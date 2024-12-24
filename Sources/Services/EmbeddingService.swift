//
//  EmbeddingService.swift
//  ophelia
//
//  Created by rob on 2024-12-24.
//
//  This file defines an actor responsible for generating vector embeddings
//  for text. You can use these embeddings to perform semantic search or
//  contextual lookups in a memory system.
//
//  Example usage in a MemoryStore:
//    let embedding = await embeddingService.embedText("I love hiking")
//    // store or compare embedding with other vectors
//

import Foundation

/**
 An actor that provides text-to-embedding functionality. By default, it shows
 how to call OpenAI’s "text-embedding-ada-002" model. However, you can adapt
 it to use a local ML model or any other embedding provider.

 Make sure you handle API keys securely and update your Info.plist if you
 need specific ATS exceptions for network requests.
 */
actor EmbeddingService {
    // MARK: - Properties
    
    /// Your API key for the embedding provider (e.g., OpenAI).
    /// For OpenAI, you must set this to a valid key from platform.openai.com.
    private let apiKey: String
    
    /// Base URL for the embeddings endpoint.
    /// For OpenAI, use "https://api.openai.com/v1/embeddings".
    private let embeddingEndpoint: URL
    
    /// Model name used to generate embeddings.
    /// For instance: "text-embedding-ada-002" (OpenAI).
    private let modelName: String
    
    // MARK: - Initialization
    
    /**
     Initializes the EmbeddingService with required info.
     
     - Parameters:
       - apiKey: Your secret API key for the embedding provider.
       - modelName: The ID of the embedding model to use, e.g. "text-embedding-ada-002".
       - endpointURLString: The URL string for the embeddings endpoint, e.g. "https://api.openai.com/v1/embeddings".
     */
    init(apiKey: String,
         modelName: String = "text-embedding-ada-002",
         endpointURLString: String = "https://api.openai.com/v1/embeddings") {
        
        self.apiKey = apiKey
        self.modelName = modelName
        
        // Attempt to construct a valid URL.
        guard let url = URL(string: endpointURLString) else {
            // Fallback to a known good URL or crash intentionally since it's critical to have a correct endpoint.
            fatalError("[EmbeddingService] Invalid endpoint URL: \(endpointURLString)")
        }
        self.embeddingEndpoint = url
    }
    
    // MARK: - Main API
    
    /**
     Embeds the given text into a floating-point vector using the configured model
     and endpoint. Returns `nil` if embedding fails or an error occurs.
     
     - Parameter text: The plain text to embed.
     - Returns: An optional array of `Float` representing the embedding vector,
               or `nil` if an error occurs.
     */
    func embedText(_ text: String) async -> [Float]? {
        // 1) Construct the JSON payload required by the embedding provider (OpenAI).
        let requestBody: [String: Any] = [
            "model": modelName,  // e.g., "text-embedding-ada-002"
            "input": text        // the text to embed
        ]
        
        // 2) Create a POST URLRequest targeting the embedding endpoint.
        var request = URLRequest(url: embeddingEndpoint)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Attempt to serialize the JSON payload.
        guard let httpBody = try? JSONSerialization.data(withJSONObject: requestBody) else {
            print("[EmbeddingService] Failed to create JSON payload.")
            return nil
        }
        request.httpBody = httpBody
        
        // 3) Perform the network request. We'll catch errors and parse the result.
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Ensure we have an HTTPURLResponse and it’s successful (2xx).
            guard let httpResponse = response as? HTTPURLResponse else {
                print("[EmbeddingService] Invalid response type.")
                return nil
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                // Attempt to decode error details or log them
                let responseText = String(data: data, encoding: .utf8) ?? "<empty>"
                print("[EmbeddingService] Request failed with status: \(httpResponse.statusCode)\n\(responseText)")
                return nil
            }
            
            // 4) Parse the JSON response.
            // For OpenAI, the format typically looks like:
            // {
            //   "data": [
            //     {
            //       "embedding": [float array],
            //       "index": 0,
            //       ...
            //     }
            //   ],
            //   ...
            // }
            guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataArray = jsonObject["data"] as? [[String: Any]],
                  let firstObject = dataArray.first,
                  let vector = firstObject["embedding"] as? [Double]
            else {
                print("[EmbeddingService] Could not parse embeddings from JSON response.")
                return nil
            }
            
            // Convert [Double] to [Float] if you want to save space and match your Memory model’s type.
            let floatVector = vector.map { Float($0) }
            return floatVector
            
        } catch {
            // If any error in network or parsing
            print("[EmbeddingService] Embedding request error: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Test / Dummy Embedding (Optional)
    
    /**
     A fallback or test method that returns a random embedding, for example if offline.
     You can use this for local testing or if you want a "dummy" embedding approach.
     
     - Parameter text: The text to embed (ignored in this dummy approach).
     - Returns: A random array of Floats.
     */
    func generateRandomEmbedding(for text: String) -> [Float] {
        let dimension = 1536 // typical dimension for "text-embedding-ada-002"
        return (0..<dimension).map { _ in Float.random(in: -1...1) }
    }
    
    // You could also add methods for caching embeddings to reduce costs or
    // speed up repeated requests. For instance, store them in a dictionary:
    //   private var cache: [String: [Float]] = [:]
    //
    // Then whenever you embedText(_:) you first check the cache before
    // calling the API.
}
