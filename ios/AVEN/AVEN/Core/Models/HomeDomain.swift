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
    var xpReward: Int { impact <= 0 ? 0 : (impact >= 15 ? min(100, impact) : max(15, min(80, impact * 5))) }
    var impactLabel: String { "+\(xpReward) XP" }
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
    static let aiActionPlanDidUpdate = Notification.Name("aven.aiActionPlanDidUpdate")
    static let goalDidUpdate = Notification.Name("aven.goalDidUpdate")
    static let xpDidUpdate = Notification.Name("aven.xpDidUpdate")
    static let growthMissionDidUpdate = Notification.Name("aven.growthMissionDidUpdate")
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

    /// Replaces the latest record after AI rewrites the wording. This does not
    /// create a second score-history entry; the local Vision score stays unchanged.
    static func replaceCurrent(_ record: AnalysisRecord) {
        if let data = try? JSONEncoder().encode(record) {
            UserDefaults.standard.set(data, forKey: key)
        }
        UserDefaults.standard.set(min(100, max(0, record.analysisScore)), forKey: scoreKey)
        UserDefaults.standard.set(true, forKey: doneKey)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .analysisDidComplete, object: nil)
        }
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


// ─── User growth goal (shared by onboarding, goal sheet and profile) ──────────

struct AVENUserGrowthGoal: Equatable {
    let type: String
    let current: String
    let target: String
    let deadline: String

    var title: String {
        switch type.lowercased() {
        case "follower", "followers": return "Mehr Follower"
        case "views": return "Mehr Views"
        case "likes": return "Mehr Likes"
        case "engagement": return "Mehr Engagement"
        case "posts/woche", "posting": return "Regelmäßiger posten"
        case "aven score", "professional": return "Account professioneller"
        default: return type.isEmpty ? "Wachstumsziel" : type
        }
    }

    var icon: String {
        switch type.lowercased() {
        case "follower", "followers": return "person.2.fill"
        case "views": return "eye.fill"
        case "likes", "engagement": return "heart.fill"
        case "posts/woche", "posting": return "calendar.badge.plus"
        case "aven score", "professional": return "sparkles"
        default: return "target"
        }
    }

    var unit: String {
        switch type.lowercased() {
        case "follower", "followers": return "Follower"
        case "views": return "Views"
        case "likes": return "Likes"
        case "engagement": return "% Engagement"
        case "posts/woche", "posting": return "Posts/Woche"
        case "aven score", "professional": return "AVEN Score"
        default: return type
        }
    }
}

enum AVENUserGoalStore {
    static var current: AVENUserGrowthGoal? {
        let primary = UserDefaults.standard.string(forKey: "aven.onboarding.primaryGoal") ?? ""
        let target = UserDefaults.standard.string(forKey: "aven.onboarding.goalTarget") ?? ""
        let deadline = UserDefaults.standard.string(forKey: "aven.onboarding.goalDeadline") ?? ""

        if !target.isEmpty {
            let storageType: String
            switch primary.lowercased() {
            case "followers": storageType = "Follower"
            case "views": storageType = "Views"
            case "engagement": storageType = "Engagement"
            case "posting": storageType = "Posts/Woche"
            case "professional": storageType = "AVEN Score"
            default: storageType = primary
            }
            let latest = latestEntry(matching: storageType)
            return AVENUserGrowthGoal(
                type: storageType,
                current: latest?["current"] ?? "",
                target: target,
                deadline: deadline.isEmpty ? (latest?["deadline"] ?? "") : deadline
            )
        }

        guard let latest = latestEntry(matching: nil),
              let type = latest["type"],
              let target = latest["target"],
              !target.isEmpty else { return nil }
        return AVENUserGrowthGoal(
            type: type,
            current: latest["current"] ?? "",
            target: target,
            deadline: latest["deadline"] ?? ""
        )
    }

    static func save(type: String, current: String, target: String, deadline: String) {
        let entry: [String: String] = [
            "type": type,
            "current": current,
            "target": target,
            "deadline": deadline,
            "date": ISO8601DateFormatter().string(from: Date())
        ]
        var all = (UserDefaults.standard.array(forKey: "aven.goals.v2") as? [[String: String]]) ?? []
        all.removeAll { ($0["type"] ?? "").caseInsensitiveCompare(type) == .orderedSame }
        all.append(entry)
        UserDefaults.standard.set(all, forKey: "aven.goals.v2")

        let primary: String
        switch type.lowercased() {
        case "follower": primary = "followers"
        case "views": primary = "views"
        case "engagement": primary = "engagement"
        case "posts/woche": primary = "posting"
        case "aven score": primary = "professional"
        case "likes": primary = "likes"
        default: primary = type.lowercased()
        }
        UserDefaults.standard.set(primary, forKey: "aven.onboarding.primaryGoal")
        UserDefaults.standard.set(target, forKey: "aven.onboarding.goalTarget")
        UserDefaults.standard.set(deadline, forKey: "aven.onboarding.goalDeadline")
        NotificationCenter.default.post(name: .goalDidUpdate, object: nil)
    }

    private static func latestEntry(matching type: String?) -> [String: String]? {
        let all = (UserDefaults.standard.array(forKey: "aven.goals.v2") as? [[String: String]]) ?? []
        let filtered: [[String: String]]
        if let type, !type.isEmpty {
            filtered = all.filter { ($0["type"] ?? "").caseInsensitiveCompare(type) == .orderedSame }
        } else {
            filtered = all
        }
        return filtered.max { a, b in (a["date"] ?? "") < (b["date"] ?? "") }
    }
}

// ─── XP / Levels / Milestones ────────────────────────────────────────────────

struct AVENXPMilestone: Identifiable {
    let xp: Int
    let title: String
    let icon: String
    var id: Int { xp }
}

struct AVENFollowerMilestone: Identifiable {
    let followers: Int
    let rewardXP: Int
    let title: String
    var id: Int { followers }
}

enum AVENXPStore {
    private static let xpKey = "aven.xp.total.v2"
    private static let grantsKey = "aven.xp.grants.v2"

    static let levelThresholds: [Int] = [0, 100, 250, 450, 700, 1000, 1400, 1850, 2350, 3000]
    static let milestones: [AVENXPMilestone] = [
        .init(xp: 100, title: "Erster Schritt", icon: "sparkles"),
        .init(xp: 300, title: "Momentum", icon: "bolt.fill"),
        .init(xp: 600, title: "Growth Streak", icon: "flame.fill"),
        .init(xp: 1000, title: "Creator Fokus", icon: "target"),
        .init(xp: 1400, title: "Growth Pro", icon: "star.fill"),
        .init(xp: 2000, title: "AVEN Elite", icon: "crown.fill")
    ]

    static let followerMilestones: [AVENFollowerMilestone] = [
        .init(followers: 100, rewardXP: 40, title: "100 Follower"),
        .init(followers: 500, rewardXP: 60, title: "500 Follower"),
        .init(followers: 1000, rewardXP: 100, title: "1K Follower"),
        .init(followers: 5000, rewardXP: 150, title: "5K Follower"),
        .init(followers: 10000, rewardXP: 200, title: "10K Follower"),
        .init(followers: 50000, rewardXP: 350, title: "50K Follower")
    ]

    static var totalXP: Int { UserDefaults.standard.integer(forKey: xpKey) }

    static var level: Int {
        let xp = totalXP
        let idx = levelThresholds.lastIndex(where: { xp >= $0 }) ?? 0
        return idx + 1
    }

    static var currentLevelStart: Int {
        levelThresholds[min(max(level - 1, 0), levelThresholds.count - 1)]
    }

    static var nextLevelXP: Int {
        let index = level
        if index < levelThresholds.count { return levelThresholds[index] }
        return currentLevelStart + 750
    }

    static var levelProgress: Double {
        let start = currentLevelStart
        let end = nextLevelXP
        guard end > start else { return 1 }
        return min(1, max(0, Double(totalXP - start) / Double(end - start)))
    }

    static var xpToNextLevel: Int { max(0, nextLevelXP - totalXP) }

    @discardableResult
    static func grantOnce(key: String, amount: Int) -> Bool {
        guard amount > 0 else { return false }
        var grants = Set(UserDefaults.standard.stringArray(forKey: grantsKey) ?? [])
        guard !grants.contains(key) else { return false }
        grants.insert(key)
        UserDefaults.standard.set(Array(grants).sorted(), forKey: grantsKey)
        UserDefaults.standard.set(totalXP + amount, forKey: xpKey)
        NotificationCenter.default.post(name: .xpDidUpdate, object: nil)
        return true
    }

    static func syncFollowerMilestones(followers: Int) {
        guard followers > 0 else { return }
        for milestone in followerMilestones where followers >= milestone.followers {
            _ = grantOnce(key: "followers.\(milestone.followers)", amount: milestone.rewardXP)
        }
    }

    static func nextFollowerMilestone(after followers: Int) -> AVENFollowerMilestone? {
        followerMilestones.first { followers < $0.followers }
    }
}

// ─── Measurable Growth Challenges ────────────────────────────────────────────
// Short, escalating goals based only on real synced TikTok counters.

enum AVENGrowthMissionMetric: String, Codable {
    case followers
    case likes

    var title: String { self == .followers ? "Follower" : "Likes" }
    var icon: String { self == .followers ? "person.2.fill" : "heart.fill" }
}

struct AVENGrowthMission: Codable, Equatable, Identifiable {
    let id: String
    let metric: AVENGrowthMissionMetric
    let baseline: Int
    let target: Int
    let stage: Int
    let rewardXP: Int
    let createdAt: Date
    let durationDays: Int
    var completedAt: Date?

    var delta: Int { max(0, target - baseline) }
    var title: String { "+\(delta) \(metric.title) erreichen" }

    func currentValue(account: ConnectedTikTokAccount) -> Int {
        metric == .followers ? account.followers : account.likes
    }

    func progress(account: ConnectedTikTokAccount) -> Double {
        let value = currentValue(account: account)
        guard target > baseline else { return 1 }
        return min(1, max(0, Double(value - baseline) / Double(target - baseline)))
    }

    var daysRemaining: Int {
        let end = Calendar.current.date(byAdding: .day, value: durationDays, to: createdAt) ?? createdAt
        return max(0, Calendar.current.dateComponents([.day], from: Date(), to: end).day ?? 0)
    }
}

enum AVENGrowthMissionStore {
    private static let currentKey = "aven.growthMission.current.v1"
    private static let historyKey = "aven.growthMission.history.v1"

    static var current: AVENGrowthMission? {
        guard let data = UserDefaults.standard.data(forKey: currentKey) else { return nil }
        return try? JSONDecoder().decode(AVENGrowthMission.self, from: data)
    }

    static var history: [AVENGrowthMission] {
        guard let data = UserDefaults.standard.data(forKey: historyKey) else { return [] }
        return (try? JSONDecoder().decode([AVENGrowthMission].self, from: data)) ?? []
    }

    @discardableResult
    static func ensure(account: ConnectedTikTokAccount?, goal: AVENUserGrowthGoal? = AVENUserGoalStore.current) -> AVENGrowthMission? {
        if let existing = current { return existing }
        guard let account else { return nil }

        let goalType = goal?.type.lowercased() ?? ""
        let metric: AVENGrowthMissionMetric
        let baseline: Int
        if goalType.contains("like"), account.likes > 0 {
            metric = .likes; baseline = account.likes
        } else if account.followers > 0 {
            metric = .followers; baseline = account.followers
        } else if account.likes > 0 {
            metric = .likes; baseline = account.likes
        } else {
            return nil
        }

        let mission = make(metric: metric, baseline: baseline, stage: 1)
        persistCurrent(mission)
        return mission
    }

    @discardableResult
    static func sync(account: ConnectedTikTokAccount?) -> AVENGrowthMission? {
        guard let account else { return nil }
        guard var mission = current ?? ensure(account: account) else { return nil }
        let value = mission.currentValue(account: account)
        guard value >= mission.target else { return mission }

        mission.completedAt = mission.completedAt ?? Date()
        _ = AVENXPStore.grantOnce(key: "growth-mission.\(mission.id)", amount: mission.rewardXP)
        var completed = history
        if !completed.contains(where: { $0.id == mission.id }) { completed.append(mission) }
        if let data = try? JSONEncoder().encode(Array(completed.suffix(30))) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }

        let next = make(metric: mission.metric, baseline: value, stage: mission.stage + 1)
        persistCurrent(next)
        return next
    }

    private static func make(metric: AVENGrowthMissionMetric, baseline: Int, stage: Int) -> AVENGrowthMission {
        let baseDelta: Int
        switch metric {
        case .followers:
            if baseline < 500 { baseDelta = 30 }
            else if baseline < 5_000 { baseDelta = 75 }
            else if baseline < 20_000 { baseDelta = 150 }
            else { baseDelta = 300 }
        case .likes:
            if baseline < 5_000 { baseDelta = 100 }
            else if baseline < 50_000 { baseDelta = 250 }
            else { baseDelta = 500 }
        }
        let multiplier = 1.0 + Double(max(0, stage - 1)) * 0.35
        let delta = max(1, Int((Double(baseDelta) * multiplier).rounded()))
        let days = min(7, 3 + max(0, stage - 1))
        let xp = min(180, 45 + max(0, stage - 1) * 15)
        return AVENGrowthMission(
            id: UUID().uuidString, metric: metric, baseline: baseline, target: baseline + delta,
            stage: stage, rewardXP: xp, createdAt: Date(), durationDays: days, completedAt: nil
        )
    }

    private static func persistCurrent(_ mission: AVENGrowthMission) {
        if let data = try? JSONEncoder().encode(mission) {
            UserDefaults.standard.set(data, forKey: currentKey)
        }
        NotificationCenter.default.post(name: .growthMissionDidUpdate, object: nil)
    }
}

// ─── AI-generated action plan persistence ────────────────────────────────────

struct AVENAIPlanTask: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let priority: String
    let category: String
    let xp: Int
    let requiresProof: Bool
}

struct AVENAIPlanSnapshot: Codable {
    let analysisTimestamp: Date
    let createdAt: Date
    let tasks: [AVENAIPlanTask]
}

enum AVENAIActionPlanStore {
    private static let key = "aven.aiActionPlan.v1"

    static func save(tasks: [AVENAIPlanTask], for analysis: AnalysisRecord) {
        guard !tasks.isEmpty else { return }
        let snapshot = AVENAIPlanSnapshot(analysisTimestamp: analysis.timestamp, createdAt: Date(), tasks: tasks)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: key)
        NotificationCenter.default.post(name: .aiActionPlanDidUpdate, object: nil)
    }

    static func load(for analysis: AnalysisRecord) -> [AVENAIPlanTask]? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(AVENAIPlanSnapshot.self, from: data),
              abs(snapshot.analysisTimestamp.timeIntervalSince(analysis.timestamp)) < 2 else { return nil }
        return snapshot.tasks.isEmpty ? nil : snapshot.tasks
    }
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
