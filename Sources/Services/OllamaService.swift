//
//  OllamaServices.swift
//  ophelia
//
//  Created by rob on 2/24/25.
//

import Foundation

actor OllamaService: ChatServiceProtocol {
    private let urlSession: URLSession
    private let baseURL: URL
    private let debugMode: Bool = true // Enable verbose logging for troubleshooting
    private let serverURL: String

    init(serverURL: String = "http://localhost:11434") {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.urlSession = URLSession(configuration: config)
        
        // Store the original server URL string
        self.serverURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate and process the server URL
        var finalURL: URL
        
        // Fix common URL issues - like duplicate http:// prefixes
        var processedURLString = self.serverURL
        
        // Handle URLs with multiple schemes (like http://http://)
        if processedURLString.contains("://") {
            let components = processedURLString.components(separatedBy: "://")
            if components.count > 1 {
                // Get the first scheme and the last path component
                let scheme = components[0].lowercased()
                let host = components.last ?? ""
                
                // Only accept http or https
                if scheme == "http" || scheme == "https" {
                    processedURLString = "\(scheme)://\(host)"
                } else {
                    // Default to http for any other scheme
                    processedURLString = "http://\(host)"
                }
            }
        } else {
            // No scheme at all, add http://
            processedURLString = "http://" + processedURLString
        }
        
        // Remove trailing slashes
        while processedURLString.hasSuffix("/") {
            processedURLString.removeLast()
        }
        
        // Try to create the URL from our processed string
        if let url = URL(string: processedURLString) {
            finalURL = url
            print("[OllamaService] Successfully processed URL: \(processedURLString)")
        } else {
            print("[OllamaService] Warning: Could not create valid URL from \(processedURLString), falling back to localhost")
            finalURL = URL(string: "http://localhost:11434")!
        }
        
        self.baseURL = finalURL
        print("[OllamaService] Initialized with base URL: \(finalURL.absoluteString)")
    }

    func updateAPIKey(_ newKey: String) {
        // Ollama doesn't need an API key by default
    }

    func streamCompletion(
        messages: [[String : String]],
        model: String,
        system: String?
    ) async throws -> AsyncThrowingStream<String, Error> {
        // Create URL components from baseURL to ensure proper URL construction
        guard var components = URLComponents(string: baseURL.absoluteString) else {
            throw ChatServiceError.invalidRequest("Invalid Ollama server URL structure")
        }
        
        // Set the path to "api/chat"
        components.path = "/api/chat"
        
        // Ensure we have a valid URL
        guard let chatURL = components.url else {
            throw ChatServiceError.invalidRequest("Failed to create chat URL from components")
        }
        
        print("[OllamaService] Using model: \(model)")
        print("[OllamaService] Using URL: \(chatURL)")
        print("[OllamaService] System prompt received: \(system ?? "none")")
        if let sys = system {
            print("[OllamaService] System prompt length: \(sys.count) characters")
            print("[OllamaService] System prompt first 50 chars: \"\(sys.prefix(50))\"")
        }
        print("[OllamaService] Message count: \(messages.count)")

        // Properly format messages for Ollama API
        var ollamaMessages = [[String: String]]()
        
        // 1. First, add system message if present (most reliable way for Ollama)
        if let systemMessage = system, !systemMessage.isEmpty {
            ollamaMessages.append([
                "role": "system",
                "content": systemMessage
            ])
            print("[OllamaService] Added system message at the beginning of messages array")
        }
        
        // 2. Then add the rest of the messages
        for message in messages {
            // Make sure role is properly formatted (Ollama expects "user", "assistant", or "system")
            let role = message["role"] ?? "user"
            let content = message["content"] ?? ""
            
            // Skip empty messages
            if !content.isEmpty {
                ollamaMessages.append([
                    "role": role,
                    "content": content
                ])
            }
        }

        // Create the request body (Ollama expects a specific format)
        var requestBody: [String: Any] = [
            "model": model,
            "messages": ollamaMessages,
            "stream": true
        ]
        
        // Configure additional options for Ollama
        var options: [String: Any] = [:]
        
        // Note: For Ollama, we can add the system prompt in options.system as well as in messages
        // This provides redundancy in case one approach works better with different Ollama versions
        if let systemMessage = system, !systemMessage.isEmpty {
            options["system"] = systemMessage
        }
        
        // Only add options if we have any
        if !options.isEmpty {
            requestBody["options"] = options
        }
        
        // Print the full request body for debugging
        if let jsonData = try? JSONSerialization.data(withJSONObject: requestBody, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("[OllamaService] Request body JSON:\n\(jsonString)")
        }

        var request = URLRequest(url: chatURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60 // Increase timeout for longer generations

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw ChatServiceError.invalidRequest("Failed to encode request body: \(error.localizedDescription)")
        }

        return AsyncThrowingStream<String, Error> { continuation in
            Task {
                do {
                    print("[OllamaService] Starting request...")
                    
                    let (bytes, response) = try await urlSession.bytes(for: request)
                    
                    print("[OllamaService] Got response: \(response)")
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: ChatServiceError.invalidResponse)
                        return
                    }
                    
                    print("[OllamaService] Status code: \(httpResponse.statusCode)")
                    
                    switch httpResponse.statusCode {
                    case 200:
                        // success
                        print("[OllamaService] Status 200 OK")
                        break
                    case 404:
                        continuation.finish(throwing: ChatServiceError.serverError("404 Not Found - Possibly Ollama is not running or incorrect URL: \(serverURL)"))
                        return
                    case 400:
                        // Try to read the error body for more details
                        let body = try await readAllRemaining(bytes)
                        let errMsg = String(data: body, encoding: .utf8) ?? "Bad Request to /api/chat (400)"
                        continuation.finish(throwing: ChatServiceError.invalidRequest(errMsg))
                        return
                    case 500...599:
                        let body = try await readAllRemaining(bytes)
                        let errMsg = String(data: body, encoding: .utf8) ?? "<unknown>"
                        continuation.finish(throwing: ChatServiceError.serverError("Server error \(httpResponse.statusCode). \(errMsg)"))
                        return
                    default:
                        continuation.finish(throwing: ChatServiceError.serverError("HTTP \(httpResponse.statusCode) from /api/chat."))
                        return
                    }

                    // Stream data line by line
                    var lineCount = 0
                    for try await line in bytes.lines {
                        lineCount += 1
                        
                        if lineCount <= 5 {
                            // Only log first 5 lines to avoid console spam
                            print("[OllamaService] Received line: \(line)")
                        }
                        
                        if Task.isCancelled {
                            continuation.finish(throwing: ChatServiceError.cancelled)
                            return
                        }
                        
                        // Handle both SSE format ("data: {...}") and raw json format
                        let processedLine: String
                        if line.hasPrefix("data: ") {
                            processedLine = line.replacingOccurrences(of: "data: ", with: "")
                        } else {
                            processedLine = line
                        }
                        
                        if processedLine == "[DONE]" {
                            print("[OllamaService] Received [DONE] marker")
                            continuation.finish()
                            return
                        }
                        
                        if !processedLine.isEmpty {
                            if let jsonData = processedLine.data(using: .utf8) {
                                do {
                                    if let jsonObj = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                                        // Check if this is a completion metadata message
                                        if let isDone = jsonObj["done"] as? Bool, isDone == true {
                                            print("[OllamaService] Received completion metadata - done=true")
                                            continuation.finish()
                                            return
                                        }
                                        
                                        // SOLUTION 1: Handle Ollama's normal format with a nested message object
                                        if let msg = jsonObj["message"] as? [String: Any] {
                                            if let content = msg["content"] as? String, !content.isEmpty {
                                                print("[OllamaService] Yielding from message.content: \"\(content)\"")
                                                continuation.yield(content)
                                                continue
                                            }
                                        }
                                        
                                        // SOLUTION 2: Check for direct "content" field
                                        if let content = jsonObj["content"] as? String, !content.isEmpty {
                                            print("[OllamaService] Yielding from content: \"\(content)\"")
                                            continuation.yield(content)
                                            continue
                                        }
                                        
                                        // SOLUTION 3: Check for "response" field (some Ollama versions)
                                        if let response = jsonObj["response"] as? String, !response.isEmpty {
                                            print("[OllamaService] Yielding from response: \"\(response)\"")
                                            continuation.yield(response)
                                            continue
                                        }
                                        
                                        // SOLUTION 4: Check for "delta" field (some streaming formats)
                                        if let delta = jsonObj["delta"] as? String, !delta.isEmpty {
                                            print("[OllamaService] Yielding from delta: \"\(delta)\"")
                                            continuation.yield(delta)
                                            continue
                                        }
                                        
                                        // If we get here, log the structure and retry as raw text
                                        print("[OllamaService] Unrecognized JSON structure: \(jsonObj)")
                                        // Last resort, just yield the entire line
                                        continuation.yield(processedLine)
                                    } else {
                                        print("[OllamaService] JSON parsing returned non-dictionary: \(processedLine)")
                                        continuation.yield(processedLine)
                                    }
                                } catch {
                                    print("[OllamaService] JSON parse error: \(error), raw data: \(processedLine)")
                                    // If JSON parsing fails completely, just yield the raw line
                                    continuation.yield(processedLine)
                                }
                            } else {
                                print("[OllamaService] Failed to convert line to data: \(processedLine)")
                                continuation.yield(processedLine)
                            }
                        }
                    }
                    
                    print("[OllamaService] Finished reading \(lineCount) lines")
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: ChatServiceError.cancelled)
                } catch {
                    print("[OllamaService] Stream error: \(error)")
                    if Task.isCancelled {
                        continuation.finish(throwing: ChatServiceError.cancelled)
                    } else {
                        continuation.finish(throwing: ChatServiceError.networkError(error.localizedDescription))
                    }
                }
            }
        }
    }

    // Reads and returns all bytes if there's an error (for error body)
    private func readAllRemaining(_ bytes: URLSession.AsyncBytes) async throws -> Data {
        var buffer = Data()
        for try await byte in bytes {
            buffer.append(byte)
        }
        return buffer
    }
}
