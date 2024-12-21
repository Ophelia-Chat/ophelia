//
//  ChatMessagesContainer.swift
//  ophelia
//
//  This file displays chat messages in a scrollable view and manages
//  smooth auto-scrolling for AI token streaming.
//
//  Key Features:
//  1. Uses ScrollViewReader to programmatically scroll to the bottom.
//  2. Declares a sentinel view (id: "bottomID") at the end of the list.
//  3. Maintains a local "autoScroll" state to decide whether to stay pinned
//     to the bottom or allow the user to freely scroll.
//  4. Respects user interactions: if the user drags up, auto-scroll is turned off.
//     The user can scroll back down or provide another mechanism to re-enable it.
//

import SwiftUI

struct ChatMessagesContainer: View {
    let messages: [MutableMessage]
    let isLoading: Bool
    let appSettings: AppSettings

    // Tracks whether we should automatically scroll to the bottom.
    // Starts as true so that new messages or tokens keep the view pinned at the bottom.
    @State private var autoScroll = true

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // We use a LazyVStack to efficiently render messages.
                LazyVStack(spacing: 8) {
                    ForEach(messages) { message in
                        MessageRow(message: message, appSettings: appSettings)
                    }

                    // Show typing indicator (e.g., animated dots) if the AI is "typing."
                    if isLoading {
                        TypingIndicator()
                            .padding(.top, 8)
                    }

                    // Invisible anchor to which we scroll.
                    Color.clear
                        .frame(height: 1)
                        .id("bottomID")
                }
                .padding(.vertical, 8)
                // Auto-scroll on initial appear.
                .onAppear {
                    scrollToBottom(proxy: proxy, animated: false)
                }
                // Auto-scroll whenever messages change, if autoScroll is still true.
                .onChange(of: messages) { _, _ in
                    if autoScroll {
                        scrollToBottom(proxy: proxy)
                    }
                }
                // Optionally, also scroll when loading state changes (if you want to follow the typing indicator).
                .onChange(of: isLoading) { _, _ in
                    if autoScroll {
                        scrollToBottom(proxy: proxy)
                    }
                }
                // Gesture to detect manual user scrolling. If the user drags up, disable auto-scroll.
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // If user drags significantly upward, disable auto-scrolling.
                            if value.translation.height > 0 {
                                autoScroll = false
                            }
                        }
                )
            }
            // Tap anywhere in the scroll view to dismiss keyboard (optional).
            .gesture(
                TapGesture()
                    .onEnded {
                        dismissKeyboard()
                    }
            )
        }
    }

    // MARK: - Scroll Helper

    /// Smoothly scroll to the bottom anchor (id: "bottomID").
    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        withAnimation(animated ? .easeInOut(duration: 0.3) : nil) {
            proxy.scrollTo("bottomID", anchor: .bottom)
        }
    }

    // MARK: - Keyboard Dismiss Helper
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}
