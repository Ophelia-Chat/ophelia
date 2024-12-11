//
//  ChatService.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//  Refactored to adopt async/await, Codable, and improved error handling.
//

import Foundation

// MARK: - Chat Service Protocol
public protocol ChatServiceProtocol: Actor {
    func updateAPIKey(_ newKey: String)
    func streamCompletion(messages: [[String: String]], model: String) async throws -> AsyncThrowingStream<String, Error>
}

// MARK: - Chat Service Error
public enum ChatServiceError: LocalizedError {
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

// MARK: - BaseChatService
/// A base class providing common networking logic, retry strategies, and JSON handling.
/// Subclasses (like OpenAIChatService or AnthropicService) can inherit from this class and implement their specifics.
open class BaseChatService {
    private(set) var apiKey: String
    private let urlSession: URLSession
    private let maxRetries: Int
    private let initialBackoff: UInt64

    public init(apiKey: String, maxRetries: Int = 3, initialBackoff: UInt64 = 500_000_000) {
        self.apiKey = apiKey
        self.maxRetries = maxRetries
        self.initialBackoff = initialBackoff

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.httpMaximumConnectionsPerHost = 5

        self.urlSession = URLSession(configuration: config)
    }

    /// Update the API key for the service.
    open func updateAPIKey(_ newKey: String) {
        self.apiKey = newKey
    }

    /// Perform a POST request with a given Codable payload and return the response as a Data stream.
    /// This method includes retry logic for transient errors.
    open func postStreamRequest<T: Codable>(
        to url: URL,
        payload: T,
        headers: [String: String] = [:]
    ) async throws -> URLSession.AsyncBytes {
        guard !apiKey.isEmpty else {
            throw ChatServiceError.invalidAPIKey
        }

        var attempt = 0
        var backoff = initialBackoff

        while attempt < maxRetries {
            do {
                return try await performSinglePostRequest(to: url, payload: payload, headers: headers)
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

        throw ChatServiceError.networkError("Failed after \(maxRetries) retries.")
    }

    /// Performs a single POST request without retry logic.
    private func performSinglePostRequest<T: Codable>(
        to url: URL,
        payload: T,
        headers: [String: String] = [:]
    ) async throws -> URLSession.AsyncBytes {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.forEach { request.addValue($1, forHTTPHeaderField: $0) }

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(payload)

        let (byteStream, response) = try await urlSession.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatServiceError.invalidResponse
        }

        try handleResponseStatus(httpResponse)
        return byteStream
    }

    /// Check HTTP status codes and throw appropriate ChatServiceErrors.
    open func handleResponseStatus(_ httpResponse: HTTPURLResponse) throws {
        switch httpResponse.statusCode {
        case 200:
            return
        case 401:
            throw ChatServiceError.invalidAPIKey
        case 429:
            throw ChatServiceError.rateLimitExceeded
        case 400:
            throw ChatServiceError.invalidRequest("Bad request")
        case 500...599:
            throw ChatServiceError.serverError("Server error: \(httpResponse.statusCode)")
        default:
            throw ChatServiceError.serverError("Unexpected status code: \(httpResponse.statusCode)")
        }
    }

    /// Determines if an error should trigger a retry.
    open func shouldRetry(for error: Error) -> Bool {
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

    /// Parses streamed JSON lines into a specified Codable type.
    /// Each line should start with `data: `, and `[DONE]` indicates the end of the stream.
    open func parseStream<T: Codable>(
        _ byteStream: URLSession.AsyncBytes,
        linePrefix: String = "data: ",
        completionHandler: @escaping (T) -> Void
    ) async throws {
        do {
            for try await line in byteStream.lines {
                if Task.isCancelled {
                    throw ChatServiceError.cancelled
                }

                guard line.hasPrefix(linePrefix) else { continue }

                let dataStr = line.replacingOccurrences(of: linePrefix, with: "")
                if dataStr == "[DONE]" {
                    return
                }

                if let data = dataStr.data(using: .utf8) {
                    let decoder = JSONDecoder()
                    let decoded = try decoder.decode(T.self, from: data)
                    completionHandler(decoded)
                }
            }
        } catch {
            if Task.isCancelled {
                throw ChatServiceError.cancelled
            } else {
                throw ChatServiceError.networkError(error.localizedDescription)
            }
        }
    }
}
