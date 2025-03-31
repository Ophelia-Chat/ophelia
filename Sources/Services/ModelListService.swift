//
//  ModelListService.swift
//  Ophelia
//
//  Description:
//  Fetches model lists from different AI providers (OpenAI, Anthropic, GitHub/Azure).
//  Includes logic for decoding the known shapes of each provider's /models response.
//
//  Notes on Provider Differences:
//
//  1) **OpenAI** (api.openai.com/v1/models):
//     Returns JSON like:
//     {
//       "object": "list",
//       "data": [
//         { "id": "gpt-4", "object": "model", ... },
//         ...
//       ]
//     }
//     A valid API key is required via the "Authorization: Bearer <YOUR_API_KEY>" header.
//
//  2) **Anthropic** (api.anthropic.com/v1/models):
//     Can return one of two shapes:
//       (a) { "data": [ { "id": "claude-2" }, ... ] }
//       (b) { "models": [ { "model_id": "claude-2" }, ... ] }
//     We attempt shape (a) first, then fallback to (b). Requires x-api-key & anthropic-version headers.
//
//  3) **Azure OpenAI** (models.inference.ai.azure.com or your custom endpoint):
//     Typically returns JSON shaped like:
//       [ { "id": "model1", "name": "Fancy Model 1" }, ... ]
//     Authentication uses an "api-key" header.
//
//  Usage Example:
//
//      let service = ModelListService()
//      let models  = try await service.fetchModels(for: .openAI, apiKey: "sk-...")
//      // models is an array of ChatModel objects
//

import Foundation

// MARK: - Response Types
private struct OllamaTagsResponse: Decodable {
    struct Model: Decodable {
        let name: String
    }
    let models: [Model]
}

/// An actor responsible for fetching and decoding model lists from various AI provider endpoints.
actor ModelListService {
    
    // MARK: - Properties
    
    private let urlSession: URLSession
    
    // MARK: - Initialization
    
    init() {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        
        self.urlSession = URLSession(configuration: config)
    }
    
    // MARK: - Public Method
    
    /// Fetches a list of models from the specified provider's API using the given API key.
    ///
    /// - Parameters:
    ///   - provider: The `ChatProvider` enum case (e.g., `.openAI`, `.anthropic`, `.githubModel`).
    ///   - apiKey:   The user's API key or token for that provider.
    /// - Returns:    An array of `ChatModel` objects (each with id, name, and provider).
    func fetchModels(for provider: ChatProvider, apiKey: String) async throws -> [ChatModel] {
        switch provider {
        case .openAI:
            // Keep dynamic fetching for OpenAI as before:
            let request = try buildRequest(for: .openAI, apiKey: apiKey)
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                let errorMsg = String(data: data, encoding: .utf8) ?? "<no response body>"
                throw URLError(.badServerResponse, userInfo: ["errorMessage": errorMsg])
            }
            return try parseResponse(data: data, provider: .openAI)
            
        case .anthropic, .githubModel:
            // Instead of hitting the network, just return the provider's built-in model list.
            // You have these pre-defined in ChatProvider.availableModels, so let's use that.
            return provider.availableModels
            
        case .ollama:
            // Safety check the URL before attempting to connect
            let serverURLString = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 1. Validate URL structure first
            guard var urlComponents = URLComponents(string: serverURLString) else {
                print("[ModelListService] Invalid Ollama server URL format: \(serverURLString)")
                return [ChatModel(id: "llama3", name: "llama3 (Default)", provider: .ollama)]
            }
            
            // 2. Ensure the URL has a scheme - if missing, add http://
            if urlComponents.scheme == nil {
                urlComponents.scheme = "http"
                print("[ModelListService] Added http:// scheme to Ollama URL")
            }
            
            // 3. Make sure the scheme is either http or https
            if urlComponents.scheme != "http" && urlComponents.scheme != "https" {
                print("[ModelListService] Invalid scheme in Ollama URL: \(urlComponents.scheme ?? "nil")")
                return [ChatModel(id: "llama3", name: "llama3 (Default)", provider: .ollama)]
            }
            
            // 4. Get the finalized URL with proper scheme
            guard let finalURL = urlComponents.url else {
                print("[ModelListService] Failed to create URL from components")
                return [ChatModel(id: "llama3", name: "llama3 (Default)", provider: .ollama)]
            }
            
            // 5. Build the tags URL
            let tagsURL = finalURL.appendingPathComponent("api/tags")
            
            print("[ModelListService] Attempting to fetch Ollama models from: \(tagsURL.absoluteString)")
            
            // 6. Create the request with the validated URL
            var request = URLRequest(url: tagsURL)
            request.httpMethod = "GET"
            request.timeoutInterval = 5 // Short timeout to avoid long hangs
            
            do {
                let (data, response) = try await urlSession.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw ChatServiceError.invalidResponse
                }
                
                if httpResponse.statusCode != 200 {
                    let body = String(data: data, encoding: .utf8) ?? "No response body"
                    print("[ModelListService] Server returned \(httpResponse.statusCode): \(body)")
                    throw ChatServiceError.serverError("HTTP \(httpResponse.statusCode)")
                }
                
                let decoded = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
                if decoded.models.isEmpty {
                    print("[ModelListService] Warning: Ollama returned empty model list")
                }
                return decoded.models.map { model in
                    ChatModel(id: model.name, name: model.name, provider: .ollama)
                }
            } catch let error as URLError {
                print("[ModelListService] Network error: \(error.localizedDescription), code: \(error.code.rawValue)")
                
                // Handle connection errors more gracefully
                switch error.code {
                case .cannotFindHost, .cannotConnectToHost, .timedOut, .badURL:
                    // Return a default model rather than throwing an error
                    print("[ModelListService] Cannot connect to Ollama server at \(finalURL.absoluteString)")
                    return [ChatModel(id: "llama3", name: "llama3 (Default)", provider: .ollama)]
                default:
                    // For other URL errors, return a sensible fallback
                    return [ChatModel(id: "llama3", name: "llama3 (Fallback)", provider: .ollama)]
                }
            } catch {
                // For any other errors, return a default model instead of throwing
                print("[ModelListService] General error fetching Ollama models: \(error.localizedDescription)")
                return [ChatModel(id: "llama3", name: "llama3 (Default)", provider: .ollama)]
            }
        }
    }
    
    // MARK: - Private Helpers
    
    /// Constructs a GET request for the appropriate provider's /models endpoint, adding required headers.
    private func buildRequest(for provider: ChatProvider, apiKey: String) throws -> URLRequest {
        var request: URLRequest
        
        switch provider {
        case .openAI:
            // For standard OpenAI usage: GET https://api.openai.com/v1/models
            guard let url = URL(string: "https://api.openai.com/v1/models") else {
                throw URLError(.badURL)
            }
            request = URLRequest(url: url)
            // OpenAI uses Bearer authorization
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            
        case .anthropic:
            // For Anthropic usage: GET https://api.anthropic.com/v1/models
            guard let url = URL(string: "https://api.anthropic.com/v1/models") else {
                throw URLError(.badURL)
            }
            request = URLRequest(url: url)
            // Anthropic requires x-api-key and anthropic-version headers
            request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            
        case .githubModel:
            // For Azure-based or GitHub-based model endpoint
            guard let url = URL(string: "https://models.inference.ai.azure.com/models") else {
                throw URLError(.badURL)
            }
            request = URLRequest(url: url)
            // Azure-based endpoints often require "api-key" in the header
            request.addValue(apiKey, forHTTPHeaderField: "api-key")
            
        case .ollama:
            // For Ollama, the URL creation is now handled in the fetchModels method
            // to provide better validation and error handling
            throw URLError(.badURL, userInfo: ["message": "Ollama requests should be created in fetchModels"])
        }
        
        request.httpMethod = "GET"
        return request
    }
    
    /// Decodes the raw JSON into `[ChatModel]`, adapting for each provider's known shapes.
    private func parseResponse(data: Data, provider: ChatProvider) throws -> [ChatModel] {
        switch provider {
            
        case .openAI:
            // Debug: Print raw OpenAI response if needed
            #if DEBUG
            let rawStr = String(data: data, encoding: .utf8) ?? "<no data>"
            print("OpenAI raw JSON:\n", rawStr)
            #endif
            
            // Typical shape:
            // {
            //   "object": "list",
            //   "data": [
            //       {"id": "gpt-4", "object": "model", ... },
            //       {"id": "gpt-3.5-turbo", "object": "model", ...}
            //   ]
            // }
            do {
                let decoded = try JSONDecoder().decode(OpenAIModelsResponse.self, from: data)
                return decoded.data.map {
                    ChatModel(
                        id: $0.id,
                        name: $0.id,
                        provider: .openAI
                    )
                }
            } catch {
                // If decoding fails, log the error
                print("OpenAI decode error:", error)
                throw error
            }
            
        case .anthropic:
            // Anthropic might return:
            // #1: { "data": [ { "id": "claude-2" }, ... ] }
            // #2: { "models": [ { "model_id": "claude-2" }, ... ] }
            
            #if DEBUG
            let rawStr = String(data: data, encoding: .utf8) ?? "<no data>"
            print("Anthropic raw JSON:\n", rawStr)
            #endif
            
            // Attempt shape #1 first
            do {
                let shapeOne = try JSONDecoder().decode(AnthropicDataResponse.self, from: data)
                return shapeOne.data.map {
                    ChatModel(
                        id: $0.id,
                        name: $0.id,
                        provider: .anthropic
                    )
                }
            } catch {
                // If that fails, try shape #2
                let shapeTwo = try JSONDecoder().decode(AnthropicModelsResponse.self, from: data)
                return shapeTwo.models.map {
                    ChatModel(
                        id: $0.model_id,
                        name: $0.model_id,
                        provider: .anthropic
                    )
                }
            }
            
        case .githubModel:
            // Example shape: [ { "id": "myModel", "name": "My Model Display Name" }, ... ]
            let decoded = try JSONDecoder().decode([AzureModelItem].self, from: data)
            return decoded.map { item in
                ChatModel(
                    id: item.id,
                    name: item.name,
                    provider: .githubModel
                )
            }
            
        case .ollama:
            #if DEBUG
            let rawStr = String(data: data, encoding: .utf8) ?? "<no data>"
            print("Ollama /api/tags raw JSON:\n", rawStr)
            #endif
            
            let decoded = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
            return decoded.models.map { info in
                ChatModel(
                    id: info.name,
                    name: info.name,
                    provider: .ollama
                )
            }
        }
    }
}

// MARK: - OpenAI Response Models

/// Decodes an OpenAI list of models shape:
/// {
///   "object": "list",
///   "data": [ { "id": "gpt-4", "object": "model" }, ... ]
/// }
private struct OpenAIModelsResponse: Decodable {
    let object: String?             // "list"
    let data: [OpenAIModelItem]
}

/// Represents a single entry in the "data" array for OpenAI's response.
private struct OpenAIModelItem: Decodable {
    let id: String
    let object: String?            // "model"
}

// MARK: - Anthropic Response Models

/// Shape #1: { "data": [ { "id": "claude-2" } ] }
private struct AnthropicDataResponse: Decodable {
    let data: [AnthropicDataItem]
}

private struct AnthropicDataItem: Decodable {
    let id: String
}

/// Shape #2: { "models": [ { "model_id": "claude-2" } ] }
private struct AnthropicModelsResponse: Decodable {
    let models: [AnthropicModelItem]
}

private struct AnthropicModelItem: Decodable {
    let model_id: String
}

// MARK: - Azure/GitHub Response Model

/// For GitHub/Azure-based endpoints:
/// [ { "id": "myModel1", "name": "My Model Display Name" }, ... ]
private struct AzureModelItem: Decodable {
    let id: String
    let name: String
}
