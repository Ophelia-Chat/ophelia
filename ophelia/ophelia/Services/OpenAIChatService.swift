//
//  OpenAIChatService.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//

import Foundation

actor OpenAIChatService: ChatServiceProtocol {
    private let baseURL = "https://api.openai.com/v1"
    private var apiKey: String
    private let urlSession: URLSession
    
    init(apiKey: String) {
        self.apiKey = apiKey
        
        // Create optimized URL session configuration
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.httpMaximumConnectionsPerHost = 5
        
        self.urlSession = URLSession(configuration: config)
    }
    
    func updateAPIKey(_ newKey: String) {
        self.apiKey = newKey
    }
    
    func streamCompletion(
        messages: [[String: String]],
        model: String
    ) async throws -> AsyncThrowingStream<String, Error> {
        guard !apiKey.isEmpty else {
            throw ChatServiceError.invalidAPIKey
        }
        
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw ChatServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "model": model,
            "messages": messages,
            "stream": true,
            "max_tokens": 4096,
            "temperature": 0.7
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (resultStream, response) = try await urlSession.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: ChatServiceError.invalidResponse)
                        return
                    }
                    
                    switch httpResponse.statusCode {
                    case 200:
                        break
                    case 401:
                        continuation.finish(throwing: ChatServiceError.invalidAPIKey)
                        return
                    case 429:
                        continuation.finish(throwing: ChatServiceError.rateLimitExceeded)
                        return
                    default:
                        continuation.finish(throwing: ChatServiceError.serverError("Status code: \(httpResponse.statusCode)"))
                        return
                    }
                    
                    var buffer = ""
                    for try await line in resultStream.lines {
                        if Task.isCancelled {
                            continuation.finish(throwing: ChatServiceError.cancelled)
                            break
                        }
                        
                        if line.hasPrefix("data: ") {
                            let dataStr = line.replacingOccurrences(of: "data: ", with: "")
                            if dataStr == "[DONE]" {
                                if !buffer.isEmpty {
                                    continuation.yield(buffer)
                                }
                                continuation.finish()
                                break
                            }
                            
                            if let data = dataStr.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let choices = json["choices"] as? [[String: Any]],
                               let delta = choices.first?["delta"] as? [String: Any],
                               let content = delta["content"] as? String {
                                buffer += content
                                
                                // Send buffer in larger chunks for better performance
                                if buffer.count >= 10 || content.contains(where: { ".,!?;\n".contains($0) }) {
                                    continuation.yield(buffer)
                                    buffer = ""
                                }
                            }
                        }
                    }
                    
                    // Send any remaining buffered content
                    if !buffer.isEmpty && !Task.isCancelled {
                        continuation.yield(buffer)
                    }
                    
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: ChatServiceError.cancelled)
                } catch {
                    continuation.finish(throwing: ChatServiceError.networkError(error.localizedDescription))
                }
            }
        }
    }
}
