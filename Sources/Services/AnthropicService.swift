//
//  AnthropicService.swift
//  ophelia
//
//  A ChatServiceProtocol implementation that sends requests to
//  Anthropic's API endpoint. Extended with additional debugging logs,
//  including a fallback read of the response body on non-200 status.
//

import Foundation

actor AnthropicService: ChatServiceProtocol {
    /// The base URL for Anthropic's v1 API.
    private let baseURL = "https://api.anthropic.com/v1"
    
    /// The Anthropic API key, e.g. "sk-ant..."
    private var apiKey: String
    
    /// Custom URLSession with specific timeouts and keep-alive behavior.
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

    /// Masks "system" prompt and x-api-key fields in JSON logs.
    private func maskSensitiveData(_ json: String) -> String {
        var masked = json.replacingOccurrences(
            of: #""system"\s*:\s*"[^"]*""#,
            with: #""system": "[MASKED]""#,
            options: .regularExpression
        )
        masked = masked.replacingOccurrences(
            of: #""x-api-key"\s*:\s*"[^"]*""#,
            with: #""x-api-key": "[MASKED]""#,
            options: .regularExpression
        )
        return masked
    }

    /// Streams a response from Anthropic using the messages-based endpoint.
    func streamCompletion(
        messages: [[String: String]],
        model: String,
        system: String?
    ) async throws -> AsyncThrowingStream<String, Error> {
        
        // 1) Validate API key
        guard !apiKey.isEmpty else {
            throw ChatServiceError.invalidAPIKey
        }

        // 2) Construct the full URL. By default: /v1/messages
        guard let url = URL(string: "\(baseURL)/messages") else {
            throw ChatServiceError.invalidURL
        }
        
        // 3) Build the URLRequest
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // 4) Convert incoming user/assistant messages to Anthropic's "messages" format
        let anthropicMessages = messages.map { msg -> [String: String] in
            let role = msg["role"] ?? "user"
            let content = msg["content"] ?? ""
            let anthRole = (role == "user") ? "user" : "assistant"
            return ["role": anthRole, "content": content]
        }

        // 5) Prepare JSON payload
        var payload: [String: Any] = [
            "model": model,
            "messages": anthropicMessages,
            "stream": true,
            "max_tokens": 4096
        ]
        if let systemPrompt = system, !systemPrompt.isEmpty {
            payload["system"] = systemPrompt
        }

        // 6) Serialize payload & log
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload)
            request.httpBody = jsonData
            
            // Print request details for debugging
            let requestString = String(data: jsonData, encoding: .utf8) ?? "<empty>"
            print("[AnthropicService] ---------------------")
            print("[AnthropicService] URL: \(url.absoluteString)")
            print("[AnthropicService] Method: POST")
            print("[AnthropicService] Headers:")
            for (headerKey, headerVal) in request.allHTTPHeaderFields ?? [:] {
                let safeVal = (headerKey == "x-api-key") ? "[REDACTED]" : headerVal
                print("   \(headerKey): \(safeVal)")
            }
            print("[AnthropicService] Body:\n\(maskSensitiveData(requestString))")
            print("[AnthropicService] ---------------------")
            
        } catch {
            throw ChatServiceError.invalidRequest("Failed to serialize request: \(error.localizedDescription)")
        }

        // 7) Return a streaming sequence
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // 8) Make the network call to get streaming bytes
                    let (resultStream, response) = try await urlSession.bytes(for: request)
                    
                    // 9) Validate response
                    guard let httpResponse = response as? HTTPURLResponse else {
                        print("[AnthropicService] Invalid response, no HTTPURLResponse.")
                        continuation.finish(throwing: ChatServiceError.invalidResponse)
                        return
                    }
                    
                    let statusCode = httpResponse.statusCode
                    print("[AnthropicService] HTTP Status Code: \(statusCode)")

                    // 10) If status isn't 200, try reading the entire body for debug logs
                    guard statusCode == 200 else {
                        // Attempt to read all bytes from the error response
                        let errorBodyString = try await fetchFullBodyIfError(stream: resultStream)
                        print("[AnthropicService] Non-200 error body:\n\(errorBodyString)")
                        
                        switch statusCode {
                        case 401:
                            continuation.finish(throwing: ChatServiceError.invalidAPIKey)
                        case 429:
                            continuation.finish(throwing: ChatServiceError.rateLimitExceeded)
                        case 400:
                            continuation.finish(throwing: ChatServiceError.invalidRequest("Bad request"))
                        case 500...599:
                            continuation.finish(throwing: ChatServiceError.serverError("Server error code: \(statusCode)"))
                        default:
                            continuation.finish(throwing: ChatServiceError.serverError("Unexpected status code: \(statusCode)"))
                        }
                        return
                    }

                    // 11) For 200 OK, read line by line
                    var currentContent = ""
                    for try await line in resultStream.lines {
                        if Task.isCancelled {
                            continuation.finish(throwing: ChatServiceError.cancelled)
                            break
                        }
                        
                        guard !line.isEmpty, line.hasPrefix("data: ") else { continue }
                        let dataStr = line.replacingOccurrences(of: "data: ", with: "")
                        
                        if dataStr == "[DONE]" {
                            print("[AnthropicService] [DONE] - stream ended for model: \(model)")
                            continuation.finish()
                            break
                        }

                        do {
                            if let data = dataStr.data(using: .utf8),
                               let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                
                                // Extract chunk type
                                if let type = json["type"] as? String {
                                    switch type {
                                    case "message_start":
                                        currentContent = ""
                                        print("[AnthropicService] message_start -> clearing buffer")

                                    case "content_block_delta":
                                        if let delta = json["delta"] as? [String: Any],
                                           let text = delta["text"] as? String {
                                            currentContent += text
                                            continuation.yield(text)
                                            print("[AnthropicService] content_block_delta => \(text)")
                                        }

                                    case "message_delta":
                                        if let delta = json["delta"] as? [String: Any],
                                           let text = delta["text"] as? String {
                                            continuation.yield(text)
                                            print("[AnthropicService] message_delta => \(text)")
                                        }

                                    case "message_stop":
                                        print("[AnthropicService] message_stop -> finishing stream")
                                        continuation.finish()
                                        return

                                    default:
                                        print("[AnthropicService] Unknown chunk type: \(type)")
                                    }
                                }
                            }
                        } catch {
                            print("[AnthropicService] Error parsing stream JSON chunk: \(error.localizedDescription)")
                            continue
                        }
                    }
                    
                    // 12) If stream ends normally, finalize
                    print("[AnthropicService] Stream concluded for model: \(model)")
                    continuation.finish()

                } catch is CancellationError {
                    continuation.finish(throwing: ChatServiceError.cancelled)
                } catch {
                    if Task.isCancelled {
                        continuation.finish(throwing: ChatServiceError.cancelled)
                    } else {
                        print("[AnthropicService] Caught unknown error: \(error.localizedDescription)")
                        continuation.finish(throwing: ChatServiceError.networkError(error.localizedDescription))
                    }
                }
            }
        }
    }

    /// If we get a non-200 response, let's read the entire response body for debugging.
    private func fetchFullBodyIfError(stream: URLSession.AsyncBytes) async throws -> String {
        var rawData = Data()
        for try await byte in stream {
            rawData.append(byte)
        }
        return String(data: rawData, encoding: .utf8) ?? "<Unable to decode error body>"
    }
}
