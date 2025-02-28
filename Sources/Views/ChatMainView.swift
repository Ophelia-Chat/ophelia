//
//  ChatMainView.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//

import SwiftUI

struct ChatMainView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var showingSettings: Bool
    @Binding var tempSettings: AppSettings

    // Tracks whether the text field is focused
    @FocusState private var fieldIsFocused: Bool

    // Use the device’s color scheme in case your themeMode == .system
    @Environment(\.colorScheme) private var colorScheme

    // Decide if we should display “dark mode” colors or not
    private var isDarkMode: Bool {
        switch viewModel.appSettings.themeMode {
        case .dark:
            return true
        case .light:
            return false
        case .system:
            // fallback to the user’s actual device preference
            return (colorScheme == .dark)
        }
    }

    var body: some View {
        ZStack {
            // A gradient background behind everything
            Color.Theme.primaryGradient(isDarkMode: isDarkMode)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // The scrollable chat container
                ChatMessagesContainer(
                    messages: viewModel.messages,
                    isLoading: viewModel.isLoading,
                    appSettings: viewModel.appSettings
                )
                // Dismiss keyboard if user taps outside the input field
                .onTapGesture {
                    dismissKeyboard()
                }

                // The chat input bar
                ChatInputContainer(
                    inputText: $viewModel.inputText,
                    isDisabled: {
                        switch viewModel.appSettings.selectedProvider {
                        case .openAI, .anthropic, .githubModel:
                            return viewModel.appSettings.currentAPIKey.isEmpty
                        case .ollama:
                            return false
                        }
                    }(),
                    onSend: {
                        Task { @MainActor in
                            viewModel.sendMessage()
                        }
                    }
                )
                .focused($fieldIsFocused)
            }
            // Ensures the VStack moves above the software keyboard
            .keyboardAdaptive()
        }
    }

    // Let user manually dismiss keyboard by tapping outside textfield
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}
