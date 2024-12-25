//
//  MemoriesView.swift
//  ophelia
//
//  Created by rob on 2024-12-23.
//

import SwiftUI

/// A SwiftUI view that displays and manages a list of user memories.
///
/// Users can:
///  - View each memory’s content and timestamp.
///  - Swipe to delete specific memories.
///  - Tap a button to clear all memories at once.
struct MemoriesView: View {
    @ObservedObject var memoryStore: MemoryStore

    var body: some View {
        // A full-bleed background so no white gap appears at the top
        ZStack {
            // Extend the background color beneath the safe area
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            // The main navigation structure
            NavigationView {
                Group {
                    if memoryStore.memories.isEmpty {
                        Text("No memories stored yet.")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(memoryStore.memories) { memory in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(memory.content)
                                        .font(.body)

                                    Text("Saved on \(memory.timestamp.formatted())")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .onDelete(perform: deleteMemories)
                        }
                        // Use your preferred list style
                        .listStyle(.insetGrouped)
                        // Hide default scroll background in iOS 16+
                        .scrollContentBackground(.hidden)
                    }
                }
                .navigationTitle("Memories")
                // Use inline titles to avoid the large-title “block” at top
                .navigationBarTitleDisplayMode(.inline)
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
    }

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
