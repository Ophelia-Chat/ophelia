//
//  MessageRow.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//

import SwiftUI

struct MessageRow: View {
    @ObservedObject var message: MutableMessage
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDarkMode: Bool {
        colorScheme == .dark
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if message.isUser {
                Spacer(minLength: 60)
                messageContent
                    .foregroundColor(.white)
                    .background(Color.Theme.accentGradient(isDarkMode: isDarkMode))
            } else {
                messageContent
                    .foregroundColor(Color.Theme.textPrimary(isDarkMode: isDarkMode))
                    .background(Color.Theme.bubbleBackground(isDarkMode: isDarkMode))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    )
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 16)
        .animation(.spring(dampingFraction: 0.8), value: message.text)
    }
    
    private var messageContent: some View {
        Text(message.text)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

#Preview {
    VStack {
        MessageRow(message: MutableMessage(text: "Hello! How are you?", isUser: true))
        MessageRow(message: MutableMessage(text: "I'm doing well, thank you for asking! How are you today?", isUser: false))
    }
}
