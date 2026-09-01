import SwiftUI

// ─── AVEN App ─────────────────────────────────────────────────────────────────

@main
struct AVENApp: App {
    @StateObject private var container = AppContainer()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("aven.appearance") private var appearanceRaw = AVENAppearance.light.rawValue

    private var appearance: AVENAppearance {
        AVENAppearance(rawValue: appearanceRaw) ?? .light
    }

    var body: some Scene {
        WindowGroup {
            AVENSplashWrapper {
                RootView()
                    .environmentObject(container)
            }
            .preferredColorScheme(appearance.colorScheme)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
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
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) {
                            withAnimation(.easeOut(duration: 0.35)) { splashOpacity = 0 }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
                                showSplash = false
                            }
                        }
                    }
            }
        }
    }
}

private struct AVENSplashView: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 12) {
                Image("AVENMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 112, height: 105)
                    .shadow(color: AVENColor.accentPurple.opacity(0.42), radius: 24)
                    .scaleEffect(appeared ? 1 : 0.76)
                    .opacity(appeared ? 1 : 0)

                Text("AVEN")
                    .font(.system(size: 27, weight: .medium))
                    .tracking(9)
                    .foregroundColor(.white)
                    .offset(x: 4)
                    .opacity(appeared ? 1 : 0)
            }
            .animation(.spring(response: 0.62, dampingFraction: 0.78), value: appeared)
        }
        .onAppear { appeared = true }
    }
}
