//
//  ChatInputView.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//

import SwiftUI

struct ChatInputView: View {
    @Binding var inputText: String
    let isDisabled: Bool
    let sendAction: () -> Void
    @FocusState.Binding var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider() // A simple divider above the input bar

            HStack(alignment: .bottom, spacing: 12) {
                TextField("Message...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    }
                    .focused($isFocused)
                    .disabled(isDisabled)
                    .lineLimit(1...5)
                    .frame(minHeight: 36)
                    .fixedSize(horizontal: false, vertical: true)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled()
                    .submitLabel(.send)
                    .onSubmit(sendAction)

                Button(action: sendAction) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 20))
                        .frame(width: 36, height: 36)
                        .foregroundColor(.white)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isDisabled)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background {
            // A background that ensures the input bar looks good with the system background
            Rectangle()
                .fill(Color(.systemBackground))
                .ignoresSafeArea(edges: .bottom)
        }
    }
}
