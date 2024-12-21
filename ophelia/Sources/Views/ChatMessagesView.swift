//
//  ChatMessagesView.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//  Now that Markdown is integrated into MessageRow, no need for MarkdownFormattedText.
//

import SwiftUI

struct ChatMessagesView: View {
    let messages: [MutableMessage]
    let isLoading: Bool
    let appSettings: AppSettings
    @Namespace private var bottomID
    @Environment(\.colorScheme) private var colorScheme

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(messages) { message in
                        MessageRow(message: message, appSettings: appSettings)
                    }

                    if isLoading {
                        TypingIndicator()
                            .padding(.top, 8)
                    }

                    Color.clear
                        .frame(height: 1)
                        .id(bottomID)
                }
                .padding(.vertical, 8)
            }
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
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
