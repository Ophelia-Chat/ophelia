//
//  ChatInputContainer.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//

import SwiftUI

struct ChatInputContainer: View {
    @Binding var inputText: String
    let isDisabled: Bool
    let onSend: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 12) {
                TextField("Message Ophelia...", text: $inputText, axis: .vertical)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    // Call the theme function with isDarkMode
                    .background(Color.Theme.bubbleBackground(isDarkMode: isDarkMode))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    )
                
                Button(action: onSend) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        // Call theme function with isDarkMode
                        .background(Color.Theme.accentGradient(isDarkMode: isDarkMode))
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.1), radius: 5)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isDisabled)
                .scaleEffect(isDisabled ? 0.95 : 1)
                .animation(.spring(dampingFraction: 0.7), value: isDisabled)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            // Separate background layers into multiple modifiers
            .background(.ultraThinMaterial)
            .background(Color.white.opacity(0.5))
        }
    }
}
