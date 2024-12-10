//
//  AnthropicService.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//

import Foundation

actor AnthropicService: ChatServiceProtocol {
    private let baseURL = "https://api.anthropic.com/v1"
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
        
        // Add additional headers for better performance
        config.httpAdditionalHeaders = [
            "Accept": "application/json",
            "Connection": "keep-alive"
        ]
        
        self.urlSession = URLSession(configuration: config)
    }
    
    func updateAPIKey(_ newKey: String) {
        self.apiKey = newKey
    }
    
    private func convertToAnthropicMessage(_ message: [String: String]) -> [String: String] {
        let role = message["role"] ?? ""
        let content = message["content"] ?? ""
        
        switch role {
        case "user":
            return ["role": "user", "content": content]
        case "assistant":
            return ["role": "assistant", "content": content]
        case "system":
            return ["role": "user", "content": "System instruction: \(content)"]
        default:
            return ["role": "user", "content": content]
        }
    }
    
    func streamCompletion(
        messages: [[String: String]],
        model: String
    ) async throws -> AsyncThrowingStream<String, Error> {
        guard !apiKey.isEmpty else {
            throw ChatServiceError.invalidAPIKey
        }
        
        guard let url = URL(string: "\(baseURL)/messages") else {
            throw ChatServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "x-api-key")
        request.addValue("anthropic-client/1.0.0", forHTTPHeaderField: "anthropic-client")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Convert messages to Anthropic format
        let anthropicMessages = messages.map(convertToAnthropicMessage)
        
        let payload: [String: Any] = [
            "model": model,
            "messages": anthropicMessages,
            "stream": true,
            "max_tokens": 4096,
            "temperature": 0.7,
            "top_p": 1,
            "top_k": 40
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            throw ChatServiceError.invalidRequest("Failed to serialize request: \(error.localizedDescription)")
        }
        
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
                    case 400:
                        continuation.finish(throwing: ChatServiceError.invalidRequest("Bad request"))
                        return
                    case 500...599:
                        continuation.finish(throwing: ChatServiceError.serverError("Server error with status code: \(httpResponse.statusCode)"))
                        return
                    default:
                        continuation.finish(throwing: ChatServiceError.serverError("Unexpected status code: \(httpResponse.statusCode)"))
                        return
                    }
                    
                    var buffer = ""
                    for try await line in resultStream.lines {
                        if Task.isCancelled {
                            continuation.finish(throwing: ChatServiceError.cancelled)
                            break
                        }
                        
                        guard !line.isEmpty else { continue }
                        
                        if line.hasPrefix("data: ") {
                            let dataStr = line.replacingOccurrences(of: "data: ", with: "")
                            if dataStr == "[DONE]" {
                                if !buffer.isEmpty {
                                    continuation.yield(buffer)
                                }
                                continuation.finish()
                                break
                            }
                            
                            do {
                                if let data = dataStr.data(using: .utf8),
                                   let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                                   let delta = json["delta"] as? [String: Any],
                                   let content = delta["text"] as? String {  // Note: Anthropic uses "text" instead of "content"
                                    buffer += content
                                    
                                    // Optimize buffer flushing for better performance
                                    if buffer.count >= 10 || content.contains(where: { ".,!?;\n".contains($0) }) {
                                        continuation.yield(buffer)
                                        buffer = ""
                                    }
                                }
                            } catch {
                                print("Error parsing JSON: \(error.localizedDescription)")
                                // Continue processing even if one message fails
                                continue
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
                    if Task.isCancelled {
                        continuation.finish(throwing: ChatServiceError.cancelled)
                    } else {
                        continuation.finish(throwing: ChatServiceError.networkError(error.localizedDescription))
                    }
                }
            }
        }
    }
}
