//
//  ChatService.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
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
    case invalidRequest(String)  // Add this new case
    
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
