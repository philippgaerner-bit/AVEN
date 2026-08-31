import Foundation
import UIKit

// ─── Domain models (UI layer) ─────────────────────────────────────────────────

struct ConnectedProfile {
    let id:          String
    let platform:    SocialPlatform
    let username:    String
    let displayName: String
    let avatarURL:   URL?

    enum SocialPlatform: String, CaseIterable {
        case tiktok    = "TikTok"
        case instagram = "Instagram"
    }
}

struct ProfileMetric: Identifiable {
    let id    = UUID()
    let label:      String
    let value:      String
    let change:     String
    let isPositive: Bool
}

struct AVENScore {
    let total:       Int
    let status:      String
    let explanation: String
    let trend:       Trend
    /// Real per-dimension scores derived from analysis. Nil = not enough data.
    let dimensions:  [ScoreDimension]

    init(total: Int, status: String, explanation: String, trend: Trend, dimensions: [ScoreDimension] = []) {
        self.total = total; self.status = status
        self.explanation = explanation; self.trend = trend
        self.dimensions = dimensions
    }

    enum Trend { case up, down, stable }

    var statusColor: String {
        switch total {
        case 80...100: return "positive"
        case 50...79:  return "neutral"
        default:       return "negative"
        }
    }
}

struct ScoreDimension: Identifiable {
    let id       = UUID()
    let name:    String
    let value:   Int          // 0–100; –1 = not measurable from available data
    let detail:  String       // what drives this dimension
    let tip:     String       // concrete improvement step

    var isMeasurable: Bool { value >= 0 }
}

struct GrowthActionItem: Identifiable {
    let id:          String
    let title:       String
    let category:    String
    let impact:      Int
    let priority:    Int
    let severity:    Severity
    let isBlocked:   Bool
    /// True = task needs a screenshot/proof before it can be marked complete.
    var requiresProof: Bool = false
    /// Locked behind AVEN Pro. Free users see title/category/points but not details.
    var isProLocked: Bool   = false
    var isCompleted: Bool   = false
    var detail:      String = ""

    enum Severity: String {
        case foundation, lever, polish
        var label: String {
            switch self {
            case .foundation: return "Foundation"
            case .lever:      return "Lever"
            case .polish:     return "Polish"
            }
        }
    }
    var impactLabel: String { "+\(impact) pts" }
}

struct HomeViewState {
    var profile:   ConnectedProfile?
    var metrics:   [ProfileMetric]
    var score:     AVENScore?
    var actions:   [GrowthActionItem]
    var period:    Period
    var isLoading: Bool
    var error:     String?

    enum Period: String, CaseIterable {
        case today = "1T"
        case week  = "7T"
        case month = "1M"
    }

    static var empty: HomeViewState {
        HomeViewState(profile: nil, metrics: [], score: nil,
                      actions: [], period: .week, isLoading: false, error: nil)
    }
}

// ─── Account goal ─────────────────────────────────────────────────────────────

enum AccountGoal: String, CaseIterable, Codable {
    case creator       = "creator"
    case business      = "business"
    case personalBrand = "personalBrand"
    case improveProfile = "improveProfile"

    var displayName: String {
        switch self {
        case .creator:        return "Creator werden & Reichweite aufbauen"
        case .business:       return "Business / Produkte vermarkten"
        case .personalBrand:  return "Personal Brand aufbauen"
        case .improveProfile: return "Profil & Videos verbessern"
        }
    }

    var shortName: String {
        switch self {
        case .creator:        return "Creator"
        case .business:       return "Business"
        case .personalBrand:  return "Personal Brand"
        case .improveProfile: return "Profil verbessern"
        }
    }

    var icon: String {
        switch self {
        case .creator:        return "star.fill"
        case .business:       return "bag.fill"
        case .personalBrand:  return "person.crop.circle.badge.checkmark"
        case .improveProfile: return "sparkles"
        }
    }

    /// Whether a missing CTA/Link should be penalised for this goal
    var requiresCTA: Bool { self == .business || self == .creator }
    /// Whether conversion-focused bio matters
    var conversionFocused: Bool { self == .business }
}

enum AVENGoalStore {
    private static let key = "aven.accountGoal"

    static var current: AccountGoal {
        get {
            guard let raw = UserDefaults.standard.string(forKey: key),
                  let goal = AccountGoal(rawValue: raw) else { return .creator }
            return goal
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }
}

// ─── Cross-feature notifications ──────────────────────────────────────────────
extension Notification.Name {
    /// Posted by AVENAnalysisStore.save() after every completed analysis.
    /// Receivers: HomeViewModel (refresh score), ActionPlanViewModel (rebuild plan).
    static let analysisDidComplete = Notification.Name("aven.analysisDidComplete")
}

// ─── Central analysis store ───────────────────────────────────────────────────
// Single source of truth for the most recent analysis result.
// Written by ProfileImageAnalyzer after every scan.
// Read by Home, Analytics, ActionPlan, Coach.

struct AnalysisDimension: Codable {
    let name:    String
    let score:   Int       // 0–100; -1 = unmeasurable
    let positives: [String]
    let negatives: [String]
    let tip:     String
}

struct AnalysisRecord: Codable {
    let analysisScore:  Int          // AVEN total from analysis
    let status:         String
    let strengths:      [String]
    let weaknesses:     [String]
    let dimensions:     [AnalysisDimension]
    let taskIDs:        [String]     // ordered task IDs derived from this analysis
    let platform:       String
    let timestamp:      Date

    // Derived total = average of measurable dimensions
    var computedTotal: Int {
        let measurable = dimensions.filter { $0.score >= 0 }
        guard !measurable.isEmpty else { return analysisScore }
        return measurable.map(\.score).reduce(0, +) / measurable.count
    }
}

enum AVENAnalysisStore {
    private static let key        = "aven.lastAnalysis"
    private static let scoreKey   = "aven.avenScore.total"
    private static let historyKey = "aven.scoreHistory"
    private static let doneKey    = "aven.hasCompletedAnalysis"

    static func save(_ record: AnalysisRecord) {
        if let data = try? JSONEncoder().encode(record) {
            UserDefaults.standard.set(data, forKey: key)
        }
        // Use analysisScore directly — this is the weighted score the user sees.
        // Do NOT use computedTotal (simple dimension average) which can differ.
        let score = min(100, max(0, record.analysisScore))
        UserDefaults.standard.set(score, forKey: scoreKey)
        UserDefaults.standard.set(true,  forKey: doneKey)
        // Append to history
        var history = loadHistory()
        history.append(ScoreHistoryEntry(score: score, date: record.timestamp,
                                          reason: record.weaknesses.first))
        if history.count > 365 { history = Array(history.suffix(365)) }
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
        // Notify all listeners immediately
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .analysisDidComplete, object: nil)
            // If new analysis is below 100, reset celebration so it can fire again if 100 is reached
            if record.analysisScore < 100 {
                UserDefaults.standard.removeObject(forKey: "aven.celebration.shown.v1")
            }
        }
    }

    static func load() -> AnalysisRecord? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(AnalysisRecord.self, from: data)
    }

    static var currentScore: Int {
        let v = UserDefaults.standard.integer(forKey: scoreKey)
        return v == 0 ? 30 : v
    }

    static var hasCompletedAnalysis: Bool {
        UserDefaults.standard.bool(forKey: doneKey)
    }

    /// Add or subtract task-completion points, clamped to 20…100
    static func applyTaskDelta(_ delta: Int) {
        let current = currentScore
        let newScore = min(100, max(20, current + delta))
        UserDefaults.standard.set(newScore, forKey: scoreKey)
    }

    static func loadHistory() -> [ScoreHistoryEntry] {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let entries = try? JSONDecoder().decode([ScoreHistoryEntry].self, from: data)
        else { return [] }
        return entries
    }
}

struct ScoreHistoryEntry: Codable, Identifiable {
    var id: Date { date }
    let score:  Int
    let date:   Date
    let reason: String?   // first weakness from that analysis, or nil
}



enum ScanFlowState {
    case idle
    case imagePicked(UIImage)
    case analyzing
    case result(ScanAnalysisResult)
    case failed(String)
}

struct ScanAnalysisResult {
    let score:          Int
    let status:         String
    let strengths:      [String]
    let weaknesses:     [String]
    let suggestions:    [ScanSuggestion]   // feeds Action Plan; not shown in result UI
    let platform:       ConnectedProfile.SocialPlatform
    let recommendedBio: String             // profile-specific optimized bio
    let bioIsStrong:    Bool               // true = existing bio already good
}

struct ScanSuggestion: Identifiable {
    let id      = UUID()
    let title:    String
    let detail:   String
    let impact:   Int
    let category: String
}

// ─── Plan / Paywall models ────────────────────────────────────────────────────

enum AVENPlan: String, CaseIterable {
    case free    = "FREE"
    case pro     = "PRO"
    case proPlus = "PRO+"

    var displayName: String { rawValue }

    var monthlyPrice: String {
        switch self {
        case .free:    return "Kostenlos"
        case .pro:     return "€9,99 / Monat"
        case .proPlus: return "€24,99 / Monat"
        }
    }

    /// Monthly KI-Video GENERATION seconds. 0 = not available on this plan.
    /// Video-Analyse is unlimited and not tracked here.
    var videoMonthlyLimit: Int {
        switch self {
        case .free:    return 0
        case .pro:     return 10
        case .proPlus: return 30
        }
    }

    /// Monthly KI-Coach question limit. 0 = feature not available on this plan.
    var coachMonthlyLimit: Int {
        switch self {
        case .free:    return 0
        case .pro:     return 0
        case .proPlus: return 100
        }
    }

    var hasCoachAccess: Bool { coachMonthlyLimit > 0 }

    var features: [PlanFeature] {
        switch self {
        case .free:
            return [
                PlanFeature("3 Profilanalysen / Monat",      included: true),
                PlanFeature("AVEN Score",                    included: true),
                PlanFeature("Top 3 Findings",               included: true),
                PlanFeature("Vollstaendige Findings",        included: false),
                PlanFeature("Aktionsplan",                   included: false),
                PlanFeature("Videoanalyse",                  included: false),
                PlanFeature("Video-Blueprint",               included: false),
                PlanFeature("KI-Coach",                      included: false),
            ]
        case .pro:
            return [
                PlanFeature("30 Profilanalysen / Monat",     included: true),
                PlanFeature("10 Videoanalysen / Monat",      included: true),
                PlanFeature("50 Video-Blueprints / Monat",   included: true),
                PlanFeature("AVEN Score",                    included: true),
                PlanFeature("Vollstaendige Findings",        included: true),
                PlanFeature("Aktionsplan",                   included: true),
                PlanFeature("KI-Empfehlungen",               included: true),
                PlanFeature("Bio-Generator",                 included: true),
                PlanFeature("KI-Coach",                      included: false),
            ]
        case .proPlus:
            return [
                PlanFeature("100 Profilanalysen / Monat",    included: true),
                PlanFeature("20 Videoanalysen / Monat",      included: true),
                PlanFeature("100 Video-Blueprints / Monat",  included: true),
                PlanFeature("100 KI-Coach-Fragen / Monat",  included: true),
                PlanFeature("AVEN Score",                    included: true),
                PlanFeature("Vollstaendige Findings",        included: true),
                PlanFeature("Aktionsplan",                   included: true),
                PlanFeature("Alle Premium-Funktionen",       included: true),
            ]
        }
    }
}

struct PlanFeature: Identifiable {
    let id      = UUID()
    let title:    String
    let included: Bool
    init(_ title: String, included: Bool) {
        self.title    = title
        self.included = included
    }
}
