import SwiftUI

// ─── AVEN App ─────────────────────────────────────────────────────────────────

@main
struct AVENApp: App {
    @StateObject private var container = AppContainer()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            AVENSplashWrapper {
                RootView()
                    .environmentObject(container)
            }
            .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                // Sync TikTok stats whenever app comes to foreground
                container.syncTikTokStats()
            }
        }
    }
}

// ─── Splash wrapper ───────────────────────────────────────────────────────────

private struct AVENSplashWrapper<Content: View>: View {
    let content: () -> Content
    @State private var showSplash = true
    @State private var splashOpacity: Double = 1

    var body: some View {
        ZStack {
            content()
            if showSplash {
                AVENSplashView()
                    .opacity(splashOpacity)
                    .ignoresSafeArea()
                    .onAppear {
                        // Letters reveal over ~0.6s, then HOLD for 1 full second, then fade
                        // Total: ~0.6 reveal + 1.0 hold + 0.4 fade = ~2.0s
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                            withAnimation(.easeOut(duration: 0.4)) { splashOpacity = 0 }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.41) {
                                showSplash = false
                            }
                        }
                    }
            }
        }
    }
}

private struct AVENSplashView: View {
    private let letters: [Character] = ["A", "V", "E", "N"]
    @State private var revealed: [Bool] = [false, false, false, false]
    @State private var glowPulse = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            HStack(spacing: 2) {
                ForEach(0..<letters.count, id: \.self) { i in
                    Text(String(letters[i]))
                        .font(.system(size: 68, weight: .light, design: .default))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#9B5CFF"), Color(hex: "#4F8FFF")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color(hex: "#9B5CFF").opacity(glowPulse ? 0.8 : 0.3), radius: 14)
                        .scaleEffect(revealed[i] ? 1 : 0.7)
                        .opacity(revealed[i] ? 1 : 0)
                        .animation(
                            .spring(response: 0.35, dampingFraction: 0.75)
                                .delay(Double(i) * 0.12),
                            value: revealed[i]
                        )
                }
            }
        }
        .onAppear {
            for i in 0..<letters.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.12 + 0.05) {
                    revealed[i] = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeInOut(duration: 0.3)) { glowPulse = true }
            }
        }
    }
}
