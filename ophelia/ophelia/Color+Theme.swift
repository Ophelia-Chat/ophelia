//
//  Color+Theme.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//

import SwiftUI

extension Color {
    struct Theme {
        @AppStorage("isDarkMode") private static var isDarkMode = false
        
        static let primaryGradient = {
            isDarkMode
                ? LinearGradient(colors: [Color(hex: "2D2438"), Color(hex: "1A1B2E")], startPoint: .topLeading, endPoint: .bottomTrailing)
                : LinearGradient(colors: [Color(hex: "f8e1e8"), Color(hex: "e8f1f8")], startPoint: .topLeading, endPoint: .bottomTrailing)
        }()
        
        static let bubbleBackground = {
            isDarkMode ? Color(hex: "2A2A2A").opacity(0.7) : Color(hex: "FFFFFF").opacity(0.7)
        }()
        
        static let textPrimary = {
            isDarkMode ? Color(hex: "E1E1E1") : Color(hex: "4A4A4A")
        }()
        
        static let textSecondary = {
            isDarkMode ? Color(hex: "A0A0A0") : Color(hex: "808080")
        }()
        
        static let accentGradient = {
            isDarkMode
                ? LinearGradient(colors: [Color(hex: "FF1493"), Color(hex: "8A2BE2")], startPoint: .leading, endPoint: .trailing)
                : LinearGradient(colors: [Color(hex: "FF69B4"), Color(hex: "9370DB")], startPoint: .leading, endPoint: .trailing)
        }()
    }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
