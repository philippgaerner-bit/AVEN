import SwiftUI

// ─── HomeView ─────────────────────────────────────────────────────────────────
// Two deliberate states:
// 1) Fresh setup: no connected TikTok OR no first AVEN Score yet.
// 2) Ready dashboard: connected TikTok AND a completed first analysis.

struct HomeView: View {
    @StateObject private var vm: HomeViewModel
    @EnvironmentObject private var container: AppContainer
    @State private var titleTrigger = UUID()
    @State private var hasCompletedAnalysis = AVENAnalysisStore.hasCompletedAnalysis

    init(container: AppContainer) {
        _vm = StateObject(wrappedValue: container.makeHomeViewModel())
    }

    /// The full dashboard only appears once both real setup milestones exist.
    /// No manual switch and no placeholder score can unlock it.
    private var isSetupComplete: Bool {
        container.isTikTokConnected && hasCompletedAnalysis
    }

    var body: some View {
        ZStack {
            AVENColor.backgroundPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    HomeHeaderBar(
                        titleTrigger: titleTrigger,
                        tikTokAccount: container.connectedTikTokAccount
                    )

                    if isSetupComplete {
                        readyHome
                    } else {
                        freshHome
                    }

                    Color.clear.frame(height: 8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }

            if isSetupComplete && vm.state.isLoading && vm.state.score == nil {
                HomeLoadingOverlay()
            }
        }
        .task {
            hasCompletedAnalysis = AVENAnalysisStore.hasCompletedAnalysis
            if isSetupComplete {
                await vm.load()
            }
        }
        .animation(AVENMotion.smooth, value: vm.state.isLoading)
        .animation(.easeInOut(duration: 0.25), value: isSetupComplete)
        .onChange(of: container.selectedTab) { _, newTab in
            if newTab == .home {
                titleTrigger = UUID()
                hasCompletedAnalysis = AVENAnalysisStore.hasCompletedAnalysis
                if isSetupComplete {
                    Task { await vm.load() }
                }
            }
        }
        .onChange(of: isSetupComplete) { _, ready in
            if ready {
                Task { await vm.load() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .analysisDidComplete)) { _ in
            hasCompletedAnalysis = AVENAnalysisStore.hasCompletedAnalysis
            if container.isTikTokConnected && AVENAnalysisStore.hasCompletedAnalysis {
                Task { await vm.load() }
            }
        }
    }

    @ViewBuilder
    private var freshHome: some View {
        HomeTikTokCard(
            tikTokAccount: container.connectedTikTokAccount,
            onTap: { container.showTikTokAccount = true }
        )
        .cardAppear(delay: 0.03)

        FreshStartHeroCard(
            hasCompletedAnalysis: hasCompletedAnalysis,
            isTikTokConnected: container.isTikTokConnected,
            onAnalyse: { container.showNewScan = true },
            onConnect: { container.showTikTokAccount = true }
        )
        .cardAppear(delay: 0.06)

        FreshScoreCard(
            score: hasCompletedAnalysis ? AVENAnalysisStore.currentScore : nil
        )
        .cardAppear(delay: 0.09)

        FreshTodayCard(
            hasCompletedAnalysis: hasCompletedAnalysis,
            isTikTokConnected: container.isTikTokConnected,
            onAnalyse: { container.showNewScan = true },
            onConnect: { container.showTikTokAccount = true },
            onGoal: { container.showCreationMenu = true }
        )
        .cardAppear(delay: 0.12)

        FreshActionPlanCard(
            hasCompletedAnalysis: hasCompletedAnalysis,
            onOpen: { container.selectedTab = .actionPlan }
        )
        .cardAppear(delay: 0.15)
    }

    @ViewBuilder
    private var readyHome: some View {
        HomeTikTokCard(
            tikTokAccount: container.connectedTikTokAccount,
            onTap: { container.selectedTab = .profile }
        )
        .cardAppear(delay: 0.03)

        HomeGrowthBriefCard(score: vm.state.score, actions: vm.state.actions)
            .cardAppear(delay: 0.06)

        HomePerformanceSection(
            metrics: vm.state.metrics,
            period: vm.state.period,
            onSelectPeriod: { vm.selectPeriod($0) }
        )
        .cardAppear(delay: 0.09)

        HomeScoreCard(score: vm.state.score)
            .cardAppear(delay: 0.12)

        HomeTodayCard(score: vm.state.score, actions: vm.state.actions)
            .cardAppear(delay: 0.15)

        HomeActionPlanCard(actions: vm.state.actions, container: container)
            .cardAppear(delay: 0.18)
    }
}

// ─── Shared card style ────────────────────────────────────────────────────────

private extension View {
    func homeCard() -> some View {
        self
            .background(AVENColor.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(AVENColor.borderSubtle, lineWidth: 0.5)
            )
            .shadow(color: AVENColor.cardShadow, radius: 4, x: 0, y: 1)
    }
}

// ─── Header ───────────────────────────────────────────────────────────────────

private struct HomeHeaderBar: View {
    let titleTrigger: UUID
    let tikTokAccount: ConnectedTikTokAccount?
    @State private var showNotifications = false
    @State private var showProfile = false

    var body: some View {
        HStack(spacing: 0) {
            Button { showProfile = true } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AVENColor.textMuted)
                    .frame(width: 34, height: 34)
            }

            Spacer()
            AnimatedAVENTitle(trigger: titleTrigger)
            Spacer()

            Button { showNotifications = true } label: {
                Image(systemName: "bell")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AVENColor.textMuted)
                    .frame(width: 34, height: 34)
            }
        }
        .padding(.top, 6)
        .sheet(isPresented: $showNotifications) { NotificationsSheet() }
        .sheet(isPresented: $showProfile) { QuickProfileSheet(tikTokAccount: tikTokAccount) }
    }
}

// ─── TikTok account card ──────────────────────────────────────────────────────

private struct HomeTikTokCard: View {
    let tikTokAccount: ConnectedTikTokAccount?
    let onTap: () -> Void

    private var username: String {
        guard let account = tikTokAccount else { return "@dein_profil" }
        if account.username.hasPrefix("@") { return account.username }
        return "@\(account.username)"
    }

    private var isConnected: Bool { tikTokAccount != nil }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [AVENColor.accentPurple.opacity(0.14), AVENColor.accentBlue.opacity(0.09)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 40, height: 40)

                    if let url = tikTokAccount?.avatarUrl.flatMap(URL.init) {
                        AsyncImage(url: url) { phase in
                            if case .success(let image) = phase {
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                            } else {
                                avatarIcon
                            }
                        }
                    } else {
                        avatarIcon
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(username)
                        .font(AVENFont.body(13, weight: .semibold))
                        .foregroundColor(AVENColor.textPrimary)

                    HStack(spacing: 4) {
                        Circle()
                            .fill(isConnected ? AVENColor.textPositive : AVENColor.textMuted)
                            .frame(width: 5, height: 5)
                        Text(isConnected ? "TikTok verbunden" : "TikTok nicht verbunden")
                            .font(AVENFont.body(11))
                            .foregroundColor(isConnected ? AVENColor.textPositive : AVENColor.textMuted)
                    }
                }

                Spacer()

                if isConnected {
                    Text("Profil ansehen")
                        .font(AVENFont.body(10, weight: .medium))
                        .foregroundColor(AVENColor.accentPurple)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .overlay(
                            Capsule().strokeBorder(AVENColor.accentPurple.opacity(0.25), lineWidth: 0.7)
                        )
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AVENColor.textMuted)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .homeCard()
        }
        .buttonStyle(PressButtonStyle())
    }

    private var avatarIcon: some View {
        Image(systemName: "person.fill")
            .font(.system(size: 17))
            .foregroundColor(AVENColor.accentPurple)
    }
}

// ─── Fresh setup state ────────────────────────────────────────────────────────

private struct FreshStartHeroCard: View {
    let hasCompletedAnalysis: Bool
    let isTikTokConnected: Bool
    let onAnalyse: () -> Void
    let onConnect: () -> Void

    private var title: String {
        if hasCompletedAnalysis && !isTikTokConnected {
            return "Verbinde jetzt\ndeinen TikTok-Account"
        }
        if isTikTokConnected && !hasCompletedAnalysis {
            return "Starte deine\nerste Analyse"
        }
        return "Starte mit AVEN"
    }

    private var message: String {
        if hasCompletedAnalysis && !isTikTokConnected {
            return "Deine erste Analyse ist fertig. Verbinde TikTok, damit AVEN dein vollständiges Dashboard freischalten kann."
        }
        if isTikTokConnected && !hasCompletedAnalysis {
            return "TikTok ist verbunden. Analysiere jetzt dein Profil, damit AVEN deinen Score und deine nächsten Schritte erstellen kann."
        }
        return "Analysiere dein Profil und verbinde TikTok. Danach wird dein persönliches Growth-Dashboard automatisch freigeschaltet."
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(AVENFont.display(24))
                    .foregroundColor(AVENColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(message)
                    .font(AVENFont.body(11))
                    .foregroundColor(AVENColor.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                if !hasCompletedAnalysis {
                    primaryButton(
                        title: "Profil analysieren",
                        icon: "sparkles",
                        action: onAnalyse
                    )
                } else if !isTikTokConnected {
                    primaryButton(
                        title: "TikTok verbinden",
                        icon: "link",
                        action: onConnect
                    )
                }

                if !isTikTokConnected && !hasCompletedAnalysis {
                    Button(action: onConnect) {
                        HStack(spacing: 6) {
                            Image(systemName: "link")
                            Text("TikTok verbinden")
                        }
                        .font(AVENFont.body(11, weight: .medium))
                        .foregroundColor(AVENColor.accentPurple)
                    }
                    .buttonStyle(PressButtonStyle())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            FreshHeroIllustration()
                .frame(width: 112, height: 125)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [AVENColor.backgroundCard, AVENColor.accentPurple.opacity(0.055)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(AVENColor.accentPurple.opacity(0.08), lineWidth: 0.6)
        )
    }

    private func primaryButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
            }
            .font(AVENFont.body(11, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(
                LinearGradient(
                    colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(PressButtonStyle())
    }
}

private struct FreshHeroIllustration: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(AVENColor.accentPurple.opacity(0.045))
                .frame(width: 100, height: 100)

            HStack(alignment: .bottom, spacing: 5) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(AVENColor.accentPurple.opacity(0.22))
                    .frame(width: 17, height: 35)
                RoundedRectangle(cornerRadius: 4)
                    .fill(AVENColor.accentPurple.opacity(0.42))
                    .frame(width: 17, height: 54)
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(
                        colors: [AVENColor.accentPurple.opacity(0.65), AVENColor.accentBlue.opacity(0.55)],
                        startPoint: .bottom,
                        endPoint: .top
                    ))
                    .frame(width: 17, height: 73)
            }
            .offset(y: 22)

            ZStack {
                Circle()
                    .stroke(LinearGradient(
                        colors: [AVENColor.accentPurple.opacity(0.45), AVENColor.accentBlue.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ), lineWidth: 7)
                    .frame(width: 54, height: 54)
                RoundedRectangle(cornerRadius: 5)
                    .fill(LinearGradient(
                        colors: [AVENColor.accentPurple.opacity(0.70), AVENColor.accentBlue.opacity(0.65)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(width: 11, height: 39)
                    .rotationEffect(.degrees(-43))
                    .offset(x: 27, y: 28)
            }
            .offset(x: -9, y: -22)

            Image(systemName: "sparkles")
                .font(.system(size: 13))
                .foregroundColor(AVENColor.accentPurple.opacity(0.45))
                .offset(x: 43, y: -42)
        }
    }
}

private struct FreshScoreCard: View {
    let score: Int?

    var body: some View {
        HStack(spacing: 14) {
            if let score {
                HomeScoreRing(total: score)
            } else {
                ZStack {
                    Circle()
                        .trim(from: 0.15, to: 0.85)
                        .stroke(
                            AVENColor.accentPurple.opacity(0.13),
                            style: StrokeStyle(lineWidth: 7, lineCap: .round)
                        )
                        .rotationEffect(.degrees(90))

                    VStack(spacing: 0) {
                        Text("--")
                            .font(AVENFont.display(18))
                            .foregroundColor(AVENColor.textPrimary)
                        Text("/100")
                            .font(AVENFont.body(9))
                            .foregroundColor(AVENColor.textMuted)
                    }
                }
                .frame(width: 70, height: 70)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("AVEN Score")
                    .font(AVENFont.body(11))
                    .foregroundColor(AVENColor.textMuted)

                Text(score.map { HomeViewModel.scoreStatus(for: $0) } ?? "Noch kein AVEN Score")
                    .font(AVENFont.body(15, weight: .semibold))
                    .foregroundColor(AVENColor.textPrimary)

                Text(score == nil
                     ? "Starte deine erste Analyse, um deinen persönlichen Score zu sehen."
                     : "Deine Analyse ist abgeschlossen. Verbinde TikTok für dein vollständiges Dashboard.")
                    .font(AVENFont.body(11))
                    .foregroundColor(AVENColor.textSecondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .homeCard()
    }
}

private struct FreshTodayCard: View {
    let hasCompletedAnalysis: Bool
    let isTikTokConnected: Bool
    let onAnalyse: () -> Void
    let onConnect: () -> Void
    let onGoal: () -> Void

    private struct Row {
        let icon: String
        let color: Color
        let title: String
        let subtitle: String
        let action: () -> Void
    }

    private var rows: [Row] {
        [
            Row(
                icon: hasCompletedAnalysis ? "checkmark.circle.fill" : "chart.bar.fill",
                color: hasCompletedAnalysis ? AVENColor.textPositive : AVENColor.accentPurple,
                title: hasCompletedAnalysis ? "Erste Profilanalyse abgeschlossen" : "Erste Profilanalyse starten",
                subtitle: hasCompletedAnalysis ? "Dein AVEN Score wurde erstellt." : "Lass AVEN dein Profil prüfen und Potenziale finden.",
                action: onAnalyse
            ),
            Row(
                icon: isTikTokConnected ? "checkmark.circle.fill" : "link",
                color: isTikTokConnected ? AVENColor.textPositive : AVENColor.accentPurple,
                title: isTikTokConnected ? "TikTok ist verbunden" : "TikTok verbinden",
                subtitle: isTikTokConnected ? "Dein Account ist mit AVEN verknüpft." : "Verbinde deinen Account für dein vollständiges Dashboard.",
                action: onConnect
            ),
            Row(
                icon: "target",
                color: AVENColor.accentPurple,
                title: "Ziel setzen",
                subtitle: "Definiere dein Wachstumsziel und bleibe fokussiert.",
                action: onGoal
            )
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Für dich heute")
                .font(AVENFont.body(13, weight: .semibold))
                .foregroundColor(AVENColor.textPrimary)
                .padding(.bottom, 8)

            ForEach(rows.indices, id: \.self) { index in
                Button(action: rows[index].action) {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(rows[index].color.opacity(0.09))
                                .frame(width: 28, height: 28)
                            Image(systemName: rows[index].icon)
                                .font(.system(size: 12))
                                .foregroundColor(rows[index].color)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text(rows[index].title)
                                .font(AVENFont.body(11, weight: .semibold))
                                .foregroundColor(AVENColor.textPrimary)
                            Text(rows[index].subtitle)
                                .font(AVENFont.body(9))
                                .foregroundColor(AVENColor.textMuted)
                                .lineLimit(1)
                        }

                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AVENColor.textMuted)
                    }
                    .padding(.vertical, 7)
                }
                .buttonStyle(.plain)

                if index < rows.count - 1 {
                    AVENColor.borderSubtle.frame(height: 0.5)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .homeCard()
    }
}

private struct FreshActionPlanCard: View {
    let hasCompletedAnalysis: Bool
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Aktionsplan")
                        .font(AVENFont.body(13, weight: .semibold))
                        .foregroundColor(AVENColor.textPrimary)
                    Spacer()
                    Text(hasCompletedAnalysis ? "Analyse bereit" : "Noch nicht erstellt")
                        .font(AVENFont.body(10, weight: .medium))
                        .foregroundColor(hasCompletedAnalysis ? AVENColor.accentPurple : AVENColor.textMuted)
                }

                HStack(spacing: 9) {
                    Image(systemName: "checklist")
                        .font(.system(size: 20))
                        .foregroundColor(AVENColor.accentPurple.opacity(0.55))

                    Text(hasCompletedAnalysis
                         ? "Deine nächsten Schritte wurden aus deiner Analyse vorbereitet."
                         : "Nach deiner ersten Analyse erscheinen hier deine nächsten Schritte.")
                        .font(AVENFont.body(10))
                        .foregroundColor(AVENColor.textSecondary)
                        .lineLimit(2)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AVENColor.textMuted)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .homeCard()
        }
        .buttonStyle(PressButtonStyle())
    }
}

// ─── Ready dashboard: growth brief ───────────────────────────────────────────

private struct HomeGrowthBriefCard: View {
    let score: AVENScore?
    let actions: [GrowthActionItem]

    private var rows: [(String, String)] {
        var result: [(String, String)] = []

        if let score {
            result.append(("chart.bar.fill", "AVEN Score: \(score.total)/100 · \(score.status)"))
        }

        for action in actions.filter({ !$0.isCompleted && !$0.isProLocked }).prefix(2) {
            result.append(("arrow.right.circle.fill", action.title))
        }

        if result.isEmpty {
            result.append(("checkmark.circle.fill", "Deine Analyse ist abgeschlossen."))
        }

        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("Growth Brief")
                    .font(AVENFont.display(14))
                    .foregroundColor(AVENColor.textPrimary)
                Text("Aus deiner Analyse")
                    .font(AVENFont.body(10))
                    .foregroundColor(AVENColor.textMuted)
            }
            .padding(.bottom, 8)

            ForEach(rows.indices, id: \.self) { index in
                HStack(spacing: 8) {
                    Image(systemName: rows[index].0)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AVENColor.accentPurple)
                        .frame(width: 16)

                    Text(rows[index].1)
                        .font(AVENFont.body(11))
                        .foregroundColor(AVENColor.textSecondary)
                        .lineLimit(2)

                    Spacer(minLength: 0)
                }

                if index < rows.count - 1 {
                    AVENColor.borderSubtle
                        .frame(height: 0.5)
                        .padding(.vertical, 6)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .homeCard()
    }
}

// ─── Ready dashboard: score ───────────────────────────────────────────────────

private struct HomeScoreCard: View {
    let score: AVENScore?
    @State private var showDetail = false

    var body: some View {
        Button { showDetail = true } label: {
            HStack(alignment: .center, spacing: 14) {
                HomeScoreRing(total: score?.total ?? 0)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("AVEN Score")
                                .font(AVENFont.body(11))
                                .foregroundColor(AVENColor.textMuted)
                            Text(score?.status ?? "–")
                                .font(AVENFont.display(16))
                                .foregroundStyle(LinearGradient(
                                    colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                        }

                        Spacer()

                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 8, weight: .semibold))
                            Text("Aktuell")
                                .font(AVENFont.body(9, weight: .semibold))
                        }
                        .foregroundColor(AVENColor.accentPurple)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(AVENColor.accentPurple.opacity(0.08))
                        .clipShape(Capsule())
                    }

                    Text(score?.explanation ?? "Deine erste Analyse ist abgeschlossen.")
                        .font(AVENFont.body(11))
                        .foregroundColor(AVENColor.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 3) {
                        Text("Score verbessern")
                            .font(AVENFont.body(10, weight: .medium))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundColor(AVENColor.accentPurple)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .homeCard()
        }
        .buttonStyle(PressButtonStyle())
        .sheet(isPresented: $showDetail) { ScoreDetailSheet(score: score) }
    }
}

private struct HomeScoreRing: View {
    let total: Int
    @State private var animated = 0

    private var progress: Double { Double(animated) / 100.0 }
    private let size: CGFloat = 70
    private let lineWidth: CGFloat = 7

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0.15, to: 0.85)
                .stroke(AVENColor.borderSubtle, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(90))

            Circle()
                .trim(from: 0.15, to: max(0.15, 0.15 + 0.70 * progress))
                .stroke(LinearGradient(
                    colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                    startPoint: .leading,
                    endPoint: .trailing
                ), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(90))
                .animation(.easeOut(duration: 1.0), value: animated)

            VStack(spacing: 0) {
                Text("\(animated)")
                    .font(AVENFont.display(18))
                    .foregroundColor(AVENColor.textPrimary)
                Text("/ 100")
                    .font(AVENFont.body(9))
                    .foregroundColor(AVENColor.textMuted)
            }
        }
        .frame(width: size, height: size)
        .onAppear { withAnimation(.easeOut(duration: 1.0)) { animated = total } }
        .onChange(of: total) { _, value in
            withAnimation(.easeOut(duration: 0.6)) { animated = value }
        }
    }
}

// ─── Ready dashboard: performance ─────────────────────────────────────────────

private struct HomePerformanceSection: View {
    let metrics: [ProfileMetric]
    let period: HomeViewState.Period
    let onSelectPeriod: (HomeViewState.Period) -> Void

    private var display: [ProfileMetric] {
        metrics.isEmpty ? [
            ProfileMetric(label: "Follower", value: "–", change: "–", isPositive: true),
            ProfileMetric(label: "Aufrufe", value: "–", change: "–", isPositive: true),
            ProfileMetric(label: "Likes", value: "–", change: "–", isPositive: true)
        ] : Array(metrics.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Deine Performance")
                    .font(AVENFont.body(13, weight: .semibold))
                    .foregroundColor(AVENColor.textPrimary)

                Spacer()

                HStack(spacing: 3) {
                    ForEach(HomeViewState.Period.allCases, id: \.self) { item in
                        Button {
                            AVENHaptic.light()
                            onSelectPeriod(item)
                        } label: {
                            Text(item.rawValue)
                                .font(AVENFont.body(10, weight: period == item ? .semibold : .regular))
                                .foregroundColor(period == item ? AVENColor.accentPurple : AVENColor.textMuted)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(period == item ? AVENColor.accentPurple.opacity(0.09) : Color.clear)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(PressButtonStyle())
                    }
                }
            }

            HStack(spacing: 7) {
                ForEach(display) { metric in
                    HomeMetricCard(metric: metric)
                }
            }
        }
    }
}

private struct HomeMetricCard: View {
    let metric: ProfileMetric
    private let sparks: [CGFloat] = [0.35, 0.52, 0.42, 0.68, 0.58, 0.78, 1.0]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(metric.label)
                .font(AVENFont.body(10))
                .foregroundColor(AVENColor.textMuted)

            Text(metric.value)
                .font(AVENFont.display(16))
                .foregroundColor(AVENColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if !metric.change.isEmpty && metric.change != "–" {
                HStack(spacing: 2) {
                    Image(systemName: metric.isPositive ? "arrow.up" : "arrow.down")
                        .font(.system(size: 8, weight: .bold))
                    Text(metric.change)
                        .font(AVENFont.body(9, weight: .semibold))
                }
                .foregroundColor(metric.isPositive ? AVENColor.textPositive : AVENColor.textNegative)
            } else {
                Color.clear.frame(height: 12)
            }

            HStack(alignment: .bottom, spacing: 2) {
                ForEach(sparks.indices, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(LinearGradient(
                            colors: [AVENColor.accentPurple.opacity(0.40), AVENColor.accentBlue.opacity(0.30)],
                            startPoint: .bottom,
                            endPoint: .top
                        ))
                        .frame(width: 2.5, height: sparks[index] * 12)
                }
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeCard()
    }
}

// ─── Ready dashboard: personalized rows ──────────────────────────────────────

private struct HomeTodayCard: View {
    let score: AVENScore?
    let actions: [GrowthActionItem]

    private var openActions: [GrowthActionItem] {
        actions.filter { !$0.isCompleted && !$0.isProLocked }
    }

    private var insightText: String {
        let text = score?.explanation.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? "Deine Analyse ist abgeschlossen." : text
    }

    private var nextAction: String {
        openActions.first?.title ?? "Aktionsplan öffnen und nächsten Schritt wählen"
    }

    private var rows: [(String, Color, String, String)] {
        [
            ("checkmark.circle.fill", AVENColor.textPositive, "Analyse", score.map { "AVEN Score \($0.total)/100 · \($0.status)" } ?? "Analyse abgeschlossen"),
            ("lightbulb.fill", AVENColor.accentBlue, "AVEN Erkenntnis", insightText),
            ("arrow.right.circle.fill", AVENColor.accentPurple, "Nächster Schritt", nextAction)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Für dich heute")
                .font(AVENFont.body(13, weight: .semibold))
                .foregroundColor(AVENColor.textPrimary)
                .padding(.bottom, 8)

            ForEach(rows.indices, id: \.self) { index in
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(rows[index].1.opacity(0.09))
                            .frame(width: 28, height: 28)
                        Image(systemName: rows[index].0)
                            .font(.system(size: 12))
                            .foregroundColor(rows[index].1)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(rows[index].2)
                            .font(AVENFont.body(10, weight: .semibold))
                            .foregroundColor(AVENColor.textMuted)
                        Text(rows[index].3)
                            .font(AVENFont.body(12))
                            .foregroundColor(AVENColor.textPrimary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.vertical, 7)

                if index < rows.count - 1 {
                    AVENColor.borderSubtle.frame(height: 0.5)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .homeCard()
    }
}

// ─── Ready dashboard: action plan ─────────────────────────────────────────────

private struct HomeActionPlanCard: View {
    let actions: [GrowthActionItem]
    let container: AppContainer

    private var openActions: [GrowthActionItem] {
        actions.filter { !$0.isCompleted && !$0.isProLocked }
    }

    private var next: String {
        openActions.first?.title ?? "Keine offene Aufgabe aus der aktuellen Analyse"
    }

    var body: some View {
        Button { container.selectedTab = .actionPlan } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("Aktionsplan")
                        .font(AVENFont.body(13, weight: .semibold))
                        .foregroundColor(AVENColor.textPrimary)
                    Spacer()
                    Text(openActions.isEmpty ? "Keine offen" : "\(openActions.count) offen")
                        .font(AVENFont.body(11, weight: .medium))
                        .foregroundColor(openActions.isEmpty ? AVENColor.textMuted : AVENColor.accentPurple)
                }

                HStack(spacing: 7) {
                    Image(systemName: openActions.isEmpty ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(openActions.isEmpty ? AVENColor.textPositive : AVENColor.accentPurple)

                    Text(next)
                        .font(AVENFont.body(11))
                        .foregroundColor(AVENColor.textSecondary)
                        .lineLimit(2)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AVENColor.textMuted)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .homeCard()
        }
        .buttonStyle(PressButtonStyle())
    }
}

// ─── Loading overlay ──────────────────────────────────────────────────────────

private struct HomeLoadingOverlay: View {
    var body: some View {
        ZStack {
            AVENColor.backgroundPrimary.opacity(0.75).ignoresSafeArea()
            VStack(spacing: AVENSpacing.md) {
                ProgressView().tint(AVENColor.accentPurple)
                Text("Lade Daten…")
                    .font(AVENFont.body(13))
                    .foregroundColor(AVENColor.textSecondary)
            }
        }
    }
}

// ─── Sheets ───────────────────────────────────────────────────────────────────

private struct NotificationsSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let items: [(String, String, String)] = [
        ("sparkles", "Profil analysieren", "Starte eine Analyse, um deinen aktuellen AVEN Score zu berechnen."),
        ("checkmark.circle", "Aktionsplan", "Öffne deinen Aktionsplan, um deine nächsten Schritte zu sehen."),
        ("arrow.up.circle", "AVEN Score", "Neue Analysen aktualisieren deinen Score und deine Empfehlungen.")
    ]

    var body: some View {
        ZStack {
            AVENColor.backgroundPrimary.ignoresSafeArea()
            VStack(spacing: 0) {
                Capsule()
                    .fill(AVENColor.borderSubtle)
                    .frame(width: 36, height: 4)
                    .padding(.top, AVENSpacing.sm)
                    .padding(.bottom, AVENSpacing.md)

                HStack {
                    Text("Benachrichtigungen")
                        .font(AVENFont.display(20))
                        .foregroundColor(AVENColor.textPrimary)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(AVENColor.textMuted)
                    }
                    .buttonStyle(PressButtonStyle())
                }
                .padding(.horizontal, AVENSpacing.md)
                .padding(.bottom, AVENSpacing.md)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AVENSpacing.sm) {
                        ForEach(items, id: \.1) { icon, title, body in
                            AVENCard {
                                HStack(alignment: .top, spacing: AVENSpacing.sm) {
                                    Image(systemName: icon)
                                        .font(.system(size: 20))
                                        .foregroundColor(AVENColor.accentPurple)
                                        .frame(width: 28)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(title)
                                            .font(AVENFont.body(14, weight: .semibold))
                                            .foregroundColor(AVENColor.textPrimary)
                                        Text(body)
                                            .font(AVENFont.body(13))
                                            .foregroundColor(AVENColor.textSecondary)
                                            .lineSpacing(3)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AVENSpacing.md)
                }

                Spacer()
            }
        }
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(28)
    }
}

private struct QuickProfileSheet: View {
    let tikTokAccount: ConnectedTikTokAccount?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AVENColor.backgroundPrimary.ignoresSafeArea()
            VStack(spacing: AVENSpacing.xl) {
                Capsule()
                    .fill(AVENColor.borderSubtle)
                    .frame(width: 36, height: 4)
                    .padding(.top, AVENSpacing.sm)

                if let url = tikTokAccount?.avatarUrl.flatMap(URL.init) {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                        } else {
                            defaultAvatar
                        }
                    }
                } else {
                    defaultAvatar
                }

                VStack(spacing: 6) {
                    if let account = tikTokAccount {
                        Text(account.username)
                            .font(AVENFont.display(22))
                            .foregroundColor(AVENColor.textPrimary)
                        Text("TikTok verbunden")
                            .font(AVENFont.body(14))
                            .foregroundColor(AVENColor.textPositive)
                    } else {
                        Text("Dein Profil")
                            .font(AVENFont.display(22))
                            .foregroundColor(AVENColor.textPrimary)
                        Text("Verwalte dein Konto im Profil-Tab.")
                            .font(AVENFont.body(14))
                            .foregroundColor(AVENColor.textSecondary)
                    }
                }

                Spacer()

                Button { dismiss() } label: {
                    Text("Schließen")
                        .font(AVENFont.body(15))
                        .foregroundColor(AVENColor.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(PressButtonStyle())
                .padding(.horizontal, AVENSpacing.md)
                .padding(.bottom, AVENSpacing.lg)
            }
        }
        .presentationDetents([.medium])
        .presentationCornerRadius(28)
    }

    private var defaultAvatar: some View {
        Circle()
            .fill(LinearGradient(
                colors: [AVENColor.accentPurple.opacity(0.2), AVENColor.accentBlue.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .frame(width: 80, height: 80)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 34))
                    .foregroundColor(AVENColor.accentPurple)
            )
    }
}

#Preview {
    HomeView(container: AppContainer.preview)
        .environmentObject(AppContainer.preview)
}
