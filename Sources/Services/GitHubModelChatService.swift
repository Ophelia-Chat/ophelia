import Foundation

actor GitHubModelChatService: ChatServiceProtocol {
    private let apiKey: String
    private let endpoint: URL
    private let urlSession: URLSession

    init(apiKey: String, endpointString: String = "https://models.inference.ai.azure.com") {
        self.apiKey = apiKey
        guard let endpoint = URL(string: endpointString) else {
            fatalError("Invalid endpoint URL.")
        }
        self.endpoint = endpoint

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        config.waitsForConnectivity = true

        self.urlSession = URLSession(configuration: config)
    }

    func updateAPIKey(_ newKey: String) {
        // If needed, implement dynamic updates. For now, do nothing.
    }

    func streamCompletion(
        messages: [[String: String]],
        model: String,
        system: String?  // We'll treat this like OpenAI's "system" role
    ) async throws -> AsyncThrowingStream<String, Error> {
        guard !apiKey.isEmpty else {
            throw ChatServiceError.invalidAPIKey
        }

        // Build the request URL
        let url = endpoint.appendingPathComponent("chat/completions")

        // Step 1: Build the messages array for the request
        var requestMessages: [[String: Any]] = []

        // If we have a system prompt, insert it at the front
        if let sys = system, !sys.isEmpty {
            requestMessages.append(["role": "system", "content": sys])
        }

        // Then append user/assistant messages in the order we received them
        for msg in messages {
            if let role = msg["role"], let content = msg["content"] {
                requestMessages.append(["role": role, "content": content])
            }
        }

        // Step 2: Construct the final JSON payload
        // You can adjust max_tokens, temperature, etc. if your model supports it
        let payload: [String: Any] = [
            "messages": requestMessages,
            "stream": true,
            "max_tokens": 2048,
            "model": model
        ]

        // Step 3: Make the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // Use `api-key` header for Azure-based endpoints
        request.setValue(apiKey, forHTTPHeaderField: "api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        // Step 4: Return an AsyncThrowingStream that yields tokens as they arrive
        return AsyncThrowingStream<String, Error> { continuation in
            Task {
                do {
                    let (bytes, response) = try await urlSession.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: ChatServiceError.invalidResponse)
                        return
                    }

                    switch httpResponse.statusCode {
                    case 200:
                        // OK, proceed with streaming
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
                        continuation.finish(throwing: ChatServiceError.serverError("Server error \(httpResponse.statusCode)"))
                        return
                    default:
                        continuation.finish(throwing: ChatServiceError.serverError("HTTP \(httpResponse.statusCode)"))
                        return
                    }

                    // Step 5: Parse SSE lines in the same style as your Node.js or OpenAI approach
                    var buffer = ""
                    for try await line in bytes.lines {
                        print("Received line from server: \(line)")
                        if Task.isCancelled {
                            continuation.finish(throwing: ChatServiceError.cancelled)
                            return
                        }

                        // SSE lines typically start with "data: "
                        guard line.hasPrefix("data: ") else { continue }
                        let dataStr = line.replacingOccurrences(of: "data: ", with: "")
                        if dataStr == "[DONE]" {
                            // End of stream
                            if !buffer.isEmpty {
                                continuation.yield(buffer)
                            }
                            continuation.finish()
                            return
                        }

                        // Step 6: Parse JSON chunk to extract partial content
                        if let jsonData = dataStr.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                           let choices = json["choices"] as? [[String: Any]] {

                            for choice in choices {
                                if let delta = choice["delta"] as? [String: Any],
                                   let content = delta["content"] as? String {
                                    // Accumulate tokens in buffer
                                    buffer += content

                                    // Yield buffer periodically for responsiveness
                                    if buffer.count > 10 || content.contains(where: { ".,!?;\n".contains($0) }) {
                                        continuation.yield(buffer)
                                        buffer = ""
                                    }
                                }
                            }
                        }
                    }

                    // End of stream or exit
                    if !buffer.isEmpty {
                        continuation.yield(buffer)
                    }
                    continuation.finish()

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
