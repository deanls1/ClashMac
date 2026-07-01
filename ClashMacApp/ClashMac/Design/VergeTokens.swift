import AppKit
import SwiftUI

// MARK: - Verge-inspired design tokens

enum VergeLayout {
    static let sidebarWidth: CGFloat = 200
    static let topBarHeight: CGFloat = 0
    static let contentPadding: CGFloat = 22
    static let cardRadius: CGFloat = 12
    static let nodeCardMinWidth: CGFloat = 148
    static let powerButtonSize: CGFloat = 96
    static let pageMaxWidth: CGFloat = 1120
    static let settingsMaxWidth: CGFloat = 1040
    static let settingsLabelWidth: CGFloat = 108
    static let settingsGearSlotWidth: CGFloat = 28
    static let settingsRowMinHeight: CGFloat = 30
    static let settingsCardPadding: CGFloat = 14
    static let settingsRowSpacing: CGFloat = 1
    static let settingsGridSpacing: CGFloat = 12
    static let homeMaxWidth: CGFloat = pageMaxWidth
    static let homeGridSpacing: CGFloat = 16
}

enum VergeColor {
    static let accent = Color(red: 0.09, green: 0.47, blue: 1.0)
    static let accentSoft = Color(red: 0.09, green: 0.47, blue: 1.0).opacity(0.14)
    static let accentGlow = Color(red: 0.09, green: 0.47, blue: 1.0).opacity(0.28)
    static let upload = Color(red: 0.96, green: 0.45, blue: 0.18)
    static let download = Color(red: 0.20, green: 0.58, blue: 0.98)
    static let running = Color(red: 0.18, green: 0.78, blue: 0.48)
    static let stopped = Color.secondary
    static let danger = Color(red: 0.94, green: 0.32, blue: 0.32)

    static var canvas: Color { adaptive(light: 0.965, dark: 0.08) }
    static var sidebarBG: Color { adaptive(light: 0.998, dark: 0.06) }
    static var cardFill: Color { adaptive(light: 1.0, dark: 0.12) }
    static var surface: Color { adaptive(light: 0.0, dark: 1.0, lightAlpha: 0.045, darkAlpha: 0.06) }
    static var surfaceElevated: Color { adaptive(light: 1.0, dark: 0.14) }
    static var border: Color { adaptive(light: 0.0, dark: 1.0, lightAlpha: 0.08, darkAlpha: 0.12) }
    static var shadow: Color { Color.black.opacity(0.045) }
    static var heroGlow: Color { accentGlow.opacity(0.45) }

    private static func adaptive(
        light: CGFloat,
        dark: CGFloat,
        lightAlpha: CGFloat? = nil,
        darkAlpha: CGFloat? = nil
    ) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            if let lightAlpha, let darkAlpha {
                return NSColor(white: 1.0, alpha: isDark ? darkAlpha : lightAlpha)
            }
            let value = isDark ? dark : light
            return NSColor(red: value, green: value, blue: value, alpha: 1)
        })
    }

    static func latency(_ ms: Int?) -> Color {
        guard let ms else { return .secondary }
        switch ms {
        case ..<80: return running
        case ..<200: return Color(red: 0.95, green: 0.75, blue: 0.2)
        default: return Color(red: 0.95, green: 0.35, blue: 0.35)
        }
    }
}
