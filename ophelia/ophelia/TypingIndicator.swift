//
//  TypingIndicator.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//

import SwiftUI

struct TypingIndicator: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.Theme.accentGradient)
                    .frame(width: 8, height: 8)
                    .scaleEffect(0.5 + 0.5 * sin(phase + Double(index) * .pi / 2))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.Theme.bubbleBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                phase = 2 * .pi
            }
        }
    }
}
