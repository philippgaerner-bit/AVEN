import SwiftUI

// ─── AVEN Motion System ───────────────────────────────────────────────────────
// Premium, restrained motion for a high-end creator-tech app.
// All values tuned to feel "Apple-quality": fast, intentional, non-distracting.

enum AVENMotion {
    // ── Springs ───────────────────────────────────────────────────────────────
    /// Standard spring — snappy, no bounce
    static let spring       = Animation.spring(response: 0.42, dampingFraction: 0.82)
    /// Gentle spring — large elements (cards, sheets)
    static let springGentle = Animation.spring(response: 0.52, dampingFraction: 0.86)
    /// Fast spring — micro-interactions (buttons, selections, toggles)
    static let springFast   = Animation.spring(response: 0.26, dampingFraction: 0.80)
    /// Very slow reveal — dramatic moments (score result)
    static let springDramatic = Animation.spring(response: 0.85, dampingFraction: 0.70)

    // ── Easing ────────────────────────────────────────────────────────────────
    static let fadeIn  = Animation.easeOut(duration: 0.26)
    static let fadeOut = Animation.easeIn(duration: 0.18)
    static let smooth  = Animation.easeInOut(duration: 0.32)

    // ── Numeric transitions ───────────────────────────────────────────────────
    static let countUp  = Animation.easeOut(duration: 0.85)
    static let scoreArc = Animation.spring(response: 1.05, dampingFraction: 0.70)

    // ── Press feedback ────────────────────────────────────────────────────────
    static let pressScale: CGFloat = 0.96

    // ── Stagger ───────────────────────────────────────────────────────────────
    static func stagger(_ index: Int, base: Double = 0.06) -> Double {
        Double(index) * base
    }

    // ── Chart draw ────────────────────────────────────────────────────────────
    static let chartDraw = Animation.easeInOut(duration: 0.75)
    static let chartTransition = Animation.easeInOut(duration: 0.40)
}

// ─── Reduce Motion helper ─────────────────────────────────────────────────────

extension Animation {
    static func motion(_ animation: Animation) -> Animation {
        // In a real app: if UIAccessibility.isReduceMotionEnabled { return .linear(duration: 0.01) }
        return animation
    }
}

// ─── Card appear modifier ─────────────────────────────────────────────────────

struct CardAppear: ViewModifier {
    @State private var appeared = false
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .animation(AVENMotion.spring.delay(delay), value: appeared)
            .onAppear { appeared = true }
    }
}

extension View {
    func cardAppear(delay: Double = 0) -> some View {
        modifier(CardAppear(delay: delay))
    }
}

// ─── Staggered list appear ────────────────────────────────────────────────────

struct StaggerAppear: ViewModifier {
    let index: Int
    let baseDelay: Double
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .animation(AVENMotion.spring.delay(AVENMotion.stagger(index, base: baseDelay)), value: appeared)
            .onAppear { appeared = true }
    }
}

extension View {
    func staggerAppear(index: Int, baseDelay: Double = 0.07) -> some View {
        modifier(StaggerAppear(index: index, baseDelay: baseDelay))
    }
}

// ─── Premium press button style ───────────────────────────────────────────────
// Already defined in NewScanSheet.swift as PressButtonStyle — this is the same.
// Import via the shared module — no duplicate needed here.

// ─── Subtle ambient glow — used around score, CTAs ───────────────────────────

struct AmbientGlow: ViewModifier {
    let color: Color
    let radius: CGFloat
    /// Set true only for elements where the glow should breathe (score arc)
    let breathes: Bool
    @State private var phase = false

    func body(content: Content) -> some View {
        content
            .shadow(
                color: color.opacity(breathes ? (phase ? 0.45 : 0.20) : 0.30),
                radius: breathes ? (phase ? radius : radius * 0.55) : radius
            )
            .animation(
                breathes
                    ? .easeInOut(duration: 2.6).repeatForever(autoreverses: true)
                    : .none,
                value: phase
            )
            .onAppear { if breathes { phase = true } }
    }
}

extension View {
    /// Subtle, non-distracting glow. `breathes: true` only for score/focal elements.
    func avGlow(color: Color = AVENColor.accentPurple, radius: CGFloat = 10, breathes: Bool = false) -> some View {
        modifier(AmbientGlow(color: color, radius: radius, breathes: breathes))
    }
}

// ─── Animated number (integer) ────────────────────────────────────────────────

struct AnimatedNumber: View {
    let value: Int
    let format: (Int) -> String
    @State private var displayed: Int = 0

    init(_ value: Int, format: @escaping (Int) -> String = { "\($0)" }) {
        self.value = value
        self.format = format
    }

    var body: some View {
        Text(format(displayed))
            .contentTransition(.numericText(countsDown: false))
            .onAppear   { withAnimation(AVENMotion.countUp) { displayed = value } }
            .onChange(of: value) { _, new in withAnimation(AVENMotion.countUp) { displayed = new } }
    }
}

// ─── Animated K/M counter ────────────────────────────────────────────────────

struct AnimatedCounterView: View {
    let target: Int
    let font: Font
    let color: Color
    @State private var current: Double = 0

    var body: some View {
        Text(formatK(Int(current)))
            .font(font)
            .foregroundColor(color)
            .contentTransition(.numericText())
            .onAppear   { withAnimation(AVENMotion.countUp) { current = Double(target) } }
            .onChange(of: target) { _, new in withAnimation(AVENMotion.countUp) { current = Double(new) } }
    }

    private func formatK(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000     { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}

// ─── Animated score arc ───────────────────────────────────────────────────────

struct AnimatedScoreArcView: View {
    let targetScore: Int
    var size: CGFloat = 140
    @State private var animatedScore: Int = 0
    @State private var labelVisible = false

    private var progress: Double { Double(animatedScore) / 100.0 }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .trim(from: 0.15, to: 0.85)
                .stroke(AVENColor.borderSubtle, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(90))
            // Progress arc
            Circle()
                .trim(from: 0.15, to: max(0.15, 0.15 + 0.70 * progress))
                .stroke(
                    LinearGradient(colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                                   startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(90))
                .animation(AVENMotion.scoreArc, value: animatedScore)
                // Breathing glow on the arc endpoint
                .avGlow(color: AVENColor.accentBlue, radius: 8, breathes: true)
            // Score label — fades in slightly after arc starts
            VStack(spacing: 0) {
                AnimatedNumber(animatedScore)
                    .font(AVENFont.display(36))
                    .foregroundColor(AVENColor.textPrimary)
                Text("/ 100")
                    .font(AVENFont.body(12))
                    .foregroundColor(AVENColor.textSecondary)
            }
            .opacity(labelVisible ? 1 : 0)
            .animation(AVENMotion.fadeIn.delay(0.3), value: labelVisible)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(AVENMotion.scoreArc) { animatedScore = targetScore }
            withAnimation(AVENMotion.fadeIn.delay(0.25)) { labelVisible = true }
        }
        .onChange(of: targetScore) { _, new in
            withAnimation(AVENMotion.scoreArc) { animatedScore = new }
        }
    }
}

// ─── Pulsing glow (legacy compat) ────────────────────────────────────────────

struct PulsingGlow: ViewModifier {
    let color: Color
    let radius: CGFloat
    @State private var pulsing = false

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(pulsing ? 0.45 : 0.18), radius: pulsing ? radius : radius * 0.5)
            .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: pulsing)
            .onAppear { pulsing = true }
    }
}

extension View {
    func pulsingGlow(color: Color = AVENColor.accentPurple, radius: CGFloat = 12) -> some View {
        modifier(PulsingGlow(color: color, radius: radius))
    }
}

// ─── Chart line draw modifier ─────────────────────────────────────────────────

struct ChartDrawModifier: ViewModifier {
    @State private var revealed = false
    func body(content: Content) -> some View {
        content
            .opacity(revealed ? 1 : 0)
            .animation(AVENMotion.chartDraw, value: revealed)
            .onAppear { withAnimation(AVENMotion.chartDraw) { revealed = true } }
    }
}

extension View {
    func chartReveal() -> some View { modifier(ChartDrawModifier()) }
}

// ─── Slide-in from bottom ────────────────────────────────────────────────────

struct SlideInBottom: ViewModifier {
    let delay: Double
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(AVENMotion.springGentle.delay(delay), value: appeared)
            .onAppear { appeared = true }
    }
}

extension View {
    func slideInBottom(delay: Double = 0) -> some View { modifier(SlideInBottom(delay: delay)) }
}

// ─── Shimmer / scan effect ────────────────────────────────────────────────────

struct AVENShimmer: View {
    @State private var phase: CGFloat = -1.0

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: .clear,                            location: 0),
                        .init(color: AVENColor.accentPurple.opacity(0.12), location: 0.45),
                        .init(color: AVENColor.accentBlue.opacity(0.18),   location: 0.5),
                        .init(color: AVENColor.accentPurple.opacity(0.12), location: 0.55),
                        .init(color: .clear,                            location: 1),
                    ],
                    startPoint: .init(x: phase, y: 0.5),
                    endPoint:   .init(x: phase + 1, y: 0.5)
                )
            )
            .onAppear {
                withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                    phase = 1.0
                }
            }
    }
}

// ─── Haptics ─────────────────────────────────────────────────────────────────

enum AVENHaptic {
    static func light()   { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium()  { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
}

// ─── Scale button style (premium press) ──────────────────────────────────────

struct AVENScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = AVENMotion.pressScale
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(AVENMotion.springFast, value: configuration.isPressed)
    }
}

// ─── Plan card scale (for Paywall) ───────────────────────────────────────────

struct PlanCardStyle: ViewModifier {
    let isSelected: Bool
    func body(content: Content) -> some View {
        content
            .scaleEffect(isSelected ? 1.015 : 1.0)
            .animation(AVENMotion.spring, value: isSelected)
    }
}

extension View {
    func planCardStyle(selected: Bool) -> some View {
        modifier(PlanCardStyle(isSelected: selected))
    }
}
