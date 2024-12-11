//
//  ChatMessagesView.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//

import SwiftUI

struct ChatMessagesView: View {
    let messages: [MutableMessage]
    let isLoading: Bool
    @Namespace private var bottomID
    @Environment(\.colorScheme) private var colorScheme

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // Use LazyVStack to handle large message lists efficiently
                LazyVStack(spacing: 8) {
                    ForEach(messages) { message in
                        // Each message is identified by its UUID, ensuring stable rendering
                        MessageRow(message: message)
                            .id(message.id)
                    }

                    if isLoading {
                        TypingIndicator()
                            .padding(.top, 8)
                    }

                    // A clear spacer at the bottom to scroll to
                    Color.clear
                        .frame(height: 1)
                        .id(bottomID)
                }
                .padding(.vertical, 8)
            }
            // Automatically scroll to the bottom when messages change
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            // Automatically scroll to the bottom when loading state changes
            .onChange(of: isLoading) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut) {
            proxy.scrollTo(bottomID, anchor: .bottom)
        }
    }
}
