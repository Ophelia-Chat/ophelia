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
    @FocusState private var fieldIsFocused: Bool
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("isDarkMode") private var isDarkMode = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                Color.Theme.primaryGradient(isDarkMode: isDarkMode)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Chat messages container (auto-scroll enabled)
                    ChatMessagesContainer(
                        messages: viewModel.messages,
                        isLoading: viewModel.isLoading,
                        appSettings: viewModel.appSettings
                    )
                    .transition(.opacity)
                    .onTapGesture {
                        dismissKeyboard()
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
                // Finalize setup when view appears
                Task {
                    await viewModel.finalizeSetup()
                }
            }
            .sheet(isPresented: $showingSettings, onDismiss: {
                // Re-finalize settings after sheet is dismissed
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
            .tint(.blue)
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase != .active {
                    fieldIsFocused = false
                }
            }
        }
    }

    // MARK: - Helpers

    /// Dismiss the keyboard manually
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    /// Placeholder view shown when no messages are present
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

    /// Provide gentle haptic feedback when sending a message
    private func provideHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}
