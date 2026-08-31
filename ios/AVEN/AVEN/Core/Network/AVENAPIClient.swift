import Foundation

// ─── AVEN API client protocol ─────────────────────────────────────────────────

protocol AVENAPIClient {
    func getHomeData(period: HomeViewState.Period) async throws -> HomeData
}

// ─── Home data bundle ─────────────────────────────────────────────────────────

struct HomeData {
    let profile:   ProfileData
    let metrics:   MetricsData
    let score:     ScoreData
    let actions:   [ActionData]
}

struct ProfileData {
    let id:          String
    let platform:    String
    let username:    String
    let displayName: String
    let avatarURL:   String?
}

struct MetricsData {
    let followers:       Int;   let followersChange:  Double
    let views:           Int;   let viewsChange:      Double
    let likes:           Int;   let likesChange:      Double
}

struct ScoreData {
    let total:       Int
    let displayable: Bool
    let coverage:    Double
    let findings:    [FindingData]
    /// Per-dimension breakdown derived from analysis signals.
    /// value –1 means "not measurable from available data"
    let dimensions:  [DimensionData]
}

struct DimensionData {
    let name:   String
    let value:  Int     // 0–100 or –1 = unmeasurable
    let detail: String
    let tip:    String
}

struct FindingData {
    let templateId:          String
    let severity:            String
    let impact:              Int
    let priority:            Int
    let blockedByFoundation: Bool
    let title:               String
}

struct ActionData {
    let id:         String
    let title:      String
    let category:   String
    let impact:     Int
    let priority:   Int
    let severity:   String
    let isBlocked:  Bool
}

// ─── Stub client ──────────────────────────────────────────────────────────────
// MARK: - Integration Point: replace StubAVENAPIClient with RealAVENAPIClient
// that calls the AVEN backend with the period param:
//   GET /home?period=1d | 7d | 30d

final class StubAVENAPIClient: AVENAPIClient {

    func getHomeData(period: HomeViewState.Period) async throws -> HomeData {
        try await Task.sleep(nanoseconds: 300_000_000)

        let currentScore = AVENAnalysisStore.currentScore

        // Read real connected TikTok account if available
        struct StoredAccount: Decodable {
            let followers: Int; let following: Int; let likes: Int; let videoCount: Int
        }
        let real: StoredAccount? = {
            guard let data = UserDefaults.standard.data(forKey: "aven.connectedTikTokAccount"),
                  let a = try? JSONDecoder().decode(StoredAccount.self, from: data) else { return nil }
            return a
        }()

        // Period-specific metrics — use real follower count if connected, else demo
        let baseFollowers = real?.followers ?? 24_800
        let baseLikes     = real?.likes     ?? 45_200
        let metrics: MetricsData = {
            switch period {
            case .today:
                return MetricsData(
                    followers: baseFollowers, followersChange: real != nil ? 0 : 0.3,
                    views:     real != nil ? 0 : 8400,  viewsChange: real != nil ? 0 : 4.1,
                    likes:     baseLikes,                likesChange: real != nil ? 0 : -0.8
                )
            case .week:
                return MetricsData(
                    followers: baseFollowers, followersChange: real != nil ? 0 : 3.2,
                    views:     real != nil ? 0 : 58600, viewsChange: real != nil ? 0 : 12.7,
                    likes:     baseLikes,                likesChange: real != nil ? 0 : -1.4
                )
            case .month:
                return MetricsData(
                    followers: baseFollowers, followersChange: real != nil ? 0 : 11.6,
                    views:     real != nil ? 0 : 198000, viewsChange: real != nil ? 0 : 34.2,
                    likes:     baseLikes,                 likesChange: real != nil ? 0 : 8.9
                )
            }
        }()

        // Build score dimensions and actions from last real analysis if available
        let record = AVENAnalysisStore.load()

        let dimensions: [DimensionData] = record?.dimensions.map {
            DimensionData(name: $0.name, value: $0.score,
                          detail: ($0.negatives.first ?? $0.positives.first ?? $0.tip),
                          tip: $0.tip)
        } ?? [
            DimensionData(name: "Profil & Bio",    value: -1,
                          detail: "Noch keine Analyse durchgeführt.",
                          tip: "Lade einen Profil-Screenshot hoch um diesen Bereich zu bewerten."),
            DimensionData(name: "Video-Einstieg",   value: -1,
                          detail: "Erfordert Video-Daten.",
                          tip: "Starte Videos mit einer Frage oder Überraschung in den ersten 2 Sek."),
            DimensionData(name: "Interaktionen",      value: -1,
                          detail: "Noch nicht bewertet – TikTok-Account verbinden.",
                          tip: "Stelle am Videoende eine konkrete Frage an deine Zuschauer."),
        ]

        // Actions: read from the SAME source as ActionPlanView (no stale/stub tasks)
        // Open tasks = the real gap-to-perfect-profile tasks that are not yet completed
        let actions: [ActionData]
        if let rec = record, AVENAnalysisStore.hasCompletedAnalysis {
            let goal = AVENGoalStore.current
            let allTasks = await MainActor.run {
                ActionPlanViewModel.buildFromAnalysis(
                    record: rec, goal: goal, isProUser: true, freeLimit: 99)
            }
            let openTasks = allTasks.filter { !$0.isCompleted && !$0.isProLocked && $0.category != "info" }
            actions = openTasks.prefix(3).map { task in
                ActionData(
                    id:       task.id,
                    title:    task.title,
                    category: task.category,
                    impact:   task.impact,
                    priority: task.priority,
                    severity: task.severity.rawValue,
                    isBlocked: task.isBlocked
                )
            }
        } else {
            actions = []   // no analysis yet → Home shows no stub tasks
        }

        return HomeData(
            profile: ProfileData(
                id: "p1", platform: "tiktok",
                username: "@avencreator", displayName: "AVEN Creator", avatarURL: nil
            ),
            metrics: metrics,
            score: ScoreData(
                total: currentScore, displayable: true, coverage: record != nil ? 0.95 : 0.5,
                findings: [],
                dimensions: dimensions
            ),
            actions: actions
        )
    }
}
