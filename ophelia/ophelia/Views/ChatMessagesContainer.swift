//
//  ChatMessagesContainer.swift
//  ophelia
//

import SwiftUI

struct ChatMessagesContainer: View {
    let messages: [MutableMessage]
    let isLoading: Bool
    let appSettings: AppSettings

    @State private var shouldScrollToBottom = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    // Render all chat messages
                    ForEach(messages) { message in
                        MessageRow(message: message, appSettings: appSettings)
                    }

                    // Show typing indicator when loading
                    if isLoading {
                        TypingIndicator()
                            .padding(.top, 8)
                    }

                    // Invisible anchor at the bottom for scrolling
                    Color.clear
                        .frame(height: 1)
                        .id("bottomID")
                }
                .padding(.vertical, 8)
                .onAppear {
                    // Ensure it scrolls to bottom on initial load
                    scrollToBottom(proxy: proxy, animated: false)
                }
                .onChange(of: messages) { _, _ in
                    // Scroll to bottom when messages update
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: isLoading) { _, _ in
                    // Scroll to bottom when loading starts or stops
                    scrollToBottom(proxy: proxy)
                }
            }
            .gesture(
                TapGesture()
                    .onEnded {
                        dismissKeyboard()
                    }
            )
        }
    }

    // MARK: - Scroll Helper

    /// Smoothly scroll to the bottom anchor
    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        withAnimation(animated ? .easeInOut(duration: 0.3) : nil) {
            proxy.scrollTo("bottomID", anchor: .bottom)
        }
    }

    // MARK: - Keyboard Dismiss Helper
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
