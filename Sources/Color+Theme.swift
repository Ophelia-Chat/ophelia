//
//  Color+Theme.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//

import SwiftUI

extension Color {
    struct Theme {

        /// Primary background gradient
        static func primaryGradient(isDarkMode: Bool) -> LinearGradient {
            isDarkMode
                // A near-black gradient with slight variation
                ? LinearGradient(
                    colors: [
                        Color(hex: "111111"),
                        Color(hex: "1A1A1A")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  )
                : LinearGradient(
                    // Light/paper-like for normal mode
                    colors: [Color(hex: "F7F5FC"), Color(hex: "FEFEFF")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  )
        }

        /// Chat bubble background
        /// For dark mode: user bubbles get a richer purple or dark gray,
        /// assistant bubbles get a simpler dark gray.
        static func bubbleBackground(isDarkMode: Bool, isUser: Bool) -> Color {
            guard isDarkMode else {
                return Color.white.opacity(0.9) // paper-like in light mode
            }
            // In dark mode:
            if isUser {
                // A subtle purple-tinted dark color for the user bubble
                return Color(hex: "292137") // tweak to preference (hint of purple)
            } else {
                // A neutral dark gray for assistant
                return Color(hex: "1E1E1E")
            }
        }

        /// Primary text color
        static func textPrimary(isDarkMode: Bool) -> Color {
            isDarkMode
                ? Color(hex: "E5E5E5") // softer white to reduce glare
                : Color(hex: "2A2A2A")
        }

        /// Secondary text color
        static func textSecondary(isDarkMode: Bool) -> Color {
            isDarkMode
                ? Color(hex: "A0A0A0")
                : Color(hex: "707070")
        }

        /// Ophelia’s accent gradient (buttons, highlights, etc.)
        static func accentGradient(isDarkMode: Bool) -> LinearGradient {
            isDarkMode
                ? LinearGradient(
                    colors: [
                        Color(hex: "9B6BD1"),
                        Color(hex: "6B3EA6")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  )
                : LinearGradient(
                    colors: [
                        Color(hex: "CAB2F2"),
                        Color(hex: "8A2BE2")
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                  )
        }
    }

    /// Initializes a Color from a hex string.
    init(hex: String) {
        let hexValue = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hexValue).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hexValue.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17,
                            (int >> 4 & 0xF) * 17,
                            (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16,
                            int >> 8 & 0xFF,
                            int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF,
                            (int >> 16) & 0xFF,
                            (int >> 8) & 0xFF,
                            int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red:   Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
