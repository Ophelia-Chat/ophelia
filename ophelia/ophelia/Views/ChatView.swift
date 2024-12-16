//
//  ChatView.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//

import SwiftUI
import Combine

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var showingSettings = false
    @State private var tempSettings = AppSettings()
    @FocusState private var fieldIsFocused: Bool
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("isDarkMode") private var isDarkMode = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Use the primary gradient as background
                Color.Theme.primaryGradient(isDarkMode: isDarkMode)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // If no messages yet, show a placeholder
                    if viewModel.messages.isEmpty && !viewModel.isLoading {
                        placeholderView
                            .transition(.opacity.combined(with: .scale))
                    } else {
                        // Main chat messages container
                        ChatMessagesContainer(
                            messages: viewModel.messages,
                            isLoading: viewModel.isLoading,
                            appSettings: viewModel.appSettings
                        )
                        .transition(.opacity)
                    }

                    // Input field and send button
                    ChatInputContainer(
                        inputText: $viewModel.inputText,
                        isDisabled: viewModel.appSettings.currentAPIKey.isEmpty,
                        onSend: {
                            Task { @MainActor in
                                viewModel.sendMessage()
                                fieldIsFocused = false
                                provideHapticFeedback()
                            }
                        }
                    )
                    .padding(.top, 4)
                }
            }
            .preferredColorScheme(isDarkMode ? .dark : .light)
            .onAppear {
                // Finalize setup on appear
                Task {
                    await viewModel.finalizeSetup()
                }
            }
            // Present SettingsView in a NavigationStack to enable navigation links within settings
            .sheet(isPresented: $showingSettings, onDismiss: {
                // Re-initialize settings after the sheet is dismissed
                Task { @MainActor in
                    await viewModel.finalizeSetup()
                }
            }) {
                NavigationStack {
                    SettingsView(clearMessages: {
                        viewModel.clearMessages()
                    })
                }
            }
            .navigationTitle("Ophelia")
            .navigationBarTitleDisplayMode(.inline)
            .tint(.blue)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gear")
                            .font(.system(size: 20))
                    }
                }
            }
            // Dismiss the keyboard if the scene moves to background
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase != .active {
                    fieldIsFocused = false
                }
            }
        }
    }

    // Placeholder view shown when there are no messages yet
    private var placeholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "message")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No messages yet.")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Type a message below to start the conversation.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    // Provide a gentle haptic feedback when sending a message
    private func provideHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}
