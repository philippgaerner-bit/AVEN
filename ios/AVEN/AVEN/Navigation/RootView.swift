import SwiftUI

// ─── RootView ─────────────────────────────────────────────────────────────────
//
// Layout fix: Instead of ZStack + ignoresSafeArea(bottom) which caused content
// to slide under the tab bar, we use safeAreaInset(edge: .bottom) so SwiftUI
// automatically reserves space for the tab bar. Each tab view's ScrollView
// then knows its bottom inset and content doesn't disappear behind the bar.

struct RootView: View {
    @EnvironmentObject private var container: AppContainer
    @AppStorage("aven.hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        if !hasCompletedOnboarding {
            AVENOnboardingView {
                hasCompletedOnboarding = true
            }
        } else {
            mainApp
        }
    }

    private var mainApp: some View {
        Group {
            switch container.selectedTab {
            case .home:       HomeView(container: container).transition(.opacity)
            case .analytics:  AnalyticsView().transition(.opacity)
            case .create:     HomeView(container: container).transition(.opacity)
            case .actionPlan: ActionPlanView().transition(.opacity)
            case .profile:    ProfileView().transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: container.selectedTab)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // safeAreaInset reserves tab-bar height so scroll content is never hidden
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AVENTabBar(
                selectedTab: $container.selectedTab,
                onCreate: { container.showCreationMenu = true }
            )
        }
        .background(AVENColor.backgroundPrimary.ignoresSafeArea())
        .fullScreenCover(isPresented: $container.showCreationMenu) {
            CreationMenuSheet(
                showNewScan: $container.showNewScan,
                showAIVideo: $container.showAIVideo
            )
            .environmentObject(container)
        }
        .sheet(isPresented: $container.showNewScan) {
            NewScanSheet()
        }
        .sheet(isPresented: $container.showAIVideo) {
            AIVideoCreatorView()
        }
        .sheet(isPresented: $container.showTikTokAccount) {
            TikTokAccountView(onNewAnalysis: {
                container.showTikTokAccount = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    container.showNewScan = true
                }
            })
        }
    }  // end mainApp
}

// ─── Tab bar ──────────────────────────────────────────────────────────────────

private struct AVENTabBar: View {
    @Binding var selectedTab: AppTab
    let onCreate: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            TabBarItem(tab: .home,       icon: "house.fill",            label: "Home",        selected: $selectedTab)
            TabBarItem(tab: .analytics,  icon: "chart.bar.fill",        label: "Analytics",   selected: $selectedTab)
            CreateButton(action: onCreate)
            TabBarItem(tab: .actionPlan, icon: "checkmark.circle.fill", label: "Aktionsplan", selected: $selectedTab)
            TabBarItem(tab: .profile,    icon: "person.fill",           label: "Profil",      selected: $selectedTab)
        }
        .padding(.top, 8)
        .padding(.bottom, 28)
        .background(
            AVENColor.backgroundCard
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(Color(hex: "#0D0E1A").opacity(0.08)),
                    alignment: .top
                )
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

private struct TabBarItem: View {
    let tab: AppTab; let icon: String; let label: String
    @Binding var selected: AppTab
    private var isSelected: Bool { selected == tab }

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { selected = tab }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? AVENColor.accentPurple : AVENColor.textMuted)
                    .scaleEffect(isSelected ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3), value: isSelected)
                Text(label)
                    .font(AVENFont.body(10))
                    .foregroundColor(isSelected ? AVENColor.accentPurple : AVENColor.textMuted)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

private struct CreateButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [AVENColor.accentGradientStart, AVENColor.accentGradientEnd],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 44, height: 44)
                    .shadow(color: AVENColor.accentPurple.opacity(0.15), radius: 5, y: 2)
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(PressButtonStyle())
        .frame(maxWidth: .infinity)
        .offset(y: -10)
    }
}

#Preview {
    RootView().environmentObject(AppContainer.preview)
}
