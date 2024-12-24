//
//  Memory.swift
//  ophelia
//
//  Created by rob on 2024-12-23.
//
//  This file defines a model for storing user "memories" or facts within a chat application.
//  Each memory consists of:
//   - A unique identifier
//   - The text or fact being stored
//   - A timestamp when this memory was created
//   - An optional embedding (vector) for semantic retrieval
//

import Foundation

/// A single piece of user-provided fact or memory.
///
/// Incorporates an optional `embedding` array for vector-based semantic retrieval.
/// If you're not using embeddings yet, you can remove or ignore this property.
struct Memory: Identifiable, Codable, Equatable {
    // MARK: - Properties

    /// A unique identifier for this memory.
    let id: UUID

    /// The main content of the memory (e.g., "I love hiking").
    var content: String

    /// The date and time when this memory was created.
    let timestamp: Date

    /// (Optional) A floating-point vector representing the semantic embedding
    /// of this memory. Useful if you plan to do vector-based similarity searches.
    var embedding: [Float]?

    // MARK: - Initialization

    /**
     Initializes a new Memory instance.

     - Parameters:
       - id: A unique `UUID` for the memory. Defaults to a newly generated UUID.
       - content: The actual text or fact being stored.
       - timestamp: The creation date and time of the memory. Defaults to the current date.
       - embedding: A vector representation of the memory’s content for semantic retrieval.
                    Defaults to `nil`, meaning no embedding has been assigned yet.
     */
    init(
        id: UUID = UUID(),
        content: String,
        timestamp: Date = Date(),
        embedding: [Float]? = nil
    ) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.embedding = embedding
    }
}
