import Foundation

// ─── AVENSubscription ─────────────────────────────────────────────────────────
// Single source of truth for all feature gates in AVEN.
//
// Debug test tier: set AVEN_TEST_TIER in scheme environment variables
//   Values: "free" | "pro" | "proplus"
//   Only active in DEBUG builds. Does NOT affect real StoreKit.

// ── Tiers ─────────────────────────────────────────────────────────────────────

enum AVENTier: String, Comparable {
    case free    = "free"
    case pro     = "pro"
    case proPlus = "proplus"

    static func < (l: AVENTier, r: AVENTier) -> Bool {
        let order: [AVENTier] = [.free, .pro, .proPlus]
        return (order.firstIndex(of: l) ?? 0) < (order.firstIndex(of: r) ?? 0)
    }

    var displayName: String {
        switch self {
        case .free:    return "FREE"
        case .pro:     return "PRO"
        case .proPlus: return "PRO+"
        }
    }
}

// ── Limits per tier ────────────────────────────────────────────────────────────

struct AVENTierLimits {
    let profileAnalysesPerMonth: Int   // -1 = unlimited
    let videoAnalysesPerMonth:   Int
    let blueprintsPerMonth:      Int
    let coachQuestionsPerMonth:  Int
    let maxVideoDurationSec:     Int   // for video analysis
    let maxBlueprintSec:         Int
    let hasFullFindings:         Bool
    let hasActionPlan:           Bool
    let hasCoach:                Bool

    static let free = AVENTierLimits(
        profileAnalysesPerMonth: 3,
        videoAnalysesPerMonth:   0,
        blueprintsPerMonth:      0,
        coachQuestionsPerMonth:  0,
        maxVideoDurationSec:     0,
        maxBlueprintSec:         0,
        hasFullFindings:         false,
        hasActionPlan:           false,
        hasCoach:                false
    )

    static let pro = AVENTierLimits(
        profileAnalysesPerMonth: 30,
        videoAnalysesPerMonth:   10,
        blueprintsPerMonth:      50,
        coachQuestionsPerMonth:  0,
        maxVideoDurationSec:     120,
        maxBlueprintSec:         90,
        hasFullFindings:         true,
        hasActionPlan:           true,
        hasCoach:                false
    )

    static let proPlus = AVENTierLimits(
        profileAnalysesPerMonth: 100,
        videoAnalysesPerMonth:   20,
        blueprintsPerMonth:      100,
        coachQuestionsPerMonth:  100,
        maxVideoDurationSec:     120,
        maxBlueprintSec:         90,
        hasFullFindings:         true,
        hasActionPlan:           true,
        hasCoach:                true
    )
}

// ── Monthly usage tracking ─────────────────────────────────────────────────────

private struct UsageKeys {
    let used:  String
    let month: String
}

private func usageKeys(for type: String) -> UsageKeys {
    UsageKeys(used: "aven.usage.\(type).used", month: "aven.usage.\(type).month")
}

private func currentMonthString() -> String {
    let c = Calendar.current; let d = Date()
    return "\(c.component(.year, from: d))-\(c.component(.month, from: d))"
}

func avenUsageRemaining(type: String, limit: Int) -> Int {
    guard limit > 0 else { return 0 }
    let keys = usageKeys(for: type)
    let month = UserDefaults.standard.string(forKey: keys.month) ?? ""
    let used  = (month == currentMonthString()) ? UserDefaults.standard.integer(forKey: keys.used) : 0
    return max(0, limit - used)
}

func avenConsumeUsage(type: String, limit: Int) -> Bool {
    guard limit != 0 else { return true }   // -1 = unlimited
    let keys = usageKeys(for: type)
    let month = currentMonthString()
    let stored = UserDefaults.standard.string(forKey: keys.month) ?? ""
    var used = (stored == month) ? UserDefaults.standard.integer(forKey: keys.used) : 0
    guard limit < 0 || used < limit else { return false }
    used += 1
    UserDefaults.standard.set(used,  forKey: keys.used)
    UserDefaults.standard.set(month, forKey: keys.month)
    return true
}

// ── Central service ────────────────────────────────────────────────────────────

@MainActor
final class AVENSubscriptionService: ObservableObject {

    // Real tier from StoreKit (written by StoreKit listener)
    @Published private var storedTier: AVENTier = {
        let raw = UserDefaults.standard.string(forKey: "aven.currentPlan") ?? ""
        // Map legacy AVENPlan strings to AVENTier
        switch raw {
        case "pro":     return .pro
        case "proplus", "pro_plus", "proPlus": return .proPlus
        default:        return .free
        }
    }()

    // ── Debug test tier ───────────────────────────────────────────────────────
    #if DEBUG
    private var debugTier: AVENTier? = {
        guard let raw = ProcessInfo.processInfo.environment["AVEN_TEST_TIER"] else { return nil }
        return AVENTier(rawValue: raw.lowercased())
    }()
    #endif

    /// The effective tier used by ALL feature gates in the app.
    var effectiveTier: AVENTier {
        #if DEBUG
        return debugTier ?? storedTier
        #else
        return storedTier
        #endif
    }

    var limits: AVENTierLimits {
        switch effectiveTier {
        case .free:    return .free
        case .pro:     return .pro
        case .proPlus: return .proPlus
        }
    }

    // ── Feature checks ────────────────────────────────────────────────────────

    var canAnalyzeProfile:    Bool { avenUsageRemaining(type:"profile",   limit:limits.profileAnalysesPerMonth) > 0 || limits.profileAnalysesPerMonth < 0 }
    var canAnalyzeVideo:      Bool { limits.videoAnalysesPerMonth > 0 && avenUsageRemaining(type:"video", limit:limits.videoAnalysesPerMonth) > 0 }
    var canCreateBlueprint:   Bool { limits.blueprintsPerMonth > 0 && avenUsageRemaining(type:"blueprint", limit:limits.blueprintsPerMonth) > 0 }
    var canAskCoach:          Bool { limits.hasCoach && avenUsageRemaining(type:"coach", limit:limits.coachQuestionsPerMonth) > 0 }
    var hasFullFindings:      Bool { limits.hasFullFindings }
    var hasActionPlan:        Bool { limits.hasActionPlan }
    var hasCoachAccess:       Bool { limits.hasCoach }

    func profileAnalysesLeft()  -> Int { avenUsageRemaining(type:"profile",   limit:limits.profileAnalysesPerMonth) }
    func videoAnalysesLeft()    -> Int { avenUsageRemaining(type:"video",     limit:limits.videoAnalysesPerMonth) }
    func blueprintsLeft()       -> Int { avenUsageRemaining(type:"blueprint", limit:limits.blueprintsPerMonth) }
    func coachQuestionsLeft()   -> Int { avenUsageRemaining(type:"coach",     limit:limits.coachQuestionsPerMonth) }

    @discardableResult func consumeProfileAnalysis() -> Bool { avenConsumeUsage(type:"profile",   limit:limits.profileAnalysesPerMonth) }
    @discardableResult func consumeVideoAnalysis()   -> Bool { avenConsumeUsage(type:"video",     limit:limits.videoAnalysesPerMonth) }
    @discardableResult func consumeBlueprint()       -> Bool { avenConsumeUsage(type:"blueprint", limit:limits.blueprintsPerMonth) }
    @discardableResult func consumeCoachQuestion()   -> Bool { avenConsumeUsage(type:"coach",     limit:limits.coachQuestionsPerMonth) }

    // ── Plan update (called by StoreKit listener) ──────────────────────────────
    func updateTier(_ tier: AVENTier) {
        storedTier = tier
        UserDefaults.standard.set(tier.rawValue, forKey: "aven.currentPlan")
    }

    // ── Legacy compat: VideoCreditsService still used in some UI ──────────────
    var isProUser: Bool { effectiveTier >= .pro }

    #if DEBUG
    func setDebugTier(_ tier: AVENTier) { debugTier = tier; objectWillChange.send() }
    #endif
}
