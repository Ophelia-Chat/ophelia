//
//  MessageRow.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//

import SwiftUI
import MarkdownUI

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
                
                Markdown(message.text)
                    .markdownTextStyle {
                        // Return a TextStyle-conforming type directly
                        ForegroundColor(Color.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.Theme.accentGradient(isDarkMode: isDarkMode))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: Color.black.opacity(0.05), radius: 8, y: 2)
                
            } else {
                Markdown(message.text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
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
}
