//
//  EmbeddingService.swift
//  ophelia
//
//  Created by rob on 2024-12-24.
//
//  This file defines an actor responsible for generating vector embeddings
//  for text. It supports both online and offline strategies, adds caching to
//  reduce redundant API calls, and provides robust error handling.
//
//  Example usage in a MemoryStore:
//    let embedding = await embeddingService.embedText("I love hiking")
//    // store or compare embedding with other vectors
//

import Foundation

// MARK: - EmbeddingProvider Protocol

/**
 A protocol defining how to embed text into a vector. Different implementations
 (local, OpenAI, etc.) can conform to this for maximum flexibility.

 By making it conform to `Sendable`, we ensure that passing a provider
 across concurrency boundaries (like from the actor) does not risk data races.
 */
public protocol EmbeddingProvider: Sendable {
    /**
     Generates an embedding (array of Float) for the given text.

     - Parameter text: The string to embed.
     - Returns: An array of `Float` representing the embedding.
     - Throws: An error if the embedding process fails (network issues, etc.).
     */
    func embed(text: String) async throws -> [Float]
}

// MARK: - OpenAIEmbeddingProvider

/**
 A concrete provider that calls OpenAI's embedding endpoint, e.g.:
    POST https://api.openai.com/v1/embeddings
 with a model like "text-embedding-ada-002".

 Conforms to `Sendable` so it can safely be used in actor contexts.
 */
public struct OpenAIEmbeddingProvider: EmbeddingProvider, Sendable {
    public let apiKey: String
    public let endpointURL: URL
    public let modelName: String

    public init(apiKey: String,
                modelName: String,
                endpointURLString: String) {
        self.apiKey = apiKey
        self.modelName = modelName

        guard let url = URL(string: endpointURLString) else {
            fatalError("[OpenAIEmbeddingProvider] Invalid endpoint URL: \(endpointURLString)")
        }
        self.endpointURL = url
    }

    public func embed(text: String) async throws -> [Float] {
        // 1) Construct the JSON payload required by OpenAI’s embedding service
        let requestBody: [String: Any] = [
            "model": modelName,
            "input": text
        ]

        // 2) Create a POST URLRequest targeting the OpenAI endpoint
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // Attempt to serialize the JSON payload
        guard let httpBody = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw EmbeddingError.serializationFailed
        }
        request.httpBody = httpBody

        // 3) Perform the network request
        let (data, response) = try await URLSession.shared.data(for: request)

        // 4) Validate the HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EmbeddingError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let responseText = String(data: data, encoding: .utf8) ?? "<empty>"
            throw EmbeddingError.serverError(
                statusCode: httpResponse.statusCode,
                details: responseText
            )
        }

        // 5) Parse JSON to extract the embedding
        // Expected format:
        // {
        //   "data": [
        //     {
        //       "embedding": [float array],
        //       ...
        //     }
        //   ],
        //   ...
        // }
        guard
            let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let dataArray = jsonObject["data"] as? [[String: Any]],
            let firstObj = dataArray.first,
            let doubleVector = firstObj["embedding"] as? [Double]
        else {
            throw EmbeddingError.parsingFailed
        }

        // Convert [Double] to [Float]
        return doubleVector.map { Float($0) }
    }
}

// MARK: - LocalEmbeddingProvider

/**
 A mock or local provider that generates embeddings without network calls.
 Useful for offline testing or a real local ML model.

 For now, it returns random embeddings, but you could integrate a Core ML
 model or on-device library here.

 Also conforms to `Sendable` for concurrency safety.
 */
public struct LocalEmbeddingProvider: EmbeddingProvider, Sendable {
    /// The dimension of the embedding vector you want to produce.
    public let dimension: Int

    public init(dimension: Int = 1536) {
        self.dimension = dimension
    }

    public func embed(text: String) async throws -> [Float] {
        // Could call a local ML model here. For now, return random floats.
        return (0..<dimension).map { _ in Float.random(in: -1...1) }
    }
}

// MARK: - EmbeddingError

public enum EmbeddingError: Error, LocalizedError, Sendable {
    case invalidResponse
    case serializationFailed
    case serverError(statusCode: Int, details: String)
    case parsingFailed
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid HTTP response from the server."
        case .serializationFailed:
            return "Failed to serialize JSON payload for embedding."
        case let .serverError(code, details):
            return "Server returned an error: \(code). \(details)"
        case .parsingFailed:
            return "Could not parse embedding from the server response."
        case let .unknown(msg):
            return "Unknown error: \(msg)"
        }
    }
}

// MARK: - EmbeddingService

/**
 An actor that provides text-to-embedding functionality with optional caching
 and multiple embedding strategies. By default, it uses an OpenAI provider,
 but you can pass a local provider for offline usage.

 Now, all properties conform to `Sendable` to avoid concurrency warnings
 about potential data races.
 */
public actor EmbeddingService {
    // MARK: - Properties
    private let provider: EmbeddingProvider
    private let enableCaching: Bool
    private var cache: [String: [Float]]

    // MARK: - Initialization

    /**
     Initializes the EmbeddingService with a chosen provider and caching preference.

     - Parameters:
       - provider: Any object that conforms to `EmbeddingProvider`. This can be
         OpenAI-based or local, etc. Must also conform to `Sendable`.
       - enableCaching: If `true`, repeated calls for the same text return a cached
         vector, avoiding redundant computation or network requests.
     */
    public init(provider: EmbeddingProvider,
                enableCaching: Bool = false) {
        self.provider = provider
        self.enableCaching = enableCaching
        self.cache = [:]
    }

    /**
     A second initializer that preserves backward compatibility
     with your previous OpenAI-based usage. Marked as an actor
     initializer rather than 'convenience' to avoid Swift concurrency errors.

     - Parameters:
       - apiKey: Your secret API key for OpenAI.
       - modelName: The ID of the embedding model, e.g. "text-embedding-ada-002".
       - endpointURLString: The URL string for the embeddings endpoint, e.g. "https://api.openai.com/v1/embeddings".
       - enableCaching: Whether to cache results. Defaults to `false`.
     */
    public init(apiKey: String,
                modelName: String = "text-embedding-ada-002",
                endpointURLString: String = "https://api.openai.com/v1/embeddings",
                enableCaching: Bool = false) {
        let openAI = OpenAIEmbeddingProvider(
            apiKey: apiKey,
            modelName: modelName,
            endpointURLString: endpointURLString
        )
        self.provider = openAI
        self.enableCaching = enableCaching
        self.cache = [:]
    }

    // MARK: - Main API

    /**
     Embeds the given text into a floating-point vector using the configured provider.
     Returns `nil` if embedding fails or an error occurs. If caching is enabled,
     repeated calls with the same text return the cached embedding.

     - Parameter text: The plain text to embed.
     - Returns: An optional array of `Float` representing the embedding vector,
               or `nil` if an error occurs.
     */
    public func embedText(_ text: String) async -> [Float]? {
        // If caching is on and we already have an embedding, return it
        if enableCaching, let cached = cache[text] {
            return cached
        }

        do {
            // Because `provider` is `Sendable`, passing it across actor boundary is allowed
            let vector = try await provider.embed(text: text)

            // Store in cache if enabled
            if enableCaching {
                cache[text] = vector
            }
            return vector
        } catch {
            // Provide robust logging
            print("[EmbeddingService] Error embedding text: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Optional: Direct Access to a Random/Local Fallback

    /**
     A fallback or test method that returns a random embedding, e.g., for offline usage
     if you didn’t want to rely on the main provider. Otherwise, you can rely on
     LocalEmbeddingProvider by passing it into the constructor.
     */
    public func generateRandomEmbedding(for text: String) -> [Float] {
        let dimension = 1536 // typical dimension for "text-embedding-ada-002"
        return (0..<dimension).map { _ in Float.random(in: -1...1) }
    }
}
