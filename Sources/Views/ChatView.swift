//
//  ChatView.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//

import SwiftUI
import Combine

@available(iOS 18.0, *)
struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()

    // Shows Settings sheet
    @State private var showingSettings = false
    
    // Shows Memories sheet
    @State private var showingMemories = false

    // Watches app’s lifecycle states (active/inactive)
    @Environment(\.scenePhase) private var scenePhase

    // Tracks dark mode from UserDefaults
    @AppStorage("isDarkMode") private var isDarkMode = false

    var body: some View {
        NavigationStack {
            ZStack {
                // A background gradient
                Color.Theme.primaryGradient(isDarkMode: isDarkMode)
                    .ignoresSafeArea(edges: .top)

                // Main chat layout (messages + input bar) in ChatMainView
                ChatMainView(
                    viewModel: viewModel,
                    showingSettings: $showingSettings,
                    tempSettings: .constant(viewModel.appSettings)
                )
            }
            // Runs final setup each time the view appears
            .onAppear {
                Task {
                    await viewModel.finalizeSetup()
                }
            }
            // Presents Settings, re-initializes the chat once user closes it
            .sheet(isPresented: $showingSettings) {
                ChatSettingsSheet(
                    tempSettings: .constant(viewModel.appSettings),
                    showingSettings: $showingSettings,
                    chatViewModel: viewModel,
                    clearMessages: {
                        viewModel.clearMessages()
                    }
                )
            }
            // Presents a sheet showing user memories
            .sheet(isPresented: $showingMemories) {
                NavigationStack {
                    MemoriesView(memoryStore: viewModel.memoryStore)
                        .navigationTitle("Your Memories")
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") {
                                    showingMemories = false
                                }
                            }
                        }
                }
            }
            // Basic nav bar
            .navigationTitle("Ophelia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Left side: Memory icon
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingMemories = true
                    } label: {
                        Image(systemName: "list.bullet.rectangle.portrait")
                    }
                }

                // Right side: Settings (gear) icon
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .tint(.blue)
            // If the app goes inactive, optionally do cleanup
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase != .active {
                    // e.g. fieldIsFocused = false
                }
            }
        }
    }
}
