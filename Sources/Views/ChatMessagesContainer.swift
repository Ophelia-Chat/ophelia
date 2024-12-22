//
//  ChatMessagesContainer.swift
//  ophelia
//
//  Revised to remain pinned at bottom on new messages,
//  yet still allow the user to scroll freely if desired.
//
import SwiftUI

@available(iOS 18.0, *)
struct ChatMessagesContainer: View {
    /// The array of messages to display.
    let messages: [MutableMessage]
    
    /// Indicates whether the AI is generating a response (e.g., "typing").
    let isLoading: Bool
    
    /// Global app settings, in case you need to style based on them.
    let appSettings: AppSettings

    /// Tracks whether the view automatically scrolls to the bottom on new messages.
    @State private var autoScroll = true

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(messages) { message in
                        MessageRow(message: message, appSettings: appSettings)
                    }

                    if isLoading {
                        TypingIndicator()
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("bottomID")
                }
                .padding(.vertical, 8)
                // 1) Scroll to bottom on first appear
                .onAppear {
                    scrollToBottom(proxy: proxy, animated: false)
                }
                // 2) Auto-scroll if the total message count changes
                .onChange(of: messages.count) { oldCount, newCount in
                    if autoScroll {
                        scrollToBottom(proxy: proxy)
                    }
                }
                // 3) Auto-scroll if isLoading changes
                .onChange(of: isLoading) { wasLoading, isLoadingNow in
                    if autoScroll {
                        scrollToBottom(proxy: proxy)
                    }
                }
                // 4) Auto-scroll on partial token updates
                //    if the last message’s text changes
                .onChange(of: messages.last?.text) { oldText, newText in
                    guard autoScroll else { return }
                    // Add slight delay so layout can recalc the new size
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        scrollToBottom(proxy: proxy)
                    }
                }
            }
            // 5) OPTIONAL: remove or comment out if you don’t want to dismiss the keyboard on tap
            /*
            .gesture(
                TapGesture()
                    .onEnded {
                        dismissKeyboard()
                    }
            )
            */
        }
    }

    // MARK: - Helpers

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        withAnimation(animated ? .easeInOut(duration: 0.3) : nil) {
            proxy.scrollTo("bottomID", anchor: .bottom)
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil,
                                        from: nil,
                                        for: nil)
    }
}
