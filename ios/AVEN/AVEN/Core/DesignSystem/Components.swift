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

// ─── Premium AVEN flask ──────────────────────────────────────────────────────
// Pure SwiftUI vector artwork. It deliberately contains no raster background,
// so it stays clean on both light and dark cards.

struct AVENFlaskShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: 0.40 * w, y: 0.08 * h))
        p.addLine(to: CGPoint(x: 0.60 * w, y: 0.08 * h))
        p.addLine(to: CGPoint(x: 0.60 * w, y: 0.34 * h))
        p.addCurve(
            to: CGPoint(x: 0.82 * w, y: 0.84 * h),
            control1: CGPoint(x: 0.60 * w, y: 0.48 * h),
            control2: CGPoint(x: 0.75 * w, y: 0.69 * h)
        )
        p.addCurve(
            to: CGPoint(x: 0.72 * w, y: 0.93 * h),
            control1: CGPoint(x: 0.86 * w, y: 0.90 * h),
            control2: CGPoint(x: 0.81 * w, y: 0.93 * h)
        )
        p.addLine(to: CGPoint(x: 0.28 * w, y: 0.93 * h))
        p.addCurve(
            to: CGPoint(x: 0.18 * w, y: 0.84 * h),
            control1: CGPoint(x: 0.19 * w, y: 0.93 * h),
            control2: CGPoint(x: 0.14 * w, y: 0.90 * h)
        )
        p.addCurve(
            to: CGPoint(x: 0.40 * w, y: 0.34 * h),
            control1: CGPoint(x: 0.25 * w, y: 0.69 * h),
            control2: CGPoint(x: 0.40 * w, y: 0.48 * h)
        )
        p.closeSubpath()
        return p
    }
}

struct AVENFlaskView: View {
    var animated: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var float = false
    @State private var shimmer = false

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                AVENFlaskShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.055 : 0.18),
                                AVENColor.accentPurple.opacity(0.045),
                                AVENColor.accentBlue.opacity(0.035)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                AVENFlaskShape()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.72 : 0.92),
                                AVENColor.accentPurple.opacity(0.90),
                                AVENColor.accentBlue.opacity(0.78)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: max(1.4, size.width * 0.018), lineCap: .round, lineJoin: .round)
                    )

                // Liquid is clipped to the glass shape, so there can never be a
                // rectangular or white bitmap edge around the flask.
                LinearGradient(
                    colors: [
                        AVENColor.accentPurple.opacity(colorScheme == .dark ? 0.84 : 0.72),
                        Color(hex: "#6F45FF").opacity(0.82),
                        AVENColor.accentBlue.opacity(0.72)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: size.height * 0.35)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .offset(y: size.height * 0.025)
                .clipShape(AVENFlaskShape())

                // Liquid surface
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.70), AVENColor.accentPurple.opacity(0.95), AVENColor.accentBlue.opacity(0.55)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: size.width * 0.47, height: max(2, size.height * 0.018))
                    .offset(y: size.height * 0.22)
                    .opacity(0.88)

                // Glass highlight
                RoundedRectangle(cornerRadius: size.width * 0.035, style: .continuous)
                    .fill(Color.white.opacity(colorScheme == .dark ? 0.30 : 0.55))
                    .frame(width: size.width * 0.055, height: size.height * 0.39)
                    .rotationEffect(.degrees(8))
                    .offset(x: -size.width * 0.11, y: -size.height * 0.12)
                    .blur(radius: 0.25)

                bubble(size: size.width * 0.065, x: 0.12, y: 0.29, delay: 0)
                bubble(size: size.width * 0.045, x: -0.10, y: 0.37, delay: 0.18)
                bubble(size: size.width * 0.030, x: 0.05, y: 0.17, delay: 0.34)

                // Tiny moving glint; subtle enough for premium UI.
                Circle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: max(3, size.width * 0.035), height: max(3, size.width * 0.035))
                    .blur(radius: 0.6)
                    .offset(x: size.width * 0.16, y: -size.height * 0.18)
                    .opacity(shimmer ? 0.95 : 0.28)
            }
            .shadow(color: AVENColor.accentPurple.opacity(colorScheme == .dark ? 0.22 : 0.14), radius: size.width * 0.08, y: size.height * 0.035)
            .offset(y: animated && float && !reduceMotion ? -3 : 2)
            .scaleEffect(animated && float && !reduceMotion ? 1.018 : 1)
            .onAppear {
                guard animated, !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 2.1).repeatForever(autoreverses: true)) { float = true }
                withAnimation(.easeInOut(duration: 1.35).repeatForever(autoreverses: true)) { shimmer = true }
            }
        }
        .aspectRatio(0.92, contentMode: .fit)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func bubble(size: CGFloat, x: CGFloat, y: CGFloat, delay: Double) -> some View {
        Circle()
            .fill(Color.white.opacity(0.38))
            .overlay(Circle().stroke(Color.white.opacity(0.36), lineWidth: 0.6))
            .frame(width: size, height: size)
            .offset(x: x * 120, y: y * 120)
            .scaleEffect(animated && float && !reduceMotion ? 1.08 : 0.94)
            .animation(
                reduceMotion || !animated ? .none : .easeInOut(duration: 1.4).repeatForever(autoreverses: true).delay(delay),
                value: float
            )
    }
}
