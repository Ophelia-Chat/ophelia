import SwiftUI

struct ChatBubbleView: View {
    let message: any Message
    
    private func isCodeBlock(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).starts(with: "```")
    }
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                MarkdownFormattedText(message.text, isCodeBlock: isCodeBlock(message.text))
                    .foregroundColor(message.isUser ? .white : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(message.isUser ? Color.blue : Color(.systemGray6))
                    .cornerRadius(16)
                
                Text(message.timestamp.formatted(.dateTime.hour().minute()))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
            }
            
            if !message.isUser {
                Spacer()
            }
        }
        .padding(.horizontal)
    }
}
