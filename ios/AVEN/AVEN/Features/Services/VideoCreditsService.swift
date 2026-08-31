import Foundation

// ─── VideoCreditsService ──────────────────────────────────────────────────────
//
// Central source of truth for:
//   • KI-Video-GENERATION seconds (NOT video-analysis — that is unlimited)
//   • KI-Coach question count (PRO+ only)
//
// Both limits reset each calendar month.
// Storage: UserDefaults (replace keys with backend calls in production).
//
// Limits (from AVENPlan.videoMonthlyLimit / coachMonthlyLimit):
//   FREE:    0 video seconds   |  0 coach questions
//   PRO:    10 video seconds   |  0 coach questions
//   PRO+:   30 video seconds   | 100 coach questions

@MainActor
final class VideoCreditsService: ObservableObject {

    // ── Current plan ──────────────────────────────────────────────────────────
    @Published var currentPlan: AVENPlan = {
        #if DEBUG
        return .proPlus
        #else
        let saved = UserDefaults.standard.string(forKey: "aven.currentPlan") ?? ""
        return AVENPlan(rawValue: saved) ?? .free
        #endif
    }() {
        didSet {
            #if !DEBUG
            UserDefaults.standard.set(currentPlan.rawValue, forKey: "aven.currentPlan")
            #endif
            // On upgrade, re-check limits without resetting used amounts
            checkMonthReset()
        }
    }

    // ── Video seconds ─────────────────────────────────────────────────────────
    @Published private(set) var videoSecondsUsed: Int = 0

    var videoSecondsLimit: Int  { currentPlan.videoMonthlyLimit }
    var videoSecondsLeft: Int   { max(0, videoSecondsLimit - videoSecondsUsed) }
    var canGenerateVideo: Bool  { videoSecondsLimit > 0 && videoSecondsLeft > 0 }

    func canGenerateSeconds(_ requested: Int) -> Bool {
        videoSecondsLimit > 0 && videoSecondsLeft >= requested
    }

    func videoRemainingLabel() -> String {
        // Blueprints are unlimited — no seconds counter shown
        return ""
    }

    /// Call AFTER a successful generation start. Pass actual seconds generated.
    func consumeVideoSeconds(_ seconds: Int) {
        guard canGenerateVideo else { return }
        videoSecondsUsed = min(videoSecondsUsed + seconds, videoSecondsLimit)
        saveVideoToStorage()
    }

    // ── Coach questions ───────────────────────────────────────────────────────
    @Published private(set) var coachQuestionsUsed: Int = 0

    var coachQuestionsLimit: Int { currentPlan.coachMonthlyLimit }
    var coachQuestionsLeft: Int  { max(0, coachQuestionsLimit - coachQuestionsUsed) }
    var hasCoachAccess: Bool     { currentPlan.hasCoachAccess }
    var canAskCoach: Bool        { hasCoachAccess && coachQuestionsLeft > 0 }

    func coachRemainingLabel() -> String {
        guard coachQuestionsLimit > 0 else { return "Nicht verfügbar" }
        return "\(coachQuestionsLeft) von \(coachQuestionsLimit) Fragen verfügbar"
    }

    /// Call BEFORE the external API call. Returns true if allowed.
    @discardableResult
    func consumeCoachQuestion() -> Bool {
        guard canAskCoach else { return false }
        coachQuestionsUsed += 1
        saveCoachToStorage()
        return true
    }

    // ── Legacy compat (used by isProUser checks) ──────────────────────────────
    var isProUser: Bool { currentPlan != .free }

    /// Kept for call-site compatibility — now means video generation seconds.
    var monthlyLimit: Int   { videoSecondsLimit }
    var creditsUsed: Int    { videoSecondsUsed }
    var creditsLeft: Int    { videoSecondsLeft }
    var canGenerate: Bool   { canGenerateVideo }

    /// Kept for call-site compat — consumes 1 second equivalent.
    func consumeCredit() { consumeVideoSeconds(1) }

    var remainingLabel: String { "" }  // Blueprints unlimited — no display

    // ── Storage ───────────────────────────────────────────────────────────────

    private let videoUsedKey:  String = "aven.videoCredits.secondsUsed"
    private let videoMonthKey: String = "aven.videoCredits.month"
    private let coachUsedKey:  String = "aven.coachCredits.questionsUsed"
    private let coachMonthKey: String = "aven.coachCredits.month"

    init() { checkMonthReset() }

    private func checkMonthReset() {
        let now = currentMonthKey()

        // Video seconds
        let vMonth = UserDefaults.standard.string(forKey: videoMonthKey) ?? ""
        if vMonth == now {
            videoSecondsUsed = UserDefaults.standard.integer(forKey: videoUsedKey)
        } else {
            videoSecondsUsed = 0
            UserDefaults.standard.set(now, forKey: videoMonthKey)
            UserDefaults.standard.set(0,   forKey: videoUsedKey)
        }

        // Coach questions
        let cMonth = UserDefaults.standard.string(forKey: coachMonthKey) ?? ""
        if cMonth == now {
            coachQuestionsUsed = UserDefaults.standard.integer(forKey: coachUsedKey)
        } else {
            coachQuestionsUsed = 0
            UserDefaults.standard.set(now, forKey: coachMonthKey)
            UserDefaults.standard.set(0,   forKey: coachUsedKey)
        }
    }

    private func saveVideoToStorage() {
        UserDefaults.standard.set(videoSecondsUsed,  forKey: videoUsedKey)
        UserDefaults.standard.set(currentMonthKey(), forKey: videoMonthKey)
    }

    private func saveCoachToStorage() {
        UserDefaults.standard.set(coachQuestionsUsed, forKey: coachUsedKey)
        UserDefaults.standard.set(currentMonthKey(),  forKey: coachMonthKey)
    }

    private func currentMonthKey() -> String {
        let c = Calendar.current; let d = Date()
        return "\(c.component(.year, from: d))-\(c.component(.month, from: d))"
    }
}
