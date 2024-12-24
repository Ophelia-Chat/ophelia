//
//  Memory.swift
//  ophelia
//
//  Created by rob on 2024-12-23.
//
//  This file defines a simple model for storing user "memories" or facts
//  within a chat application. Each memory consists of a unique identifier,
//  the content of the memory, and a timestamp indicating when it was created.
//

import Foundation

/// A single piece of user-provided fact or memory.
struct Memory: Identifiable, Codable, Equatable {
    /// A unique identifier for this memory
    let id: UUID
    
    /// The main content of the memory (e.g., "I love hiking")
    var content: String
    
    /// The date and time when this memory was created
    let timestamp: Date
    
    /**
     Initializes a new Memory instance.
     
     - Parameters:
       - id: A unique `UUID` for the memory. Defaults to a newly generated UUID.
       - content: The actual text or fact being stored.
       - timestamp: The creation date and time of the memory. Defaults to the current date.
     */
    init(id: UUID = UUID(), content: String, timestamp: Date = Date()) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
    }
}
