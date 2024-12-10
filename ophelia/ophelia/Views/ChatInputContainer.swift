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
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 12) {
                TextField("Message Ophelia...", text: $inputText, axis: .vertical)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.Theme.bubbleBackground)
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
                        .background(Color.Theme.accentGradient)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.1), radius: 5)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isDisabled)
                .scaleEffect(isDisabled ? 0.95 : 1)
                .animation(.spring(dampingFraction: 0.7), value: isDisabled)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Color.white.opacity(0.5)
                    .background(.ultraThinMaterial)
            )
        }
    }
}
