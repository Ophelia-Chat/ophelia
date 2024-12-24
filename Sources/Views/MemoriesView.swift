//
//  MemoriesView.swift
//  ophelia
//
//  Created by rob on 2024-12-23.
//
//  This file defines a SwiftUI view that lists all stored user memories, with
//  the ability to delete an individual memory or clear them all at once.
//

import SwiftUI

/// A SwiftUI view that displays and manages a list of user memories.
///
/// Users can:
///   - View each memory’s content and timestamp.
///   - Swipe to delete specific memories.
///   - Tap a button to clear all memories at once.
struct MemoriesView: View {
    // MARK: - Observed Properties
    
    /// The MemoryStore that manages loading, saving,
    /// and storing user memories in an array.
    @ObservedObject var memoryStore: MemoryStore
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            List {
                // If no memories exist, display a placeholder text.
                if memoryStore.memories.isEmpty {
                    Text("No memories stored yet.")
                        .foregroundColor(.secondary)
                } else {
                    // Otherwise, list each Memory in the store.
                    ForEach(memoryStore.memories) { memory in
                        VStack(alignment: .leading, spacing: 4) {
                            // The main content of the memory
                            Text(memory.content)
                                .font(.body)
                            
                            // When it was saved, shown in smaller text
                            Text("Saved on \(memory.timestamp.formatted())")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onDelete(perform: deleteMemories)
                }
            }
            .navigationTitle("Memories")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear All") {
                        memoryStore.clearAll()
                    }
                    .disabled(memoryStore.memories.isEmpty)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Deletes the selected memory (or memories) by index.
    ///
    /// - Parameter offsets: The positions in `memories` of the items to remove.
    private func deleteMemories(at offsets: IndexSet) {
        for index in offsets {
            let contentToRemove = memoryStore.memories[index].content
            memoryStore.removeMemory(content: contentToRemove)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct MemoriesView_Previews: PreviewProvider {
    static var previews: some View {
        // Example store with mock data
        let mockStore = MemoryStore()
        mockStore.addMemory(content: "I enjoy painting landscapes.")
        mockStore.addMemory(content: "My favorite color is green.")
        
        return MemoriesView(memoryStore: mockStore)
    }
}
#endif
