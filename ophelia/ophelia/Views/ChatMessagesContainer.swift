//
//  ChatMessagesContainer.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//

import SwiftUI

struct ChatMessagesContainer: View {
    let messages: [MutableMessage]
    let isLoading: Bool
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(messages) { message in
                        MessageRow(message: message)
                    }
                    
                    if isLoading {
                        TypingIndicator()
                            .padding(.top, 8)
                    }
                    
                    Color.clear
                        .frame(height: 1)
                        .id("bottomID")
                }
                .padding(.vertical, 8)
            }
            .onChange(of: messages.count) { _, _ in
                withAnimation {
                    proxy.scrollTo("bottomID", anchor: .bottom)
                }
            }
            .onChange(of: isLoading) { _, _ in
                withAnimation {
                    proxy.scrollTo("bottomID", anchor: .bottom)
                }
            }
        }
    }
}
