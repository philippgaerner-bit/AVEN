import SwiftUI
import UIKit

// ─── AVEN Design Tokens ───────────────────────────────────────────────────────
// Premium adaptive palette. Light uses soft marble whites; Dark uses near-black
// surfaces so the purple/blue AVEN accents stay crisp without looking neon-heavy.

enum AVENAppearance: String, CaseIterable, Identifiable {
    case light
    case dark
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light:  return "Hell"
        case .dark:   return "Dunkel"
        case .system: return "System"
        }
    }

    var icon: String {
        switch self {
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        case .system: return "iphone"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light:  return .light
        case .dark:   return .dark
        case .system: return nil
        }
    }
}

enum AVENColor {
    private static func adaptive(light: String, dark: String) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    // ── Backgrounds ───────────────────────────────────────────────────────────
    static let backgroundPrimary   = adaptive(light: "#F7F7FA", dark: "#050507")
    static let backgroundSecondary = adaptive(light: "#EDEEF4", dark: "#0B0B10")
    static let backgroundCard      = adaptive(light: "#FFFFFF", dark: "#111116")
    static let backgroundElevated  = adaptive(light: "#F8F9FC", dark: "#17171E")

    // ── Accents ───────────────────────────────────────────────────────────────
    static let accentPurple        = Color(hex: "#7B4FFF")
    static let accentBlue          = Color(hex: "#4F8FFF")
    static let accentPurpleLight   = Color(hex: "#A47FFF")
    static let accentGradientStart = Color(hex: "#7B4FFF")
    static let accentGradientEnd   = Color(hex: "#4F8FFF")

    // ── Text ──────────────────────────────────────────────────────────────────
    static let textPrimary         = adaptive(light: "#0D0E1A", dark: "#F7F7FB")
    static let textSecondary       = adaptive(light: "#5C5E72", dark: "#B5B6C4")
    static let textMuted           = adaptive(light: "#9395A8", dark: "#77798A")
    static let textPositive        = Color(hex: "#16A34A")
    static let textNegative        = Color(hex: "#DC2626")

    // ── Borders / shadows ─────────────────────────────────────────────────────
    static let borderSubtle        = adaptive(light: "#E4E4EB", dark: "#25252E")
    static let borderAccent        = Color(hex: "#7B4FFF").opacity(0.25)
    static let cardShadow          = adaptive(light: "#0D0E1A", dark: "#000000").opacity(0.08)
}

enum AVENSpacing {
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 24
    static let xl:  CGFloat = 32
    static let xxl: CGFloat = 48
}

enum AVENRadius {
    static let sm:   CGFloat = 8
    static let md:   CGFloat = 12
    static let lg:   CGFloat = 16
    static let xl:   CGFloat = 22
    static let full: CGFloat = 999
}

enum AVENFont {
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    static func mono(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }
}

// ─── Hex color helpers ────────────────────────────────────────────────────────

extension UIColor {
    convenience init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        let hasAlpha = h.count == 8
        let a = hasAlpha ? CGFloat((rgb & 0xFF000000) >> 24) / 255 : 1.0
        let r = CGFloat((rgb & (hasAlpha ? 0x00FF0000 : 0xFF0000)) >> 16) / 255
        let g = CGFloat((rgb & (hasAlpha ? 0x0000FF00 : 0x00FF00)) >> 8) / 255
        let b = CGFloat(rgb & (hasAlpha ? 0x000000FF : 0x0000FF)) / 255
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}

extension Color {
    init(hex: String) {
        self.init(uiColor: UIColor(hex: hex))
    }
}
