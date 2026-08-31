import SwiftUI

// ─── AVEN Design Tokens ───────────────────────────────────────────────────────
// Light premium aesthetic: off-white / marble-white + purple/blue accents

enum AVENColor {
    // ── Backgrounds ───────────────────────────────────────────────────────────
    static let backgroundPrimary   = Color(hex: "#F7F7FA")  // premium soft marble-white
    static let backgroundSecondary = Color(hex: "#EDEEF4")  // slightly deeper
    static let backgroundCard      = Color(hex: "#FFFFFF")  // pure white card
    static let backgroundElevated  = Color(hex: "#F8F9FC")  // slightly off-white elevated

    // ── Accents ───────────────────────────────────────────────────────────────
    static let accentPurple        = Color(hex: "#7B4FFF")
    static let accentBlue          = Color(hex: "#4F8FFF")
    static let accentPurpleLight   = Color(hex: "#A47FFF")
    static let accentGradientStart = Color(hex: "#7B4FFF")
    static let accentGradientEnd   = Color(hex: "#4F8FFF")

    // ── Text ──────────────────────────────────────────────────────────────────
    static let textPrimary         = Color(hex: "#0D0E1A")  // deep navy-black
    static let textSecondary       = Color(hex: "#5C5E72")  // muted slate
    static let textMuted           = Color(hex: "#9395A8")  // light slate
    static let textPositive        = Color(hex: "#16A34A")  // green
    static let textNegative        = Color(hex: "#DC2626")  // red

    // ── Borders ───────────────────────────────────────────────────────────────
    static let borderSubtle        = Color(hex: "#0D0E1A").opacity(0.07)
    static let borderAccent        = Color(hex: "#7B4FFF").opacity(0.25)

    // ── Shadow ────────────────────────────────────────────────────────────────
    static let cardShadow          = Color(hex: "#0D0E1A").opacity(0.06)
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

// ─── Hex color extension ──────────────────────────────────────────────────────

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        let hasAlpha = h.count == 8
        let a = hasAlpha ? Double((rgb & 0xFF000000) >> 24) / 255 : 1.0
        let r = Double((rgb & (hasAlpha ? 0x00FF0000 : 0xFF0000)) >> (hasAlpha ? 16 : 16)) / 255
        let g = Double((rgb & (hasAlpha ? 0x0000FF00 : 0x00FF00)) >> 8) / 255
        let b = Double( rgb & (hasAlpha ? 0x000000FF : 0x0000FF)) / 255
        self.init(red: r, green: g, blue: b, opacity: a)
    }
}
