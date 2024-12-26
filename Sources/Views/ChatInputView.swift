//
//  ChatInputView.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//

import SwiftUI

struct ChatInputView: View {
    @Binding var inputText: String
    let isDisabled: Bool
    let sendAction: () -> Void

    @FocusState.Binding var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    var body: some View {
        VStack(spacing: 0) {
            // A subtle divider or line above the input bar
            Divider()
                .overlay(
                    // If you want the divider to disappear or unify in dark mode,
                    // you could use a softer color from your theme:
                    Color.Theme.textSecondary(isDarkMode: isDarkMode).opacity(0.2)
                )

            HStack(alignment: .bottom, spacing: 12) {
                // The multiline TextField
                TextField("Message...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .disabled(isDisabled)
                    .lineLimit(1...5)
                    .frame(minHeight: 36)
                    .fixedSize(horizontal: false, vertical: true)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled()
                    .submitLabel(.send)
                    .onSubmit(sendAction)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    // Now theming:
                    .background(
                        // We’re calling your bubble background with `isUser: false`
                        // to style it like the assistant or general “system” bubble
                        Color.Theme.bubbleBackground(isDarkMode: isDarkMode, isUser: false)
                            .cornerRadius(12)
                    )
                    // Adjust text color if needed:
                    .foregroundColor(Color.Theme.textPrimary(isDarkMode: isDarkMode))

                // The Send Button
                Button(action: sendAction) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 20))
                        .frame(width: 36, height: 36)
                        .foregroundColor(.white)
                        .background(
                            // Ophelia’s accent gradient from your theme
                            Color.Theme.accentGradient(isDarkMode: isDarkMode)
                                .clipShape(Circle())
                        )
                }
                // Only enable when there’s text & not disabled
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isDisabled)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            // If you want a frosted bar effect, you could do .background(.ultraThinMaterial)
            // or unify it with your bubble BG to keep everything consistent:
            .background(
                Color.Theme.bubbleBackground(isDarkMode: isDarkMode, isUser: false)
                    .opacity(0.95)
            )
        }
        // Instead of a system background, unify with your theme
        .background(
            Color.Theme.bubbleBackground(isDarkMode: isDarkMode, isUser: false)
        )
    }
}
