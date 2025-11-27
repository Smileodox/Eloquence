//
//  ColorTheme.swift
//  Eloquence
//
//  Created by Johannes Gruber on 10.11.25.
//

import SwiftUI

extension Color {
    // Background colors
    static let bgDark = Color(hue: 255/360, saturation: 0.35, brightness: 0.1)
    static let bg = Color(hue: 255/360, saturation: 0.23, brightness: 0.15)
    static let bgLight = Color(hue: 255/360, saturation: 0.175, brightness: 0.2)
    
    // Text colors
    static let textPrimary = Color(hue: 255/360, saturation: 0.073, brightness: 0.96)
    static let textMuted = Color(hue: 255/360, saturation: 0.092, brightness: 0.76)
    static let highlight = Color(hue: 255/360, saturation: 0.14, brightness: 0.5)
    
    // Border colors
    static let border = Color(hue: 255/360, saturation: 0.175, brightness: 0.4)
    static let borderMuted = Color(hue: 255/360, saturation: 0.233, brightness: 0.3)
    
    // Brand colors
    static let primary = Color(hue: 255/360, saturation: 0.132, brightness: 0.76)
    static let secondary = Color(hue: 75/360, saturation: 0.132, brightness: 0.76)
    
    // Semantic colors
    static let danger = Color(hue: 30/360, saturation: 0.1, brightness: 0.7)
    static let warning = Color(hue: 100/360, saturation: 0.1, brightness: 0.7)
    static let success = Color(hue: 160/360, saturation: 0.1, brightness: 0.7)
    static let info = Color(hue: 260/360, saturation: 0.1, brightness: 0.7)
}

// Theme environment
struct Theme {
    static let cornerRadius: CGFloat = 16
    static let smallCornerRadius: CGFloat = 12
    static let buttonHeight: CGFloat = 56
    static let spacing: CGFloat = 16
    static let largeSpacing: CGFloat = 24
}

