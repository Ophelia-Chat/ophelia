import SwiftUI

struct MarkdownFormattedText: View {
    let text: String
    let isCodeBlock: Bool
    
    init(_ text: String, isCodeBlock: Bool = false) {
        self.text = text
        self.isCodeBlock = isCodeBlock
    }
    
    var body: some View {
        if let attributedString = try? AttributedString(markdown: text) {
            Text(attributedString)
                .textSelection(.enabled)
                .if(isCodeBlock) { view in
                    view
                        .font(.system(.body, design: .monospaced))
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
        } else {
            Text(text)
                .textSelection(.enabled)
        }
    }
}

// Helper extension for conditional modifiers
extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
