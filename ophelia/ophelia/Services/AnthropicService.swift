//
//  AnthropicService.swift
//  ophelia
//

import Foundation

actor AnthropicService: ChatServiceProtocol {
    private let baseURL = "https://api.anthropic.com/v1"
    private var apiKey: String
    private let urlSession: URLSession

    init(apiKey: String) {
        self.apiKey = apiKey

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.httpAdditionalHeaders = [
            "Accept": "application/json",
            "Connection": "keep-alive"
        ]

        self.urlSession = URLSession(configuration: config)
    }

    func updateAPIKey(_ newKey: String) {
        self.apiKey = newKey
    }

    private func maskSensitiveData(_ json: String) -> String {
        // Mask the system message if present
        var masked = json.replacingOccurrences(
            of: #""system"\s*:\s*"[^"]*""#,
            with: #""system": "[MASKED]""#,
            options: .regularExpression
        )
        
        // Mask any API keys if present
        masked = masked.replacingOccurrences(
            of: #""x-api-key"\s*:\s*"[^"]*""#,
            with: #""x-api-key": "[MASKED]""#,
            options: .regularExpression
        )
        
        return masked
    }

    func streamCompletion(
        messages: [[String: String]],
        model: String,
        system: String?
    ) async throws -> AsyncThrowingStream<String, Error> {
        guard !apiKey.isEmpty else {
            throw ChatServiceError.invalidAPIKey
        }

        guard let url = URL(string: "\(baseURL)/messages") else {
            throw ChatServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // Convert messages to Anthropic format
        let anthropicMessages = messages.map { message -> [String: String] in
            let role = message["role"] ?? "user"
            let content = message["content"] ?? ""
            return [
                "role": role == "user" ? "user" : "assistant",
                "content": content
            ]
        }

        var payload: [String: Any] = [
            "model": model,
            "messages": anthropicMessages,
            "stream": true,
            "max_tokens": 4096
        ]

        if let systemPrompt = system, !systemPrompt.isEmpty {
            payload["system"] = systemPrompt
        }

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            if let requestBody = String(data: request.httpBody!, encoding: .utf8) {
                print("Request body:", maskSensitiveData(requestBody))
            }
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

                    var currentContent = ""
                    for try await line in resultStream.lines {
                        if Task.isCancelled {
                            continuation.finish(throwing: ChatServiceError.cancelled)
                            break
                        }

                        guard !line.isEmpty, line.hasPrefix("data: ") else { continue }

                        let dataStr = line.replacingOccurrences(of: "data: ", with: "")
                        if dataStr == "[DONE]" {
                            continuation.finish()
                            break
                        }

                        do {
                            if let data = dataStr.data(using: .utf8),
                               let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                
                                if let type = json["type"] as? String {
                                    switch type {
                                    case "message_start":
                                        currentContent = ""
                                        
                                    case "content_block_delta":
                                        if let delta = json["delta"] as? [String: Any],
                                           let text = delta["text"] as? String {
                                            currentContent += text
                                            continuation.yield(text)
                                        }
                                        
                                    case "message_delta":
                                        if let delta = json["delta"] as? [String: Any],
                                           let text = delta["text"] as? String {
                                            continuation.yield(text)
                                        }
                                        
                                    case "message_stop":
                                        continuation.finish()
                                        return
                                        
                                    default:
                                        break
                                    }
                                }
                            }
                        } catch {
                            print("Error parsing JSON: \(error.localizedDescription)")
                            continue
                        }
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
