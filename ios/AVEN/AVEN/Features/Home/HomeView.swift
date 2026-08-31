import SwiftUI

// ─── HomeView ─────────────────────────────────────────────────────────────────

struct HomeView: View {
    @StateObject private var vm: HomeViewModel
    @EnvironmentObject private var container: AppContainer
    @State private var titleTrigger = UUID()

    init(container: AppContainer) {
        _vm = StateObject(wrappedValue: container.makeHomeViewModel())
    }

    var body: some View {
        ZStack {
            AVENColor.backgroundPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    // 1. Header
                    HomeHeaderBar(titleTrigger: titleTrigger,
                                  tikTokAccount: container.connectedTikTokAccount)

                    // 2. TikTok Account Card
                    HomeTikTokCard(
                        tikTokAccount: container.connectedTikTokAccount,
                        onSwitchAccount: { container.showTikTokAccount = true }
                    )
                    .cardAppear(delay: 0.03)

                    // 3. Growth Brief
                    HomeGrowthBriefCard()
                        .cardAppear(delay: 0.06)

                    // 4. Performance Section
                    HomePerformanceSection(
                        metrics: vm.state.metrics,
                        period: vm.state.period,
                        onSelectPeriod: { vm.selectPeriod($0) }
                    )
                    .cardAppear(delay: 0.09)

                    // 5. AVEN Score Card
                    HomeScoreCard(score: vm.state.score)
                        .cardAppear(delay: 0.12)

                    // 6. Für dich heute
                    HomeTodayCard()
                        .cardAppear(delay: 0.15)

                    // 7. Aktionsplan Preview
                    HomeActionPlanCard(actions: vm.state.actions, container: container)
                        .cardAppear(delay: 0.18)

                    Color.clear.frame(height: 8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }

            if vm.state.isLoading && vm.state.score == nil {
                HomeLoadingOverlay()
            }
        }
        .task { await vm.load() }
        .animation(AVENMotion.smooth, value: vm.state.isLoading)
        .onChange(of: container.selectedTab) { _, newTab in
            if newTab == .home {
                titleTrigger = UUID()
                Task { await vm.load() }
            }
        }
    }
}

// ─── Card style helper ────────────────────────────────────────────────────────

private extension View {
    func homeCard() -> some View {
        self
            .background(AVENColor.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color(hex: "#0D0E1A").opacity(0.055), lineWidth: 0.5)
            )
            .shadow(color: Color(hex: "#0D0E1A").opacity(0.035), radius: 4, x: 0, y: 1)
    }
}

// ─── 1. Header ────────────────────────────────────────────────────────────────

private struct HomeHeaderBar: View {
    let titleTrigger:  UUID
    let tikTokAccount: ConnectedTikTokAccount?
    @State private var showNotifications = false
    @State private var showProfile       = false

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
        .sheet(isPresented: $showProfile)       { QuickProfileSheet(tikTokAccount: tikTokAccount) }
    }
}

// ─── 2. TikTok Account Card ───────────────────────────────────────────────────

private struct HomeTikTokCard: View {
    let tikTokAccount:   ConnectedTikTokAccount?
    let onSwitchAccount: () -> Void

    private var username: String {
        tikTokAccount?.username.isEmpty == false
            ? "@\(tikTokAccount!.username)" : "@dein_profil"
    }
    private var isConnected: Bool { tikTokAccount != nil }

    var body: some View {
        HStack(spacing: 10) {
            // Avatar
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [AVENColor.accentPurple.opacity(0.14), AVENColor.accentBlue.opacity(0.09)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 36, height: 36)
                if let url = tikTokAccount?.avatarUrl.flatMap(URL.init) {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase {
                            img.resizable().scaledToFill()
                                .frame(width: 36, height: 36).clipShape(Circle())
                        } else { avatarIcon }
                    }
                } else { avatarIcon }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(username)
                    .font(AVENFont.body(13, weight: .semibold))
                    .foregroundColor(AVENColor.textPrimary)
                HStack(spacing: 4) {
                    Circle()
                        .fill(isConnected ? AVENColor.textPositive : AVENColor.textMuted)
                        .frame(width: 5, height: 5)
                    Text(isConnected ? "TikTok verbunden · Aktiv" : "TikTok nicht verbunden")
                        .font(AVENFont.body(11))
                        .foregroundColor(isConnected ? AVENColor.textPositive : AVENColor.textMuted)
                }
            }

            Spacer()

            Button(action: onSwitchAccount) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AVENColor.textMuted)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .homeCard()
    }

    private var avatarIcon: some View {
        Image(systemName: "person.fill")
            .font(.system(size: 15))
            .foregroundColor(AVENColor.accentPurple)
    }
}

// ─── 3. Growth Brief ─────────────────────────────────────────────────────────

private struct HomeGrowthBriefCard: View {
    private let insights: [(String, String)] = [
        ("arrow.up.right",      "+8,7 % Follower-Wachstum diese Woche"),
        ("play.rectangle.fill", "Dein letztes Video performt stark"),
        ("text.bubble.fill",    "Stärkster Content-Typ: Tutorials"),
        ("lightbulb.fill",      "Hooks <3s performen besser"),
    ]

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                // Title
                HStack(spacing: 6) {
                    Text("Growth Brief")
                        .font(AVENFont.display(14))
                        .foregroundColor(AVENColor.textPrimary)
                    Text("Heute für dich")
                        .font(AVENFont.body(10))
                        .foregroundColor(AVENColor.textMuted)
                }
                .padding(.bottom, 8)

                ForEach(insights.indices, id: \.self) { i in
                    HStack(spacing: 7) {
                        Image(systemName: insights[i].0)
                            .font(.system(size: 10))
                            .foregroundStyle(LinearGradient(
                                colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                                startPoint: .leading, endPoint: .trailing))
                            .frame(width: 14)
                        Text(insights[i].1)
                            .font(AVENFont.body(11))
                            .foregroundColor(AVENColor.textSecondary)
                            .lineLimit(1)
                    }
                    if i < insights.count - 1 {
                        Color(hex: "#0D0E1A").opacity(0.05)
                            .frame(height: 0.5)
                            .padding(.vertical, 5)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            GrowthBriefBars()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .homeCard()
    }
}

private struct GrowthBriefBars: View {
    private let bars: [CGFloat] = [0.40, 0.65, 0.50, 0.80, 0.60, 0.95, 0.75]
    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(bars.indices, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearGradient(
                        colors: [AVENColor.accentPurple.opacity(0.55), AVENColor.accentBlue.opacity(0.40)],
                        startPoint: .bottom, endPoint: .top))
                    .frame(width: 5, height: bars[i] * 40)
            }
        }
        .frame(width: 53, height: 42, alignment: .bottom)
    }
}

// ─── 4. Performance Section ───────────────────────────────────────────────────

private struct HomePerformanceSection: View {
    let metrics:        [ProfileMetric]
    let period:         HomeViewState.Period
    let onSelectPeriod: (HomeViewState.Period) -> Void

    private var display: [ProfileMetric] {
        metrics.isEmpty ? [
            ProfileMetric(label: "Follower", value: "–", change: "–", isPositive: true),
            ProfileMetric(label: "Aufrufe",  value: "–", change: "–", isPositive: true),
            ProfileMetric(label: "Likes",    value: "–", change: "–", isPositive: true),
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
                    ForEach(HomeViewState.Period.allCases, id: \.self) { p in
                        Button {
                            AVENHaptic.light(); onSelectPeriod(p)
                        } label: {
                            Text(p.rawValue)
                                .font(AVENFont.body(10, weight: period == p ? .semibold : .regular))
                                .foregroundColor(period == p ? AVENColor.accentPurple : AVENColor.textMuted)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(period == p ? AVENColor.accentPurple.opacity(0.09) : Color.clear)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(PressButtonStyle())
                    }
                }
            }

            HStack(spacing: 7) {
                ForEach(display) { m in HomeMetricCard(metric: m) }
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
                .lineLimit(1).minimumScaleFactor(0.8)

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
                ForEach(sparks.indices, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(LinearGradient(
                            colors: [AVENColor.accentPurple.opacity(0.40), AVENColor.accentBlue.opacity(0.30)],
                            startPoint: .bottom, endPoint: .top))
                        .frame(width: 2.5, height: sparks[i] * 12)
                }
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeCard()
    }
}

// ─── 5. AVEN Score Card ───────────────────────────────────────────────────────

private struct HomeScoreCard: View {
    let score: AVENScore?
    @State private var showDetail = false

    var body: some View {
        Button { showDetail = true } label: {
            HStack(alignment: .center, spacing: 14) {

                // Compact score ring — custom, not AnimatedScoreArcView (avoids font-size clash)
                HomeScoreRing(total: score?.total ?? 0)

                // Info
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
                                    startPoint: .leading, endPoint: .trailing))
                        }
                        Spacer()
                        // Weekly badge top-right
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 8, weight: .bold))
                            Text("+4 Woche")
                                .font(AVENFont.body(9, weight: .semibold))
                        }
                        .foregroundColor(AVENColor.textPositive)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(AVENColor.textPositive.opacity(0.10))
                        .clipShape(Capsule())
                    }

                    Text(score?.explanation ?? "Starte eine Analyse für deinen Score.")
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

/// Compact arc-ring for the Home card — independent of AnimatedScoreArcView
/// so we can control font size without touching the shared component.
private struct HomeScoreRing: View {
    let total: Int
    @State private var animated: Int = 0

    private var progress: Double { Double(animated) / 100.0 }
    private let size: CGFloat = 70
    private let lineW: CGFloat = 7

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0.15, to: 0.85)
                .stroke(Color(hex: "#0D0E1A").opacity(0.07),
                        style: StrokeStyle(lineWidth: lineW, lineCap: .round))
                .rotationEffect(.degrees(90))

            Circle()
                .trim(from: 0.15, to: max(0.15, 0.15 + 0.70 * progress))
                .stroke(LinearGradient(
                    colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                    startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: lineW, lineCap: .round))
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
        .onChange(of: total) { _, v in withAnimation(.easeOut(duration: 0.6)) { animated = v } }
    }
}

// ─── 6. Für dich heute ───────────────────────────────────────────────────────

private struct HomeTodayCard: View {
    private let rows: [(String, Color, String, String)] = [
        ("chart.bar.fill",         Color(hex: "#7B4FFF"), "Performance",      "Reichweite stieg diese Woche"),
        ("lightbulb.fill",         Color(hex: "#4F8FFF"), "AVEN Erkenntnis",  "Hooks <3s performen besser"),
        ("arrow.right.circle.fill",Color(hex: "#16A34A"), "Nächster Schritt", "Profil-Bio mit CTA optimieren"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Für dich heute")
                .font(AVENFont.body(13, weight: .semibold))
                .foregroundColor(AVENColor.textPrimary)
                .padding(.bottom, 8)

            ForEach(rows.indices, id: \.self) { i in
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(rows[i].1.opacity(0.09))
                            .frame(width: 28, height: 28)
                        Image(systemName: rows[i].0)
                            .font(.system(size: 12))
                            .foregroundColor(rows[i].1)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(rows[i].2)
                            .font(AVENFont.body(10, weight: .semibold))
                            .foregroundColor(AVENColor.textMuted)
                        Text(rows[i].3)
                            .font(AVENFont.body(12))
                            .foregroundColor(AVENColor.textPrimary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AVENColor.textMuted)
                }
                .padding(.vertical, 7)

                if i < rows.count - 1 {
                    Color(hex: "#0D0E1A").opacity(0.05).frame(height: 0.5)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .homeCard()
    }
}

// ─── 7. Aktionsplan Preview ───────────────────────────────────────────────────

private struct HomeActionPlanCard: View {
    let actions:   [GrowthActionItem]
    let container: AppContainer

    private var done:  Int    { actions.filter { $0.isCompleted }.count }
    private var total: Int    { max(actions.count, 6) }
    private var prog:  Double { total > 0 ? Double(done) / Double(total) : 0 }
    private var next:  String {
        actions.first { !$0.isCompleted && !$0.isProLocked }?.title
            ?? "Hook mit starker Aussage testen"
    }

    var body: some View {
        Button { container.selectedTab = .actionPlan } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Aktionsplan")
                        .font(AVENFont.body(13, weight: .semibold))
                        .foregroundColor(AVENColor.textPrimary)
                    Spacer()
                    Text("\(done) von \(total) erledigt")
                        .font(AVENFont.body(11))
                        .foregroundColor(AVENColor.textMuted)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(hex: "#0D0E1A").opacity(0.07))
                            .frame(height: 4)
                        Capsule()
                            .fill(LinearGradient(
                                colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                                startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * max(prog, 0.03), height: 4)
                    }
                }
                .frame(height: 4)

                HStack(spacing: 5) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AVENColor.accentPurple)
                    Text("Nächste: \(next)")
                        .font(AVENFont.body(11))
                        .foregroundColor(AVENColor.textSecondary)
                        .lineLimit(1)
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

// ─── Sheets (unchanged logic) ─────────────────────────────────────────────────

private struct NotificationsSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let items: [(String, String, String)] = [
        ("sparkles",         "Neue Analyse verfügbar",   "Lade einen Screenshot hoch und erhalte deinen AVEN Score."),
        ("checkmark.circle", "Aktionsplan-Erinnerung",   "Du hast noch 2 offene Aufgaben. Erledige sie für mehr Punkte."),
        ("arrow.up.circle",  "Score-Tipp",               "Accounts mit Bio-CTA wachsen 3× schneller."),
    ]
    var body: some View {
        ZStack {
            AVENColor.backgroundPrimary.ignoresSafeArea()
            VStack(spacing: 0) {
                Capsule().fill(AVENColor.borderSubtle).frame(width: 36, height: 4)
                    .padding(.top, AVENSpacing.sm).padding(.bottom, AVENSpacing.md)
                HStack {
                    Text("Benachrichtigungen").font(AVENFont.display(20)).foregroundColor(AVENColor.textPrimary)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 24)).foregroundColor(AVENColor.textMuted)
                    }.buttonStyle(PressButtonStyle())
                }
                .padding(.horizontal, AVENSpacing.md).padding(.bottom, AVENSpacing.md)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AVENSpacing.sm) {
                        ForEach(items, id: \.1) { icon, title, body in
                            AVENCard {
                                HStack(alignment: .top, spacing: AVENSpacing.sm) {
                                    Image(systemName: icon).font(.system(size: 20))
                                        .foregroundColor(AVENColor.accentPurple).frame(width: 28)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(title).font(AVENFont.body(14, weight: .semibold)).foregroundColor(AVENColor.textPrimary)
                                        Text(body).font(AVENFont.body(13)).foregroundColor(AVENColor.textSecondary).lineSpacing(3)
                                    }
                                }
                            }
                        }
                    }.padding(.horizontal, AVENSpacing.md)
                }
                Spacer()
            }
        }
        .presentationDetents([.medium, .large]).presentationCornerRadius(28)
    }
}

private struct QuickProfileSheet: View {
    let tikTokAccount: ConnectedTikTokAccount?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ZStack {
            AVENColor.backgroundPrimary.ignoresSafeArea()
            VStack(spacing: AVENSpacing.xl) {
                Capsule().fill(AVENColor.borderSubtle).frame(width: 36, height: 4).padding(.top, AVENSpacing.sm)
                if let url = tikTokAccount?.avatarUrl.flatMap(URL.init) {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase {
                            img.resizable().scaledToFill().frame(width: 80, height: 80).clipShape(Circle())
                        } else { defaultAvatar }
                    }
                } else { defaultAvatar }
                VStack(spacing: 6) {
                    if let acct = tikTokAccount {
                        Text(acct.username).font(AVENFont.display(22)).foregroundColor(AVENColor.textPrimary)
                        Text("TikTok verbunden").font(AVENFont.body(14)).foregroundColor(AVENColor.textPositive)
                    } else {
                        Text("Dein Profil").font(AVENFont.display(22)).foregroundColor(AVENColor.textPrimary)
                        Text("Verwalte dein Konto im Profil-Tab.").font(AVENFont.body(14)).foregroundColor(AVENColor.textSecondary)
                    }
                }
                Spacer()
                Button { dismiss() } label: {
                    Text("Schließen").font(AVENFont.body(15)).foregroundColor(AVENColor.textSecondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                }.buttonStyle(PressButtonStyle())
                .padding(.horizontal, AVENSpacing.md).padding(.bottom, AVENSpacing.lg)
            }
        }
        .presentationDetents([.medium]).presentationCornerRadius(28)
    }
    private var defaultAvatar: some View {
        Circle()
            .fill(LinearGradient(colors: [AVENColor.accentPurple.opacity(0.2), AVENColor.accentBlue.opacity(0.1)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 80, height: 80)
            .overlay(Image(systemName: "person.fill").font(.system(size: 34)).foregroundColor(AVENColor.accentPurple))
    }
}

#Preview {
    HomeView(container: AppContainer.preview)
        .environmentObject(AppContainer.preview)
}
