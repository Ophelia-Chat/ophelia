//
//  MemoryStore.swift
//  ophelia
//
//  Created by rob on 2024-12-23.
//
//  This file defines a simple model for storing user "memories" or facts
//  within a chat application. Each memory consists of a unique identifier,
//  the content of the memory, and a timestamp indicating when it was created.
//
//  This file defines the MemoryStore class, which is responsible for managing a
//  list of user memories. It handles loading from and saving to a JSON file,
//  and provides methods to add, remove, clear, and search for relevant memories.
//

import Foundation
import Combine

/// The MemoryStore class manages the lifecycle and persistence of user memories.
///
/// It stores the memories in memory (as an in-memory array) and also handles
/// reading/writing from/to a JSON file on the user’s device. This enables
/// the application to remember user facts between sessions.
///
/// The class is marked `@MainActor` to ensure all published changes
/// occur on the main thread (safe for SwiftUI updates).
@MainActor
class MemoryStore: ObservableObject {
    
    // MARK: - Published Properties
    
    /// The array of `Memory` objects currently stored.
    @Published private(set) var memories: [Memory] = []
    
    // MARK: - Private Properties
    
    /// A JSON encoder for serializing the memory array to disk.
    private let encoder = JSONEncoder()
    
    /// A JSON decoder for reading the memory array back from disk.
    private let decoder = JSONDecoder()
    
    /// The file URL where memories will be stored. In this example,
    /// we save `Memories.json` to the app’s Documents directory.
    private var memoriesFileURL: URL {
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentDirectory.appendingPathComponent("Memories.json")
    }
    
    // MARK: - Initializer
    
    /// Initializes a new MemoryStore, automatically attempting
    /// to load existing memories from disk.
    init() {
        loadMemories()
    }
    
    // MARK: - Public Methods
    
    /**
     Adds a new memory to the store, then saves to disk.
     
     - Parameter content: The text content of the memory (e.g., "I love hiking").
     */
    func addMemory(content: String) {
        let newMemory = Memory(content: content)
        memories.append(newMemory)
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
     Retrieves an array of memories relevant to the given query string.
     By default, uses a simple substring match (case-insensitive).
     
     - Parameter query: A substring or keyword to match in memory content.
     - Returns: An array of memories whose `content` contains the query.
     */
    func retrieveRelevant(to query: String) -> [Memory] {
        return memories.filter {
            $0.content.localizedCaseInsensitiveContains(query)
        }
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
}
