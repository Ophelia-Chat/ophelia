//
//  FlowerLogoView.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//

import SwiftUI

struct FlowerLogoView: View {
    @Environment(\.colorScheme) private var colorScheme
    private var isDarkMode: Bool { colorScheme == .dark }
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            ZStack {
                ForEach(0..<5) { index in
                    Petal()
                        .fill(Color.Theme.accentGradient(isDarkMode: isDarkMode))
                        .frame(width: size * 0.4, height: size * 0.6)
                        .rotationEffect(.degrees(Double(index) * 72))
                }
                Circle()
                    .fill(Color.Theme.accentGradient(isDarkMode: isDarkMode))
                    .frame(width: size * 0.2)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct Petal: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: 0))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.minX, y: rect.height * 0.3),
            control2: CGPoint(x: rect.maxX, y: rect.height * 0.7)
        )
        return path
    }
}
