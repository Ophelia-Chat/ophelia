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
    /// Main ViewModel managing chat flow, messages, app settings, etc.
    @StateObject private var viewModel = ChatViewModel()

    /// Controls whether to show the Settings sheet
    @State private var showingSettings = false

    /// Controls whether to show the Memories sheet
    @State private var showingMemories = false

    /// Watches app’s lifecycle states (active, inactive, background)
    @Environment(\.scenePhase) private var scenePhase

    /// Tracks dark mode preference from UserDefaults (in case you rely on it for the background)
    @AppStorage("isDarkMode") private var isDarkMode = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient that adjusts to dark mode
                Color.Theme.primaryGradient(isDarkMode: isDarkMode)
                    .ignoresSafeArea(edges: .top)

                // The main chat interface: messages + input bar
                ChatMainView(
                    viewModel: viewModel,
                    // This toggles Settings
                    showingSettings: $showingSettings,
                    // No longer passing a .constant(...) for tempSettings
                    // The underlying ChatSettingsSheet can directly observe viewModel.appSettings
                    tempSettings: .constant(viewModel.appSettings)
                )
                .onAppear {
                    /**
                     If the user has selected .ollama in the past and the user has not
                     fetched local models, we could attempt to do so again here.
                     Or we can rely on the user to press "Refresh Models" in the UI.
                     */
                }
            }
            // Final async setup each time the view appears (e.g., reload settings & messages)
            .onAppear {
                Task {
                    await viewModel.finalizeSetup()
                }
            }
            // Presents the Settings sheet.
            // Instead of tempSettings: .constant(...), just let ChatSettingsSheet observe the ChatViewModel.
            .sheet(isPresented: $showingSettings) {
                ChatSettingsSheet(
                    // Removed tempSettings; the sheet can reference viewModel.appSettings directly
                    showingSettings: $showingSettings,
                    chatViewModel: viewModel,
                    clearMessages: {
                        viewModel.clearMessages()
                    }
                )
            }
            // Presents user memories in a separate sheet
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
            // Basic nav bar config
            .navigationTitle("Ophelia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Left side: memory list
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingMemories = true
                    } label: {
                        Image(systemName: "list.bullet.rectangle.portrait")
                    }
                }
                // Right side: gear for Settings
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .tint(.blue)
            // ScenePhase changes: you can do cleanup when leaving active state
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase != .active {
                    // e.g., hide keyboard or other cleanup
                }
            }
        }
    }
}
