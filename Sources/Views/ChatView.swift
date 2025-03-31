//
//  ChatView.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//  Updated with copy conversation feature
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
    
    /// Controls toast for copy conversation feedback
    @State private var showCopiedToast = false

    /// Watches app's lifecycle states (active, inactive, background)
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
                
                // Overlay for copy toast feedback
                if showCopiedToast {
                    VStack {
                        Spacer()
                        Text("Conversation copied to clipboard")
                            .font(.caption)
                            .padding(8)
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .transition(.opacity)
                            .padding(.bottom, 100)
                    }
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
                
                // Center: Copy Conversation
                ToolbarItem(placement: .principal) {
                    Button {
                        copyConversation()
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .disabled(viewModel.messages.isEmpty)
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
    
    // MARK: - Copy Entire Conversation
    private func copyConversation() {
        let conversationText = viewModel.messages.map { msg in
            let prefix = msg.isUser ? "You: " : "Ophelia: "
            return prefix + msg.text
        }.joined(separator: "\n\n")
        
        UIPasteboard.general.string = conversationText
        
        // Show feedback toast
        withAnimation {
            showCopiedToast = true
        }
        
        // Auto-hide toast after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showCopiedToast = false
            }
        }
    }
}
