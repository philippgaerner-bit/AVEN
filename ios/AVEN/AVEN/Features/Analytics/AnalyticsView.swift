import SwiftUI

// ─── AnalyticsView ────────────────────────────────────────────────────────────

struct AnalyticsView: View {
    @StateObject private var vm = AnalyticsViewModel()
    @EnvironmentObject private var container: AppContainer
    @State private var selectedTab: ATab = .uebersicht

    enum ATab: String, CaseIterable {
        case uebersicht = "Übersicht"
        case profil     = "Profil"
        case content    = "Content"
        case engagement = "Engagement"
        case audience   = "Audience"
    }

    var body: some View {
        ZStack {
            AVENColor.backgroundPrimary.ignoresSafeArea()
            VStack(spacing: 0) {
                // ── Fixed header + tabs (not scrollable) ──────────────────────
                VStack(spacing: 0) {
                    AHeader()
                    ATabs(selected: $selectedTab)
                }

                // ── Scrollable content ────────────────────────────────────────
                if vm.isLoading {
                    Spacer()
                    ProgressView().tint(AVENColor.accentPurple)
                    Spacer()
                } else if let data = vm.data {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            AStandSection(data: data, vm: vm)
                                .cardAppear(delay: 0.04)
                            AScoreSection(data: data, vm: vm)
                                .cardAppear(delay: 0.08)
                            AInsightsCard()
                                .cardAppear(delay: 0.12)
                            ANextActionsSection(container: container)
                                .cardAppear(delay: 0.16)
                            Color.clear.frame(height: 12)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                    }
                } else {
                    // First load / no data yet
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            ANoDataCard()
                            ANextActionsSection(container: container)
                            Color.clear.frame(height: 12)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                    }
                }
            }
        }
        .task { await vm.load(period: .week) }
        .onChange(of: container.selectedTab) { _, newTab in
            if newTab == .analytics { Task { await vm.load(period: vm.selectedPeriod) } }
        }
    }
}

// ─── Card helper ──────────────────────────────────────────────────────────────

private extension View {
    func aCard() -> some View {
        self
            .background(AVENColor.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color(hex: "#0D0E1A").opacity(0.055), lineWidth: 0.5))
            .shadow(color: Color(hex: "#0D0E1A").opacity(0.032), radius: 3, x: 0, y: 1)
    }
}

// ─── Header ───────────────────────────────────────────────────────────────────

private struct AHeader: View {
    @State private var trigger = UUID()
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Top bar
            HStack {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AVENColor.textMuted)
                    .frame(width: 32, height: 32)
                Spacer()
                AnimatedAVENTitle(trigger: trigger)
                Spacer()
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AVENColor.textMuted)
                    .frame(width: 32, height: 32)
            }

            // Title + subtitle
            Text("Analyse")
                .font(AVENFont.display(24))
                .foregroundColor(AVENColor.textPrimary)
            Text("Verstehe deinen Account. Triff bessere Entscheidungen.")
                .font(AVENFont.body(13))
                .foregroundColor(AVENColor.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }
}

// ─── Tabs ─────────────────────────────────────────────────────────────────────

private struct ATabs: View {
    @Binding var selected: AnalyticsView.ATab

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(AnalyticsView.ATab.allCases, id: \.self) { tab in
                    Button { withAnimation(.easeInOut(duration: 0.18)) { selected = tab } } label: {
                        Text(tab.rawValue)
                            .font(AVENFont.body(12, weight: selected == tab ? .semibold : .regular))
                            .foregroundColor(selected == tab ? AVENColor.accentPurple : AVENColor.textMuted)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(selected == tab
                                ? AVENColor.accentPurple.opacity(0.09) : Color.clear)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PressButtonStyle())
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 4)
    }
}

// ─── 1. Dein aktueller Stand ──────────────────────────────────────────────────

private struct AStandSection: View {
    let data: AnalyticsPeriodData
    @ObservedObject var vm: AnalyticsViewModel

    private let dateRange: String = {
        let fmt = DateFormatter(); fmt.dateFormat = "d. MMM"; fmt.locale = Locale(identifier: "de_DE")
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -7, to: end) ?? end
        return "\(fmt.string(from: start)) – \(fmt.string(from: end))"
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Dein aktueller Stand")
                    .font(AVENFont.body(13, weight: .semibold))
                    .foregroundColor(AVENColor.textPrimary)
                Spacer()
                Text(dateRange)
                    .font(AVENFont.body(10))
                    .foregroundColor(AVENColor.textMuted)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color(hex: "#0D0E1A").opacity(0.05))
                    .clipShape(Capsule())
            }

            HStack(spacing: 7) {
                AMetricCard(
                    icon: "person.2.fill",
                    label: "Follower",
                    value: formatK(data.followers),
                    change: data.followersChange,
                    hasChange: data.hasRealHistory
                )
                AMetricCard(
                    icon: "eye.fill",
                    label: "Aufrufe",
                    value: formatK(data.views),
                    change: data.viewsChange,
                    hasChange: false
                )
                AMetricCard(
                    icon: "heart.fill",
                    label: "Likes",
                    value: formatK(data.likes),
                    change: data.likesChange,
                    hasChange: data.hasRealHistory
                )
                AMetricCard(
                    icon: "chart.bar.fill",
                    label: "Engagement",
                    value: String(format: "%.1f%%", data.engagement),
                    change: data.engagementChange,
                    hasChange: false
                )
            }
        }
    }
}

private struct AMetricCard: View {
    let icon:      String
    let label:     String
    let value:     String
    let change:    Double
    let hasChange: Bool
    private let sparks: [CGFloat] = [0.3, 0.5, 0.4, 0.65, 0.55, 0.8, 1.0]

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(LinearGradient(
                    colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                    startPoint: .leading, endPoint: .trailing))

            Text(label)
                .font(AVENFont.body(9))
                .foregroundColor(AVENColor.textMuted)

            Text(value)
                .font(AVENFont.display(14))
                .foregroundColor(AVENColor.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.7)

            if hasChange && change != 0 {
                HStack(spacing: 1) {
                    Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                        .font(.system(size: 7, weight: .bold))
                    Text(String(format: "%.1f%%", abs(change)))
                        .font(AVENFont.body(8, weight: .semibold))
                }
                .foregroundColor(change >= 0 ? AVENColor.textPositive : AVENColor.textNegative)
            } else {
                Color.clear.frame(height: 10)
            }

            // Mini sparkline
            HStack(alignment: .bottom, spacing: 1.5) {
                ForEach(sparks.indices, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(LinearGradient(
                            colors: [AVENColor.accentPurple.opacity(0.40),
                                     AVENColor.accentBlue.opacity(0.30)],
                            startPoint: .bottom, endPoint: .top))
                        .frame(width: 2, height: sparks[i] * 10)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .aCard()
    }
}

// ─── 2. AVEN Score Section ────────────────────────────────────────────────────

private struct AScoreSection: View {
    let data: AnalyticsPeriodData
    @ObservedObject var vm: AnalyticsViewModel
    @State private var showDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top row: ring + chart
            HStack(alignment: .top, spacing: 14) {
                // Left: ring + info
                VStack(alignment: .leading, spacing: 6) {
                    // Compact ring
                    AScoreRing(score: data.currentScore)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("AVEN Score").font(AVENFont.body(10)).foregroundColor(AVENColor.textMuted)
                        Text(scoreStatus).font(AVENFont.display(15))
                            .foregroundStyle(LinearGradient(
                                colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                                startPoint: .leading, endPoint: .trailing))
                        Text("Basierend auf deiner letzten Analyse.")
                            .font(AVENFont.body(10)).foregroundColor(AVENColor.textSecondary)
                            .lineLimit(2)
                    }

                    Button { showDetail = true } label: {
                        HStack(spacing: 3) {
                            Text("Score verbessern")
                                .font(AVENFont.body(10, weight: .medium))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundColor(AVENColor.accentPurple)
                    }
                }
                .frame(width: 130)

                // Right: score history chart
                VStack(alignment: .trailing, spacing: 4) {
                    HStack {
                        Spacer()
                        // Period selector
                        HStack(spacing: 4) {
                            ForEach(AnalyticsPeriod.allCases, id: \.self) { p in
                                Button {
                                    AVENHaptic.light()
                                    Task { await vm.load(period: p) }
                                } label: {
                                    Text(p.rawValue)
                                        .font(AVENFont.body(9, weight: vm.selectedPeriod == p ? .semibold : .regular))
                                        .foregroundColor(vm.selectedPeriod == p ? AVENColor.accentPurple : AVENColor.textMuted)
                                        .padding(.horizontal, 6).padding(.vertical, 3)
                                        .background(vm.selectedPeriod == p
                                            ? AVENColor.accentPurple.opacity(0.09) : Color.clear)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(PressButtonStyle())
                            }
                        }
                    }

                    if data.hasRealHistory && data.snapshots.count >= 2 {
                        MiniLineChart(snapshots: data.snapshots)
                            .frame(height: 80)
                            .chartReveal()
                    } else {
                        // Empty chart state
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(hex: "#0D0E1A").opacity(0.03))
                            VStack(spacing: 4) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 18))
                                    .foregroundColor(AVENColor.textMuted)
                                Text("Mehr Analysen\nfür Verlauf")
                                    .font(AVENFont.body(9))
                                    .foregroundColor(AVENColor.textMuted)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .frame(height: 80)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 14)
            .padding(.top, 13)
            .padding(.bottom, 10)

            // Bottom badge
            Divider().background(Color(hex: "#0D0E1A").opacity(0.05))
            HStack(spacing: 5) {
                let pos = data.scoreChange >= 0
                Image(systemName: pos ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(pos ? AVENColor.textPositive : AVENColor.textNegative)
                Text("\(pos ? "+" : "")\(data.scoreChange) Punkte gegenüber dem vorherigen Zeitraum")
                    .font(AVENFont.body(11))
                    .foregroundColor(AVENColor.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .aCard()
        .sheet(isPresented: $showDetail) {
            ScoreDetailSheet(score: AVENScore(
                total:       data.currentScore,
                status:      scoreStatus,
                explanation: "Basierend auf deiner letzten Profil-Analyse.",
                trend:       data.scoreChange >= 0 ? .up : .down
            ))
        }
    }

    private var scoreStatus: String {
        data.currentScore >= 80 ? "Stark"
            : data.currentScore >= 65 ? "Gut" : "Ausbaufähig"
    }
}

/// Self-contained score ring sized for the Analytics card (no font-size clash)
private struct AScoreRing: View {
    let score: Int
    @State private var animated: Int = 0
    private let size: CGFloat = 64
    private let lw:   CGFloat = 6

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0.15, to: 0.85)
                .stroke(Color(hex: "#0D0E1A").opacity(0.07),
                        style: StrokeStyle(lineWidth: lw, lineCap: .round))
                .rotationEffect(.degrees(90))
            Circle()
                .trim(from: 0.15, to: max(0.15, 0.15 + 0.70 * Double(animated) / 100.0))
                .stroke(LinearGradient(
                    colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                    startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: lw, lineCap: .round))
                .rotationEffect(.degrees(90))
                .animation(.easeOut(duration: 0.9), value: animated)
            VStack(spacing: 0) {
                Text("\(animated)")
                    .font(AVENFont.display(16))
                    .foregroundColor(AVENColor.textPrimary)
                Text("/ 100")
                    .font(AVENFont.body(8))
                    .foregroundColor(AVENColor.textMuted)
            }
        }
        .frame(width: size, height: size)
        .onAppear { withAnimation(.easeOut(duration: 0.9)) { animated = score } }
        .onChange(of: score) { _, v in withAnimation(.easeOut(duration: 0.6)) { animated = v } }
    }
}

// ─── 3. Wichtigste Erkenntnisse ───────────────────────────────────────────────

private struct AInsightsCard: View {
    private let rows: [(String, String, String)] = [
        ("play.rectangle.fill", "Kurze Videos performen am besten",
         "Videos unter 30 Sek. erreichen 2× mehr Aufrufe."),
        ("clock.fill", "Beste Posting-Zeit: 18:00 – 21:00 Uhr",
         "Poste abends für mehr organische Reichweite."),
        ("arrow.up.right.circle.fill", "Stetiges Wachstum",
         "Dein Account wächst konstant – bleibe am Ball."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Wichtigste Erkenntnisse")
                    .font(AVENFont.body(13, weight: .semibold))
                    .foregroundColor(AVENColor.textPrimary)
                Spacer()
                Text("Alle Insights")
                    .font(AVENFont.body(11))
                    .foregroundColor(AVENColor.accentPurple)
            }
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 10)

            ForEach(rows.indices, id: \.self) { i in
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(AVENColor.accentPurple.opacity(0.09))
                            .frame(width: 30, height: 30)
                        Image(systemName: rows[i].0)
                            .font(.system(size: 13))
                            .foregroundColor(AVENColor.accentPurple)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(rows[i].1)
                            .font(AVENFont.body(12, weight: .medium))
                            .foregroundColor(AVENColor.textPrimary)
                        Text(rows[i].2)
                            .font(AVENFont.body(10))
                            .foregroundColor(AVENColor.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AVENColor.textMuted)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)

                if i < rows.count - 1 {
                    Color(hex: "#0D0E1A").opacity(0.05).frame(height: 0.5)
                        .padding(.horizontal, 14)
                }
            }
            .padding(.bottom, 4)
        }
        .aCard()
    }
}

// ─── 4. Next Actions ─────────────────────────────────────────────────────────

private struct ANextActionsSection: View {
    let container: AppContainer

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Was möchtest du als Nächstes tun?")
                .font(AVENFont.body(13, weight: .semibold))
                .foregroundColor(AVENColor.textPrimary)

            HStack(spacing: 8) {
                AActionCard(
                    icon: "camera.viewfinder",
                    title: "Neue Profilanalyse",
                    subtitle: "Profil scannen"
                ) { container.showNewScan = true }

                AActionCard(
                    icon: "video.fill",
                    title: "Video analysieren",
                    subtitle: "Hook & CTA"
                ) { container.showCreationMenu = true }

                AActionCard(
                    icon: "person.fill.questionmark",
                    title: "AI Coach",
                    subtitle: "Frage stellen"
                ) { container.showCreationMenu = true }
            }
        }
    }
}

private struct AActionCard: View {
    let icon:     String
    let title:    String
    let subtitle: String
    let action:   () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AVENColor.accentPurple.opacity(0.09))
                        .frame(width: 30, height: 30)
                    Image(systemName: icon)
                        .font(.system(size: 13))
                        .foregroundColor(AVENColor.accentPurple)
                }
                Text(title)
                    .font(AVENFont.body(11, weight: .semibold))
                    .foregroundColor(AVENColor.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(AVENFont.body(9))
                    .foregroundColor(AVENColor.textMuted)
                Spacer(minLength: 0)
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AVENColor.accentPurple)
            }
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .aCard()
        }
        .buttonStyle(PressButtonStyle())
    }
}

// ─── No-data state ────────────────────────────────────────────────────────────

private struct ANoDataCard: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 36))
                .foregroundColor(AVENColor.textMuted)
            Text("Noch keine Analyse")
                .font(AVENFont.display(16))
                .foregroundColor(AVENColor.textPrimary)
            Text("Starte deine erste Profilanalyse, um hier deinen AVEN Score und deine Performance zu sehen.")
                .font(AVENFont.body(12))
                .foregroundColor(AVENColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .aCard()
    }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

private func formatK(_ n: Int) -> String {
    if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
    if n >= 1_000     { return String(format: "%.1fK", Double(n) / 1_000) }
    return "\(n)"
}

// ─── MiniLineChart ────────────────────────────────────────────────────────────
// Renders a score-history sparkline from real AnalyticsSnapshot data.
// Safe with < 2 points: shows empty state instead of crashing.

private struct MiniLineChart: View {
    let snapshots: [AnalyticsSnapshot]

    private var scores: [Double] { snapshots.map { Double($0.score) } }
    private var minS: Double { (scores.min() ?? 0) - 2 }
    private var maxS: Double { (scores.max() ?? 100) + 2 }

    var body: some View {
        GeometryReader { geo in
            if scores.count >= 2 {
                ZStack {
                    // Gradient fill under the line
                    LinearGradient(
                        colors: [AVENColor.accentPurple.opacity(0.18), AVENColor.accentPurple.opacity(0)],
                        startPoint: .top, endPoint: .bottom)
                    .mask(fillPath(in: geo.size))

                    // Line
                    linePath(in: geo.size)
                        .stroke(
                            LinearGradient(
                                colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                                startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))

                    // End dot
                    if let last = pt(scores.count - 1, geo.size) {
                        Circle()
                            .fill(AVENColor.accentBlue)
                            .frame(width: 5, height: 5)
                            .position(last)
                    }
                }
            } else {
                // Not enough data
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(AVENColor.textMuted)
                        .font(.system(size: 14))
                    Text("Mehr Analysen für Score-Verlauf")
                        .font(AVENFont.body(10))
                        .foregroundColor(AVENColor.textMuted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
    }

    private func pt(_ i: Int, _ s: CGSize) -> CGPoint? {
        guard scores.count > 1, i < scores.count else { return nil }
        let x = s.width  * CGFloat(i) / CGFloat(scores.count - 1)
        let y = s.height - s.height * CGFloat((scores[i] - minS) / (maxS - minS))
        return CGPoint(x: x, y: y)
    }

    private func linePath(in s: CGSize) -> Path {
        var p = Path()
        for i in 0..<scores.count {
            guard let point = pt(i, s) else { continue }
            if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
        }
        return p
    }

    private func fillPath(in s: CGSize) -> Path {
        var p = linePath(in: s)
        p.addLine(to: CGPoint(x: s.width, y: s.height))
        p.addLine(to: CGPoint(x: 0, y: s.height))
        p.closeSubpath()
        return p
    }
}

// ─── ViewModel (preserved exactly) ───────────────────────────────────────────

@MainActor
final class AnalyticsViewModel: ObservableObject {
    @Published var data: AnalyticsPeriodData?
    @Published var isLoading = false
    @Published var selectedPeriod: AnalyticsPeriod = .week

    private let service: AnalyticsServiceProtocol = StubAnalyticsService()

    init() {
        NotificationCenter.default.addObserver(
            forName: .analysisDidComplete, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { await self.load(period: self.selectedPeriod) }
        }
    }

    func load(period: AnalyticsPeriod) async {
        selectedPeriod = period
        isLoading = true
        data = nil
        do {
            let result = try await service.fetchData(period: period)
            withAnimation(AVENMotion.smooth) { data = result }
        } catch { }
        isLoading = false
    }
}

#Preview {
    AnalyticsView()
        .environmentObject(AppContainer.preview)
}
