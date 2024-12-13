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

    // Use a fixed constant for petalCount to avoid compile-time issues
    private let petalCount = 5

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)

            ZStack {
                // BACK LAYER PETALS: Just apply opacity directly
                ForEach(0..<petalCount, id: \.self) { index in
                    Petal(isBackLayer: true)
                        .fill(Color.Theme.accentGradient(isDarkMode: isDarkMode)
                                .opacity(0.5))
                        .frame(width: size * 0.45, height: size * 0.65)
                        .rotationEffect(.degrees(Double(index) * (360.0 / Double(petalCount))))
                }

                // FRONT LAYER PETALS
                ForEach(0..<petalCount, id: \.self) { index in
                    Petal(isBackLayer: false)
                        .fill(Color.Theme.accentGradient(isDarkMode: isDarkMode))
                        .frame(width: size * 0.4, height: size * 0.6)
                        .rotationEffect(.degrees(Double(index) * (360.0 / Double(petalCount))))
                }

                // CENTER ELEMENTS
                Circle()
                    .fill(Color.Theme.accentGradient(isDarkMode: isDarkMode))
                    .frame(width: size * 0.2)

                Circle()
                    .fill(Color.white.opacity(isDarkMode ? 0.3 : 0.5))
                    .frame(width: size * 0.1)

                ForEach(0..<8, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(isDarkMode ? 0.3 : 0.5))
                        .frame(width: size * 0.03)
                        .offset(x: 0, y: -size * 0.1)
                        .rotationEffect(.degrees(Double(i) * 45))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct Petal: Shape {
    var isBackLayer: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Start at top center
        path.move(to: CGPoint(x: rect.midX, y: 0))
        
        let controlOffsetX: CGFloat = isBackLayer ? rect.width * 0.35 : rect.width * 0.25
        let controlOffsetY: CGFloat = isBackLayer ? rect.height * 0.6 : rect.height * 0.5

        // Curve down the left side
        path.addCurve(
            to: CGPoint(x: rect.midX - rect.width * 0.1, y: rect.maxY * 0.8),
            control1: CGPoint(x: rect.midX - controlOffsetX, y: rect.height * 0.3),
            control2: CGPoint(x: rect.midX - rect.width * 0.2, y: controlOffsetY)
        )

        // Curve back up right side, adding asymmetry
        path.addCurve(
            to: CGPoint(x: rect.midX, y: 0),
            control1: CGPoint(x: rect.midX + rect.width * 0.1, y: rect.height * 0.9),
            control2: CGPoint(x: rect.midX + controlOffsetX, y: rect.height * 0.4)
        )

        return path
    }
}
