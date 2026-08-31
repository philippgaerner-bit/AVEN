import Foundation
import Combine

// ─── HomeViewModel ────────────────────────────────────────────────────────────
// All business logic for the Homescreen lives here.
// Views are dumb — they only read @Published state and call methods.

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var state: HomeViewState = .empty

    private let apiClient: AVENAPIClient

    init(apiClient: AVENAPIClient) {
        self.apiClient = apiClient
        // Refresh home data whenever an analysis completes (score + metrics update)
        NotificationCenter.default.addObserver(
            forName: .analysisDidComplete,
            object:  nil,
            queue:   .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.load() }
        }
    }

    // ── Actions ───────────────────────────────────────────────────────────────

    func load() async {
        state.isLoading = true
        state.error     = nil
        do {
            let data  = try await apiClient.getHomeData(period: state.period)
            state     = Self.map(data: data, period: state.period)
        } catch {
            state.isLoading = false
            state.error = "Daten konnten nicht geladen werden."
        }
    }

    func selectPeriod(_ period: HomeViewState.Period) {
        state.period = period
        Task { await load() }
    }

    // ── Mapping (static → testable without MainActor) ─────────────────────────

    static func map(data: HomeData, period: HomeViewState.Period) -> HomeViewState {
        let profile  = mapProfile(data.profile)
        let metrics  = mapMetrics(data.metrics)
        let score    = mapScore(data.score)
        let actions  = mapActions(data.actions)

        return HomeViewState(
            profile:   profile,
            metrics:   metrics,
            score:     score,
            actions:   actions,
            period:    period,
            isLoading: false,
            error:     nil
        )
    }

    static func mapProfile(_ p: ProfileData) -> ConnectedProfile {
        let platform: ConnectedProfile.SocialPlatform = p.platform == "instagram" ? .instagram : .tiktok
        return ConnectedProfile(
            id:          p.id,
            platform:    platform,
            username:    p.username,
            displayName: p.displayName,
            avatarURL:   p.avatarURL.flatMap { URL(string: $0) }
        )
    }

    static func mapMetrics(_ m: MetricsData) -> [ProfileMetric] {
        [
            ProfileMetric(label: "Follower", value: formatCount(m.followers),
                          change: formatChange(m.followersChange), isPositive: m.followersChange >= 0),
            ProfileMetric(label: "Views",    value: formatCount(m.views),
                          change: formatChange(m.viewsChange),     isPositive: m.viewsChange >= 0),
            ProfileMetric(label: "Likes",    value: formatCount(m.likes),
                          change: formatChange(m.likesChange),     isPositive: m.likesChange >= 0),
        ]
    }

    static func mapScore(_ s: ScoreData) -> AVENScore {
        let status: String
        let explanation: String
        switch s.total {
        case 80...100:
            status = "Stark";        explanation = "Dein Profil ist sehr gut aufgestellt."
        case 60...79:
            status = "Gut";          explanation = "Solide Basis mit klaren Wachstumshebeln."
        case 40...59:
            status = "Verbesserbar"; explanation = "Grundlegende Probleme begrenzen dein Wachstum."
        default:
            status = "Kritisch";     explanation = "Wichtige Fundament-Issues blockieren den Rest."
        }
        let dims = s.dimensions.map {
            ScoreDimension(name: $0.name, value: $0.value, detail: $0.detail, tip: $0.tip)
        }
        return AVENScore(total: s.total, status: status, explanation: explanation,
                         trend: .stable, dimensions: dims)
    }

    static func mapActions(_ raw: [ActionData]) -> [GrowthActionItem] {
        raw
            .filter { !$0.isBlocked || $0.severity != "polish" }
            .sorted { $0.priority < $1.priority }
            .map { a in
                let sev: GrowthActionItem.Severity = {
                    switch a.severity {
                    case "foundation": return .foundation
                    case "lever":      return .lever
                    default:           return .polish
                    }
                }()
                return GrowthActionItem(
                    id: a.id, title: a.title, category: a.category,
                    impact: a.impact, priority: a.priority,
                    severity: sev, isBlocked: a.isBlocked
                )
            }
    }

    // ── Formatting helpers ────────────────────────────────────────────────────

    static func formatCount(_ n: Int) -> String {
        switch n {
        case 1_000_000...: return String(format: "%.1fM", Double(n) / 1_000_000)
        case 1_000...:     return String(format: "%.1fK", Double(n) / 1_000)
        default:           return "\(n)"
        }
    }

    static func formatChange(_ pct: Double) -> String {
        let sign = pct >= 0 ? "+" : ""
        return String(format: "%@%.1f%%", sign, pct)
    }

    static func scoreStatus(for total: Int) -> String {
        switch total {
        case 80...100: return "Stark"
        case 60...79:  return "Gut"
        case 40...59:  return "Verbesserbar"
        default:       return "Kritisch"
        }
    }
}
