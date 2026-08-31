import Foundation

// ─── Analytics data models ─────────────────────────────────────────────────────

struct AnalyticsSnapshot {
    let date:      Date
    let score:     Int
    let followers: Int
    let views:     Int
    let likes:     Int
}

struct AnalyticsPeriodData {
    let period:      AnalyticsPeriod
    let snapshots:   [AnalyticsSnapshot]
    let currentScore:      Int
    let scoreChange:       Int        // points delta vs oldest in period
    let followers:         Int
    let followersChange:   Double     // % — 0 if no real history
    let views:             Int
    let viewsChange:       Double
    let likes:             Int
    let likesChange:       Double
    let engagement:        Double     // %
    let engagementChange:  Double
    let strongestMetric:   String
    let weakestMetric:     String
    let insight:           String
    let hasRealHistory:    Bool       // true = drawn from real analyses
}

enum AnalyticsPeriod: String, CaseIterable {
    case week  = "7T"
    case month = "30T"
    case quarter = "90T"
    var days: Int { self == .week ? 7 : self == .month ? 30 : 90 }
}

// ─── Analytics service protocol ───────────────────────────────────────────────

protocol AnalyticsServiceProtocol {
    func fetchData(period: AnalyticsPeriod) async throws -> AnalyticsPeriodData
}

// ─── Real + stub implementation ───────────────────────────────────────────────
// Primary source: AVENAnalysisStore.loadHistory() — one entry per real analysis.
// Fallback (no history yet): shows current score as single point + clear messaging.
// TikTok stats from AppContainer when available — never fabricated growth curves.

final class StubAnalyticsService: AnalyticsServiceProtocol {
    func fetchData(period: AnalyticsPeriod) async throws -> AnalyticsPeriodData {
        try await Task.sleep(nanoseconds: 300_000_000)

        let currentScore = AVENAnalysisStore.currentScore

        // ── Real score history ────────────────────────────────────────────────
        let history = AVENAnalysisStore.loadHistory()
        let cutoff  = Calendar.current.date(byAdding: .day, value: -period.days, to: Date()) ?? Date()
        let inPeriod = history.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }

        // ── Real TikTok stats ─────────────────────────────────────────────────
        struct StoredAccount: Decodable {
            let followers: Int; let likes: Int
        }
        let realAccount: StoredAccount? = {
            guard let data = UserDefaults.standard.data(forKey: "aven.connectedTikTokAccount"),
                  let a = try? JSONDecoder().decode(StoredAccount.self, from: data) else { return nil }
            return a
        }()

        let finalFollowers = realAccount?.followers ?? 0
        let finalLikes     = realAccount?.likes     ?? 0
        let hasRealAccount = realAccount != nil

        // ── Build snapshots from REAL history ─────────────────────────────────
        let snapshots: [AnalyticsSnapshot]
        let hasRealHistory: Bool

        if inPeriod.count >= 2 {
            // Multiple analyses in this period → draw the real curve
            snapshots = inPeriod.map { entry in
                AnalyticsSnapshot(
                    date:      entry.date,
                    score:     entry.score,
                    followers: finalFollowers,   // same point in time (no historical follower data yet)
                    views:     0,
                    likes:     finalLikes
                )
            }
            hasRealHistory = true
        } else if inPeriod.count == 1 || !history.isEmpty {
            // One analysis (inside or outside this period) → single point
            let entry = inPeriod.first ?? history.last!
            snapshots = [AnalyticsSnapshot(
                date:      entry.date,
                score:     entry.score,
                followers: finalFollowers,
                views:     0,
                likes:     finalLikes
            )]
            hasRealHistory = true
        } else {
            // No analysis at all yet
            snapshots = [AnalyticsSnapshot(
                date:      Date(),
                score:     currentScore,
                followers: finalFollowers,
                views:     0,
                likes:     finalLikes
            )]
            hasRealHistory = false
        }

        // ── Score change ──────────────────────────────────────────────────────
        let firstScore = inPeriod.first?.score ?? currentScore
        let scoreChange = currentScore - firstScore

        // ── Follower / likes changes — only meaningful with real historical data ──
        // We don't fabricate growth curves. If no real before/after data: show 0.
        let fChange: Double = 0    // no per-snapshot follower history yet
        let vChange: Double = 0    // views not available from user.info.basic
        let lChange: Double = 0    // no per-snapshot likes history yet
        let eng: Double = 0

        // ── Insight — driven by real data ──────────────────────────────────────
        let insight: String
        if !hasRealHistory {
            insight = "Analysiere dein Profil, um hier deinen Score-Verlauf zu sehen."
        } else if inPeriod.count >= 2 {
            if scoreChange > 0 {
                insight = "Dein AVEN Score hat sich in diesem Zeitraum um \(scoreChange) Punkte verbessert. Weiter so!"
            } else if scoreChange < 0 {
                insight = "Dein AVEN Score hat sich um \(abs(scoreChange)) Punkte verändert. Erledige offene Aktionsplan-Aufgaben, um ihn wieder zu steigern."
            } else {
                insight = "Dein AVEN Score ist stabil. Erledige Aktionsplan-Aufgaben für den nächsten Fortschritt."
            }
        } else {
            // Single analysis
            let status = currentScore >= 90 ? "hervorragend" : currentScore >= 80 ? "stark" : currentScore >= 65 ? "gut" : "ausbaufähig"
            if hasRealAccount {
                insight = "Erste Analyse abgeschlossen. Score: \(currentScore) (\(status)). Verbinde deinen TikTok-Account regelmäßig und führe weitere Analysen durch, um deinen Verlauf zu sehen."
            } else {
                insight = "Erste Analyse abgeschlossen. Score: \(currentScore) (\(status)). Führe weitere Analysen durch, um deinen Score-Verlauf zu sehen."
            }
        }

        // ── Strongest/weakest — only real dimensions ──────────────────────────
        let dims = AVENAnalysisStore.load()?.dimensions ?? []
        let sortedDims = dims.filter { $0.score >= 0 }.sorted { $0.score < $1.score }
        let weakest  = sortedDims.first?.name   ?? "Noch keine Daten"
        let strongest = sortedDims.last?.name   ?? "Noch keine Daten"

        return AnalyticsPeriodData(
            period:           period,
            snapshots:        snapshots,
            currentScore:     currentScore,
            scoreChange:      scoreChange,
            followers:        finalFollowers,
            followersChange:  fChange,
            views:            0,
            viewsChange:      vChange,
            likes:            finalLikes,
            likesChange:      lChange,
            engagement:       eng,
            engagementChange: 0,
            strongestMetric:  strongest,
            weakestMetric:    weakest,
            insight:          insight,
            hasRealHistory:   hasRealHistory
        )
    }
}
