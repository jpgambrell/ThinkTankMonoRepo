//
//  Colors.swift
//  ThinkTank
//
//  Created by John Gambrell on 1/29/26.
//

import SwiftUI

// MARK: - Color Extension for Hex Support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - App Colors
extension Color {
    // Primary brand colors
    static let brandPrimary = Color(hex: "059669")
    static let brandPrimaryLight = Color(hex: "D1FAE5")
    static let brandPrimaryDark = Color(hex: "047857")
    
    // Semantic colors
    static let destructive = Color(hex: "E53935")
    static let destructiveLight = Color(hex: "FFEBEE")
}

// MARK: - Theme-Aware Colors
struct ThemeColors {
    // Background colors
    static func windowBackground(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "1A1A1A") : Color(hex: "F7F7F8")
    }
    
    static func sidebarBackground(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "252525") : Color(hex: "F0F0F1")
    }
    
    static func cardBackground(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "2D2D2D") : .white
    }
    
    static func inputBackground(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "3A3A3A") : Color(hex: "F7F7F8")
    }
    
    // Text colors
    static func primaryText(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "F0F0F0") : Color(hex: "1A1A1A")
    }
    
    static func secondaryText(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "A0A0A0") : Color(hex: "666666")
    }
    
    static func tertiaryText(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "707070") : Color(hex: "888888")
    }
    
    static func placeholderText(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "606060") : Color(hex: "999999")
    }
    
    // Border colors
    static func border(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "404040") : Color(hex: "E0E0E0")
    }
    
    static func divider(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "3A3A3A") : Color(hex: "E5E5E6")
    }
    
    // Message bubbles
    static func userBubble(_ colorScheme: ColorScheme) -> Color {
        Color.brandPrimary
    }
    
    static func assistantBubble(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "3A3A3A") : Color(hex: "F7F7F8")
    }
    
    // Selection/Hover states
    static func selectedBackground(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "3A3A3A") : .white
    }
    
    static func hoverBackground(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "333333") : Color(hex: "F5F5F5")
    }
    
    // User profile section
    static func userProfileBackground(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "E8E8E9")
    }
}
