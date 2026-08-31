import SwiftUI

// ─── AnimatedAVENTitle ────────────────────────────────────────────────────────
//
// Premium letter-by-letter reveal for the AVEN wordmark.
//
// Behavior:
//   - Letters appear left → right, fast and cinematic.
//   - Each letter fades in + settles from a slight downward offset.
//   - Stagger: 0.08 s between letters → total ≈ 0.55 s.
//   - Replays every time `trigger` changes (e.g. on Home tab return).
//   - Does NOT loop while staying on Home.
//   - Respects Reduce Motion: immediate full-opacity.

struct AnimatedAVENTitle: View {
    let trigger: UUID

    @State private var revealed: [Bool] = [false, false, false, false]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let letters: [(String, Color)] = [
        ("A", AVENColor.accentPurple),
        ("V", Color(hex: "#9060FF")),
        ("E", Color(hex: "#6090FF")),
        ("N", AVENColor.accentBlue),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(letters.enumerated()), id: \.offset) { index, pair in
                LetterView(
                    letter:   pair.0,
                    color:    pair.1,
                    revealed: revealed[index]
                )
            }
        }
        .onAppear { animateIn() }
        .onChange(of: trigger) { _, _ in replay() }
    }

    private func animateIn() {
        if reduceMotion {
            revealed = [true, true, true, true]
            return
        }
        for i in 0..<4 {
            // 0.08 s stagger → premium fast feel, total ~0.55 s
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.08) {
                withAnimation(
                    .spring(response: 0.38, dampingFraction: 0.82)
                ) {
                    revealed[i] = true
                }
            }
        }
    }

    private func replay() {
        revealed = [false, false, false, false]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            animateIn()
        }
    }
}

// ─── Single letter ────────────────────────────────────────────────────────────

private struct LetterView: View {
    let letter:   String
    let color:    Color
    let revealed: Bool

    @State private var glowOpacity: Double = 0

    var body: some View {
        Text(letter)
            .font(AVENFont.display(24))
            .foregroundStyle(
                LinearGradient(
                    colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            // Settle from slightly below — no bounce, no horizontal shift
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : 7)
            // Very subtle glow on landing, fades quickly
            .shadow(color: color.opacity(glowOpacity), radius: 6)
            .onChange(of: revealed) { _, isRevealed in
                guard isRevealed else { glowOpacity = 0; return }
                withAnimation(.easeOut(duration: 0.15))  { glowOpacity = 0.55 }
                withAnimation(.easeIn(duration: 0.45).delay(0.15)) { glowOpacity = 0 }
            }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        AnimatedAVENTitle(trigger: UUID())
            .padding()
    }
}
