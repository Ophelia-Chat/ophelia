//
//  TypingIndicator.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//

import SwiftUI

struct TypingIndicator: View {
    @State private var phase: CGFloat = 0
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDarkMode: Bool {
        colorScheme == .dark
    }
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                let angle = phase + Double(index) * .pi / 2
                let scaleValue = 0.5 + 0.5 * sin(angle)
                
                Circle()
                    .fill(Color.Theme.accentGradient(isDarkMode: isDarkMode))
                    .frame(width: 8, height: 8)
                    .scaleEffect(scaleValue)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Color.Theme.bubbleBackground(isDarkMode: isDarkMode, isUser: false)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                phase = 2 * .pi
            }
        }
    }
}
