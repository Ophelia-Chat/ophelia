//
//  MemoryStore.swift
//  ophelia
//
//  Created by rob on 2024-12-23.
//
//  This file defines the MemoryStore class, which is responsible for managing a
//  list of user memories. It handles loading from and saving to a JSON file,
//  and provides methods to add, remove, clear, and search for relevant memories.
//
//  Additionally, it can generate and store vector embeddings (e.g., from OpenAI)
//  to enable advanced semantic or contextual lookups. This version includes
//  performance improvements for large datasets, better error handling, and
//  refined similarity logic.
//
//  Usage in your ChatViewModel (example):
//    @Published var memoryStore = MemoryStore(embeddingService: EmbeddingService(apiKey: "..."))
//    ...
//    memoryStore.addMemory(content: "I love pizza")
//

import Foundation
import Combine

/// The MemoryStore class manages the lifecycle, persistence, and optional
/// embedding logic for user memories.
///
/// It maintains an in-memory array of `Memory` objects and saves/loads
/// these to a JSON file on disk. If an `EmbeddingService` is provided,
/// the store can generate vector embeddings for new memories and
/// perform semantic retrieval based on those embeddings.
@MainActor
class MemoryStore: ObservableObject {

    // MARK: - Published Properties

    /// The array of `Memory` objects currently stored in memory.
    /// SwiftUI views can observe changes to this array.
    @Published private(set) var memories: [Memory] = []

    // MARK: - Private Properties

    /// A JSON encoder for serializing the memory array to disk.
    private let encoder = JSONEncoder()

    /// A JSON decoder for reading the memory array back from disk.
    private let decoder = JSONDecoder()

    /// The file URL where memories will be stored.
    /// In this example, we save `Memories.json` to the app’s Documents directory.
    private var memoriesFileURL: URL {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDir.appendingPathComponent("Memories.json")
    }

    /// (Optional) A reference to an embedding service that can generate
    /// vector embeddings for new memory entries or user queries.
    ///
    /// If `nil`, no embeddings will be generated or used for retrieval.
    private let embeddingService: EmbeddingService?

    // MARK: - Initializer

    /**
     Initializes a new MemoryStore, automatically attempting
     to load existing memories from disk. Optionally accepts an embedding service
     to enable semantic retrieval.

     - Parameter embeddingService: An optional instance of `EmbeddingService`
       that can generate vector embeddings. Defaults to `nil`.
     */
    init(embeddingService: EmbeddingService? = nil) {
        self.embeddingService = embeddingService
        loadMemories()
    }

    // MARK: - Public Methods

    /**
     Adds a new memory to the store, then saves to disk. If an `EmbeddingService` is
     available, this method also requests an embedding for the new memory’s content
     and updates the memory accordingly.

     - Parameter content: The text content of the memory (e.g., "I love hiking").
     */
    func addMemory(content: String) {
        let newMemory = Memory(content: content)
        memories.append(newMemory)
        
        // If we have an embedding service, compute an embedding asynchronously
        // and update the stored memory once it's available.
        if let service = embeddingService {
            Task { [weak self] in
                guard let self = self else { return }
                
                // Directly await embedding without do-catch
                if let embed = await service.embedText(content) {
                    self.updateMemoryEmbedding(for: newMemory.id, to: embed)
                } else {
                    print("[MemoryStore] Embedding service returned nil.")
                }
            }
        }
        
        saveMemories()
    }

    /**
     Removes the first memory whose content contains the specified string
     (case-insensitive). If none is found, no action is taken.

     - Parameter content: A case-insensitive substring of the memory content to remove.
     */
    func removeMemory(content: String) {
        if let index = memories.firstIndex(where: {
            $0.content.localizedCaseInsensitiveContains(content)
        }) {
            memories.remove(at: index)
            saveMemories()
        }
    }

    /**
     Removes all stored memories, then saves an empty array to disk.
     */
    func clearAll() {
        memories.removeAll()
        saveMemories()
    }

    /**
     Returns up to `topK` memories that are relevant to the given query. If
     an `EmbeddingService` is available, it attempts to compute semantic similarity
     against each memory’s embedding. Otherwise, it falls back to substring matching.

     - Parameters:
       - query: The user’s text query (e.g., "I love pizza").
       - topK: The maximum number of relevant memories to return. Defaults to 5.

     - Returns: An array of relevant memories sorted by descending relevance or
                substring match. If no embeddings exist or embedding fails,
                falls back to a simple substring approach.
     */
    func retrieveRelevant(to query: String, topK: Int = 5) async -> [Memory] {
        // 1) If no embedding service or query embedding fails, fallback to substring
        guard let service = embeddingService,
              let queryEmbedding = await service.embedText(query) else {
            return substringFallback(query: query, topK: topK)
        }

        // 2) Compute similarity vs. each memory. For large memory sets, do it concurrently.
        //    We'll gather results in a local array, then sort.
        let scored: [(Memory, Float)] = await withTaskGroup(of: (Memory, Float).self) { group in
            // Add each memory to a TaskGroup so we can parallelize similarity checks
            for mem in memories {
                group.addTask { [weak self] in
                    guard let self = self else { return (mem, 0.0) }
                    
                    if let memEmbedding = mem.embedding {
                        // Compute semantic similarity
                        let score = await self.refinedCosineSimilarity(memEmbedding, queryEmbedding)
                        return (mem, score)
                    } else {
                        // Fallback if no embedding is stored
                        let fallbackScore: Float = mem.content.localizedCaseInsensitiveContains(query) ? 0.3 : 0.0
                        return (mem, fallbackScore)
                    }
                }
            }

            // Collect all results
            var tempResults = [(Memory, Float)]()
            for await result in group {
                tempResults.append(result)
            }
            return tempResults
        }

        // 3) Sort by descending similarity and take the top K
        let sorted = scored.sorted { $0.1 > $1.1 }
        return Array(sorted.prefix(topK).map { $0.0 })
    }

    // MARK: - Private Methods

    /// Attempts to load memories from the JSON file on disk.
    /// If unsuccessful (e.g., file doesn’t exist), `memories` is left empty.
    private func loadMemories() {
        do {
            let data = try Data(contentsOf: memoriesFileURL)
            let decoded = try decoder.decode([Memory].self, from: data)
            self.memories = decoded
            print("[MemoryStore] Successfully loaded \(decoded.count) memories.")
        } catch {
            print("[MemoryStore] No existing Memories.json or failed to load. Starting fresh.")
            self.memories = []
        }
    }

    /// Saves the current `memories` array to the JSON file on disk.
    private func saveMemories() {
        do {
            let data = try encoder.encode(memories)
            try data.write(to: memoriesFileURL, options: [.atomic])
            print("[MemoryStore] Memories saved to disk.")
        } catch {
            print("[MemoryStore] Failed to save memories: \(error.localizedDescription)")
        }
    }

    /**
     Internal helper to update an existing memory’s embedding in place,
     then save changes to disk.

     - Parameters:
       - memoryID: The `UUID` of the memory whose embedding we want to update.
       - newEmbedding: The `[Float]` vector to assign as the updated embedding.
     */
    private func updateMemoryEmbedding(for memoryID: UUID, to newEmbedding: [Float]) {
        if let index = memories.firstIndex(where: { $0.id == memoryID }) {
            memories[index].embedding = newEmbedding
            saveMemories()
        }
    }

    /**
     A refined cosine similarity with a small epsilon to handle floating precision better.
     If lengths mismatch or either vector is zero-length, returns 0.

     - Parameters:
       - v1: The first vector of floats.
       - v2: The second vector of floats.
     - Returns: The cosine similarity score, typically between -1 and 1,
                with 1 indicating high similarity.
     */
    private func refinedCosineSimilarity(_ v1: [Float], _ v2: [Float]) -> Float {
        guard v1.count == v2.count else { return 0 }
        let dotProduct = zip(v1, v2).map(*).reduce(0, +)
        let norm1 = sqrt(v1.reduce(0) { $0 + $1 * $1 })
        let norm2 = sqrt(v2.reduce(0) { $0 + $1 * $1 })
        let epsilon: Float = 1e-6
        if norm1 < epsilon || norm2 < epsilon { return 0 }
        return dotProduct / (norm1 * norm2)
    }

    /**
     Substring fallback approach when embeddings are unavailable or fail.
     Returns up to `topK` matches where `content` contains `query`
     (case-insensitive), sorted by a basic measure of "match strength."

     - Parameters:
       - query: The user’s text query.
       - topK: The maximum number of results to return.
     - Returns: An array of memories that match substring logic.
     */
    private func substringFallback(query: String, topK: Int) -> [Memory] {
        // A simple approach: rank by the count of matched occurrences, etc.
        // For now, let's just filter and return up to topK in arbitrary order.
        let filtered = memories.filter {
            $0.content.localizedCaseInsensitiveContains(query)
        }
        return Array(filtered.prefix(topK))
    }
}

extension MemoryStore {
    /// Exports the memories array as a temporary JSON file and returns the file URL, or `nil` on failure.
    func exportMemoriesAsJSONFile() -> URL? {
        do {
            let data = try JSONEncoder().encode(memories)
            let tempDir = FileManager.default.temporaryDirectory
            let filename = "memories-\(UUID().uuidString).json"
            let fileURL = tempDir.appendingPathComponent(filename)

            try data.write(to: fileURL, options: .atomic)
            print("[MemoryStore] Exported memories to file: \(fileURL)")
            return fileURL
        } catch {
            print("[MemoryStore] Error exporting memories: \(error)")
            return nil
        }
    }
}
