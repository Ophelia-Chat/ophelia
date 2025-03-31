//
//  MessageRow.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//  Updated to ensure proper Markdown layout constraints and prevent scrolling issues.
//  Added copy functionality with visual feedback
//

import SwiftUI
import MarkdownUI

struct MessageRow: View {
    @ObservedObject var message: MutableMessage
    let appSettings: AppSettings
    @Environment(\.colorScheme) private var colorScheme
    @State private var showCopiedToast = false

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
            // Display message header (provider, model, timestamp)
            messageHeader
            
            HStack(alignment: .bottom, spacing: 12) {
                if message.isUser {
                    Spacer(minLength: 60)
                    userMessageContent
                        .contextMenu {
                            Button(action: {
                                UIPasteboard.general.string = message.text
                                withAnimation {
                                    showCopiedToast = true
                                }
                                // Auto-hide toast after delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    withAnimation {
                                        showCopiedToast = false
                                    }
                                }
                            }) {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                        }
                        .overlay(alignment: .center) {
                            if showCopiedToast {
                                copiedToast
                            }
                        }
                } else {
                    assistantMessageContent
                        .contextMenu {
                            Button(action: {
                                UIPasteboard.general.string = message.text
                                withAnimation {
                                    showCopiedToast = true
                                }
                                // Auto-hide toast after delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    withAnimation {
                                        showCopiedToast = false
                                    }
                                }
                            }) {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                        }
                        .overlay(alignment: .center) {
                            if showCopiedToast {
                                copiedToast
                            }
                        }
                    Spacer(minLength: 60)
                }
            }
        }
        .padding(.horizontal, 16)
        // Animate layout changes smoothly as text updates
        .animation(.easeInOut(duration: 0.2), value: message.text)
    }
    
    // MARK: - Message Header
    private var messageHeader: some View {
        HStack {
            if message.isUser {
                Text("You")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(message.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                let providerName = message.originProvider ?? appSettings.selectedProvider.rawValue
                let modelName = message.originModel ?? appSettings.selectedModel.name
                Text("\(providerName) - \(modelName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(message.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - User Message Content
    private var userMessageContent: some View {
        // Applying .fixedSize and .frame to ensure Markdown wraps and doesn't cause layout issues.
        Markdown(message.text)
            .markdownTextStyle {
                ForegroundColor(Color.white)
            }
            .fixedSize(horizontal: false, vertical: true) // Allows vertical expansion but no infinite horizontal growth
            .frame(maxWidth: .infinity, alignment: .leading) // Ensures text wraps within the available width
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.Theme.accentGradient(isDarkMode: isDarkMode))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.05), radius: 8, y: 2)
            .overlay(alignment: .bottomTrailing) {
                copyButton
            }
    }

    // MARK: - Assistant Message Content
    private var assistantMessageContent: some View {
        // Similar layout constraints for assistant messages to ensure consistent behavior.
        Markdown(message.text)
            .fixedSize(horizontal: false, vertical: true) // Prevents infinite horizontal growth
            .frame(maxWidth: .infinity, alignment: .leading) // Enforces wrapping within view bounds
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Color.Theme.bubbleBackground(isDarkMode: isDarkMode, isUser: false)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.Theme.textSecondary(isDarkMode: isDarkMode).opacity(0.3), lineWidth: 1)
            )
            .overlay(alignment: .bottomTrailing) {
                copyButton
            }
    }
    
    // MARK: - Copy Button
    private var copyButton: some View {
        Button(action: {
            UIPasteboard.general.string = message.text
            withAnimation {
                showCopiedToast = true
            }
            // Auto-hide toast after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    showCopiedToast = false
                }
            }
        }) {
            Image(systemName: "doc.on.doc")
                .font(.caption)
                .padding(6)
                .background(Color.Theme.bubbleBackground(isDarkMode: isDarkMode, isUser: message.isUser).opacity(0.8))
                .clipShape(Circle())
                .foregroundColor(Color.Theme.textPrimary(isDarkMode: isDarkMode))
        }
        .buttonStyle(BorderlessButtonStyle())
        .opacity(0.7)
        .padding(8)
    }
    
    // MARK: - Copied Toast
    private var copiedToast: some View {
        Text("Copied to clipboard")
            .font(.caption)
            .padding(8)
            .background(Color.black.opacity(0.6))
            .foregroundColor(.white)
            .cornerRadius(8)
            .transition(.opacity)
    }
}
