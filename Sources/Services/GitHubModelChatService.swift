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
        system: String?
    ) async throws -> AsyncThrowingStream<String, Error> {
        guard !apiKey.isEmpty else {
            throw ChatServiceError.invalidAPIKey
        }

        let url = endpoint.appendingPathComponent("chat/completions")

        // Build the messages array
        var requestMessages: [[String: Any]] = []
        if let sys = system, !sys.isEmpty {
            requestMessages.append(["role": "system", "content": sys])
        }

        for msg in messages {
            if let role = msg["role"], let content = msg["content"] {
                requestMessages.append(["role": role, "content": content])
            }
        }

        let payload: [String: Any] = [
            "messages": requestMessages,
            "stream": true,
            "max_tokens": 128,
            "model": model
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // Set the `api-key` header like the NodeJS AzureKeyCredential does
        request.setValue(apiKey, forHTTPHeaderField: "api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

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

                    // Parse SSE lines in the same way as Node.js sample
                    var buffer = ""
                    for try await line in bytes.lines {
                        print("Received line from server: \(line)")
                        if Task.isCancelled {
                            continuation.finish(throwing: ChatServiceError.cancelled)
                            return
                        }

                        guard line.hasPrefix("data: ") else { continue }
                        let dataStr = line.replacingOccurrences(of: "data: ", with: "")
                        if dataStr == "[DONE]" {
                            if !buffer.isEmpty {
                                continuation.yield(buffer)
                            }
                            continuation.finish()
                            return
                        }

                        // Parse JSON chunk
                        if let jsonData = dataStr.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                           let choices = json["choices"] as? [[String: Any]] {

                            for choice in choices {
                                if let delta = choice["delta"] as? [String: Any],
                                   let content = delta["content"] as? String {
                                    buffer += content
                                    // Yield periodically
                                    if buffer.count > 10 || content.contains(where: { ".,!?;\n".contains($0) }) {
                                        continuation.yield(buffer)
                                        buffer = ""
                                    }
                                }
                            }
                        }
                    }

                    // End of stream
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
