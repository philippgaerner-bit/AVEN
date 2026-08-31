import SwiftUI

// ─── AVENCard ─────────────────────────────────────────────────────────────────

struct AVENCard<Content: View>: View {
    var elevated: Bool = false
    var accentBorder: Bool = false
    let content: Content

    init(elevated: Bool = false, accentBorder: Bool = false, @ViewBuilder content: () -> Content) {
        self.elevated = elevated
        self.accentBorder = accentBorder
        self.content = content()
    }

    var body: some View {
        content
            .padding(AVENSpacing.md)
            .background(elevated ? AVENColor.backgroundElevated : AVENColor.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: AVENRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AVENRadius.lg)
                    .strokeBorder(
                        accentBorder ? AVENColor.borderAccent : AVENColor.borderSubtle,
                        lineWidth: 0.5
                    )
            )
            .shadow(color: AVENColor.cardShadow, radius: 4, x: 0, y: 1)
    }
}

// ─── AVENBadge ────────────────────────────────────────────────────────────────

struct AVENBadge: View {
    let text: String
    var positive: Bool = true

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: positive ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(AVENFont.body(11, weight: .semibold))
        }
        .foregroundColor(positive ? AVENColor.textPositive : AVENColor.textNegative)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background((positive ? AVENColor.textPositive : AVENColor.textNegative).opacity(0.12))
        .clipShape(Capsule())
    }
}

// ─── AVENButton ───────────────────────────────────────────────────────────────

struct AVENPrimaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AVENSpacing.sm) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(AVENFont.body(16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [AVENColor.accentGradientStart, AVENColor.accentGradientEnd],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: AVENRadius.md))
        }
        .foregroundColor(.white)
        .buttonStyle(PressButtonStyle())
    }
}

// ─── AVENPill (period selector) ───────────────────────────────────────────────

struct AVENPill: View {
    let title: String
    var selected: Bool = false

    var body: some View {
        Text(title)
            .font(AVENFont.body(13, weight: selected ? .semibold : .regular))
            .foregroundColor(selected ? .white : AVENColor.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(selected ? AVENColor.accentPurple : Color.clear)
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(
                    selected ? Color.clear : AVENColor.borderSubtle, lineWidth: 1
                )
            )
    }
}

// ─── Score arc view ───────────────────────────────────────────────────────────

struct ScoreArcView: View {
    let score: Int  // 0–100
    var size: CGFloat = 140

    private var progress: Double { Double(score) / 100.0 }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .trim(from: 0.15, to: 0.85)
                .stroke(AVENColor.borderSubtle, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(90))
            // Progress
            Circle()
                .trim(from: 0.15, to: 0.15 + 0.70 * progress)
                .stroke(
                    LinearGradient(
                        colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(90))
                .animation(.spring(response: 0.8), value: score)
            // Score label
            VStack(spacing: 0) {
                Text("\(score)")
                    .font(AVENFont.display(36))
                    .foregroundColor(AVENColor.textPrimary)
                Text("/ 100")
                    .font(AVENFont.body(12))
                    .foregroundColor(AVENColor.textSecondary)
            }
        }
        .frame(width: size, height: size)
    }
}

// CardAppear, StaggerAppear, AmbientGlow, AVENShimmer — defined in AVENMotion.swift

// ─── Press button style (shared globally) ────────────────────────────────────

struct PressButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .opacity(configuration.isPressed ? 0.82 : 1.0)
            .animation(AVENMotion.springFast, value: configuration.isPressed)
    }
}

// ─── TikTok Avatar ────────────────────────────────────────────────────────────
// Loads avatar_url asynchronously; falls back to initial letter while loading
// or when no URL is provided.

struct TikTokAvatarView: View {
    let displayName: String
    let avatarUrl:   String?
    let size:        CGFloat
    let ringColor:   Color

    init(displayName: String, avatarUrl: String?,
         size: CGFloat = 84, ringColor: Color = AVENColor.accentPurple) {
        self.displayName = displayName
        self.avatarUrl   = avatarUrl
        self.size        = size
        self.ringColor   = ringColor
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [ringColor, ringColor.opacity(0.4)],
                        startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 2.5)
                .frame(width: size + 8, height: size + 8)

            if let urlStr = avatarUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                    case .failure, .empty:
                        avatarPlaceholder
                    @unknown default:
                        avatarPlaceholder
                    }
                }
            } else {
                avatarPlaceholder
            }
        }
    }

    private var avatarPlaceholder: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [ringColor, ringColor.opacity(0.6)],
                    startPoint: .top, endPoint: .bottom))
                .frame(width: size, height: size)
            Text(String(displayName.prefix(1)).uppercased())
                .font(.system(size: size * 0.4, weight: .black, design: .rounded))
                .foregroundColor(.white)
        }
    }
}

// ─── TikTok Icon ──────────────────────────────────────────────────────────────
// Custom TikTok-styled icon (no official SF Symbol available).
// Uses a musical note + "T" shape characteristic of TikTok's brand.

struct TikTokIconView: View {
    var size: CGFloat = 22
    var color: Color = .white

    var body: some View {
        ZStack {
            // Simplified TikTok logo using music.note as proxy
            Image(systemName: "music.note")
                .font(.system(size: size * 0.85, weight: .bold))
                .foregroundColor(color)
        }
    }
}
