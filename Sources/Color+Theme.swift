//
//  Color+Theme.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//

import SwiftUI

extension Color {
    struct Theme {
        /// A soft, paper-like gradient for light mode,
        /// and a darker gradient for dark mode.
        static func primaryGradient(isDarkMode: Bool) -> LinearGradient {
            isDarkMode
                ? LinearGradient(
                    colors: [Color(hex: "2D2438"), Color(hex: "1A1B2E")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  )
                : LinearGradient(
                    // Subtle, near-white tones with a hint of lavender
                    colors: [Color(hex: "F7F5FC"), Color(hex: "FEFEFF")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  )
        }

        /// The background for chat bubbles or panels.
        /// Light mode is a clean, paper-like white with slight opacity,
        /// while dark mode uses a semi-opaque gray.
        static func bubbleBackground(isDarkMode: Bool) -> Color {
            isDarkMode
                ? Color(hex: "2A2A2A").opacity(0.7)
                : Color.white.opacity(0.9)
        }

        /// Primary text color. Lighter gray in dark mode, deep charcoal in light mode.
        static func textPrimary(isDarkMode: Bool) -> Color {
            isDarkMode
                ? Color(hex: "E1E1E1")
                : Color(hex: "2A2A2A")  // a soft black for paper-like contrast
        }

        /// Secondary text color. Dimmer in dark mode, mid-gray in light mode.
        static func textSecondary(isDarkMode: Bool) -> Color {
            isDarkMode
                ? Color(hex: "A0A0A0")
                : Color(hex: "707070")
        }

        /// A refined purple gradient for Ophelia’s accent highlights,
        /// leaning toward elegance in both modes.
        static func accentGradient(isDarkMode: Bool) -> LinearGradient {
            isDarkMode
                ? LinearGradient(
                    colors: [Color(hex: "B389FF"), Color(hex: "7E3CE2")],
                    startPoint: .leading,
                    endPoint: .trailing
                  )
                : LinearGradient(
                    // Soft, sophisticated purples for a regal look
                    colors: [Color(hex: "CAB2F2"), Color(hex: "8A2BE2")],
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
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17,
                            (int >> 4 & 0xF) * 17,
                            (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16,
                            int >> 8 & 0xFF,
                            int & 0xFF)
        case 8: // ARGB (32-bit)
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
