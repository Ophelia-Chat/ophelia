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

    var body: some View {
        ZStack {
            // 1) A gradient background behind everything
            Color.Theme.primaryGradient(isDarkMode: viewModel.appSettings.isDarkMode)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 2) The scrollable chat container
                ChatMessagesContainer(
                    messages: viewModel.messages,
                    isLoading: viewModel.isLoading,
                    appSettings: viewModel.appSettings
                )
                // OPTIONAL: If you want a tap outside the text field to dismiss the keyboard
                // .onTapGesture {
                //     dismissKeyboard()
                // }

                // 3) The input bar
                ChatInputContainer(
                    inputText: $viewModel.inputText,
                    isDisabled: viewModel.appSettings.currentAPIKey.isEmpty,
                    onSend: {
                        Task { @MainActor in
                            viewModel.sendMessage()
                            // Don’t clear focus if you want keyboard to stay
                            // fieldIsFocused = false
                        }
                    }
                )
                .focused($fieldIsFocused)
            }
            // 4) Move entire stack above the keyboard
            .keyboardAdaptive()
        }
    }

    // Let user manually dismiss keyboard by swiping down or tapping outside
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}
