//
//  OpenAIChatService.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//  Refactored to use async/await, Codable, and improved error handling.
//

import Foundation

public protocol OpenAIChatServiceProtocol: Actor {
    func updateAPIKey(_ newKey: String)
    // Update signature to include `system: String?` to match ChatServiceProtocol
    func streamCompletion(messages: [[String: String]], model: String, system: String?) async throws -> AsyncThrowingStream<String, Error>
}

public enum OpenAIChatServiceError: LocalizedError {
    case invalidURL
    case invalidAPIKey
    case networkError(String)
    case invalidResponse
    case rateLimitExceeded
    case serverError(String)
    case cancelled
    case invalidRequest(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL configuration"
        case .invalidAPIKey:
            return "Invalid or missing API key"
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidResponse:
            return "Invalid response from server"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later"
        case .serverError(let message):
            return "Server error: \(message)"
        case .cancelled:
            return "Request was cancelled"
        case .invalidRequest(let message):
            return "Invalid request: \(message)"
        }
    }
}

// MARK: - Request/Response Models
private struct OpenAICompletionRequest: Codable {
    struct Message: Codable {
        let role: String
        let content: String
    }

    let model: String
    let messages: [Message]
    let stream: Bool
    let max_tokens: Int
    let temperature: Double
}

private struct OpenAIStreamResponse: Codable {
    struct Choice: Codable {
        struct Delta: Codable {
            let content: String?
        }
        let delta: Delta?
    }
    let choices: [Choice]
}

// MARK: - OpenAIChatService
actor OpenAIChatService: ChatServiceProtocol {
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    private var apiKey: String
    private let urlSession: URLSession

    private let maxRetries = 3
    private let initialBackoff: UInt64 = 500_000_000 // 0.5 seconds

    init(apiKey: String) {
        self.apiKey = apiKey
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

    /// Streams completion responses from OpenAI.
    /// Note: The `system` parameter is included to match the ChatServiceProtocol but is not used here.
    func streamCompletion(
        messages: [[String: String]],
        model: String,
        system: String? // We simply accept this parameter but do not use it for OpenAI.
    ) async throws -> AsyncThrowingStream<String, Error> {
        guard !apiKey.isEmpty else {
            throw ChatServiceError.invalidAPIKey
        }

        guard let url = URL(string: baseURL) else {
            throw ChatServiceError.invalidURL
        }

        // Convert incoming messages to strongly typed request messages
        let requestMessages = messages.compactMap { dict -> OpenAICompletionRequest.Message? in
            guard let role = dict["role"], let content = dict["content"] else { return nil }
            return OpenAICompletionRequest.Message(role: role, content: content)
        }

        let payload = OpenAICompletionRequest(
            model: model,
            messages: requestMessages,
            stream: true,
            max_tokens: 4096,
            temperature: 0.7
        )

        var attempt = 0
        var backoff = initialBackoff

        // Retry loop for transient errors like network or rate limit
        while attempt < maxRetries {
            do {
                let stream = try await performRequest(url: url, payload: payload)
                return stream
            } catch {
                if shouldRetry(for: error) && attempt < maxRetries - 1 {
                    attempt += 1
                    try await Task.sleep(nanoseconds: backoff)
                    backoff *= 2
                    continue
                } else {
                    throw error
                }
            }
        }

        // If all retries fail, throw the last error encountered (handled by above logic)
        throw ChatServiceError.networkError("Failed after \(maxRetries) retries.")
    }

    // MARK: - Internal Logic

    private func performRequest(
        url: URL,
        payload: OpenAICompletionRequest
    ) async throws -> AsyncThrowingStream<String, Error> {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(payload)

        let (resultStream, response) = try await urlSession.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatServiceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            // OK, proceed with streaming
            break
        case 401:
            throw ChatServiceError.invalidAPIKey
        case 429:
            throw ChatServiceError.rateLimitExceeded
        default:
            throw ChatServiceError.serverError("Status code: \(httpResponse.statusCode)")
        }

        return parseStream(resultStream)
    }

    private func parseStream(_ byteStream: URLSession.AsyncBytes) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream<String, Error> { continuation in
            Task {
                var buffer = ""
                do {
                    for try await line in byteStream.lines {
                        if Task.isCancelled {
                            continuation.finish(throwing: ChatServiceError.cancelled)
                            return
                        }

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

                        // Attempt to decode the partial JSON line
                        if let data = dataStr.data(using: .utf8),
                           let json = try? JSONDecoder().decode(OpenAIStreamResponse.self, from: data),
                           let content = json.choices.first?.delta?.content {
                            buffer += content

                            // Yield buffer periodically for performance and responsiveness
                            if buffer.count >= 10 || content.contains(where: { ".,!?;\n".contains($0) }) {
                                continuation.yield(buffer)
                                buffer = ""
                            }
                        }
                    }

                    // Yield any remaining content in buffer
                    if !buffer.isEmpty && !Task.isCancelled {
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

    private func shouldRetry(for error: Error) -> Bool {
        // Determine if the error is transient and worth retrying
        if let chatError = error as? ChatServiceError {
            switch chatError {
            case .rateLimitExceeded, .networkError, .invalidResponse, .serverError:
                return true
            default:
                return false
            }
        }
        return false
    }
}
