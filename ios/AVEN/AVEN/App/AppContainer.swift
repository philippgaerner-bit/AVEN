import SwiftUI
import Combine

// ─── Shared connected TikTok account ──────────────────────────────────────────

struct ConnectedTikTokAccount: Codable, Equatable {
    let openId:      String
    let username:    String   // with @ prefix
    let displayName: String
    let avatarUrl:   String?
    let followers:   Int
    let following:   Int
    let likes:       Int
    let videoCount:  Int
}

// ─── AppContainer — dependency injection root ─────────────────────────────────

@MainActor
final class AppContainer: ObservableObject {
    let apiClient: AVENAPIClient
    let videoCredits    = VideoCreditsService()
    let authService     = AVENAuthService()
    let subscription    = AVENSubscriptionService()

    @Published var selectedTab:       AppTab = .home
    @Published var showNewScan:       Bool   = false
    @Published var showCreationMenu:  Bool   = false
    @Published var showAIVideo:       Bool   = false
    @Published var showTikTokAccount: Bool   = false

    // ── Shared TikTok connection state ────────────────────────────────────────
    // Single source of truth — persisted across launches.
    // Written by TikTokAccountViewModel after successful auth.
    // Read by ProfileView, HomeView, TikTokAccountView.

    private let tikTokAccountKey = "aven.connectedTikTokAccount"

    @Published var connectedTikTokAccount: ConnectedTikTokAccount? {
        didSet { persist(connectedTikTokAccount) }
    }

    var isTikTokConnected: Bool { connectedTikTokAccount != nil }

    func setConnectedTikTokAccount(_ account: ConnectedTikTokAccount) {
        connectedTikTokAccount = account
    }

    func disconnectTikTok() {
        connectedTikTokAccount = nil
    }

    private func persist(_ account: ConnectedTikTokAccount?) {
        if let account, let data = try? JSONEncoder().encode(account) {
            UserDefaults.standard.set(data, forKey: tikTokAccountKey)
        } else {
            UserDefaults.standard.removeObject(forKey: tikTokAccountKey)
        }
    }

    private let workerBase = "https://muddy-fire-2876.philipp-gaerner.workers.dev"
    private var syncTimer: Timer?

    init() {
        self.apiClient = AppContainer.makeAPIClient()
        // Restore from last session
        if let data = UserDefaults.standard.data(forKey: tikTokAccountKey),
           let account = try? JSONDecoder().decode(ConnectedTikTokAccount.self, from: data) {
            self._connectedTikTokAccount = Published(initialValue: account)
        }
        scheduleSyncIfNeeded()
    }

    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(apiClient: apiClient)
    }

    // ── TikTok Stats Sync ─────────────────────────────────────────────────────
    // Fetches fresh stats from the backend and updates connectedTikTokAccount.
    // Called on app foreground and on a plan-based timer.

    func syncTikTokStats() {
        guard let account = connectedTikTokAccount, !account.openId.isEmpty else { return }
        Task {
            guard let url = URL(string: "\(workerBase)/auth/tiktok/userinfo?open_id=\(account.openId)") else { return }
            do {
                let (data, resp) = try await URLSession.shared.data(from: url)
                guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return }
                struct StatsResp: Decodable {
                    let follower_count:  Int?;  let followerCount:  Int?
                    let following_count: Int?;  let followingCount: Int?
                    let likes_count:     Int?;  let likesCount:     Int?
                    let video_count:     Int?;  let videoCount:     Int?
                    var followers: Int { follower_count  ?? followerCount  ?? 0 }
                    var following: Int { following_count ?? followingCount ?? 0 }
                    var likes:     Int { likes_count     ?? likesCount     ?? 0 }
                    var videos:    Int { video_count     ?? videoCount     ?? 0 }
                }
                if let stats = try? JSONDecoder().decode(StatsResp.self, from: data) {
                    await MainActor.run {
                        let updated = ConnectedTikTokAccount(
                            openId:      account.openId,
                            username:    account.username,
                            displayName: account.displayName,
                            avatarUrl:   account.avatarUrl,
                            followers:   stats.followers,
                            following:   stats.following,
                            likes:       stats.likes,
                            videoCount:  stats.videos
                        )
                        connectedTikTokAccount = updated
                        // Trigger Analytics / Home refresh so UI shows new follower count
                        NotificationCenter.default.post(name: .analysisDidComplete, object: nil)
                    }
                }
            } catch { /* silent — stale data remains */ }
        }
    }

    /// Schedule background sync interval based on current plan.
    /// Free: sync on open only (no timer). Pro: every 15 min. Pro+: every 5 min.
    func scheduleSyncIfNeeded() {
        syncTimer?.invalidate()
        syncTimer = nil
        let interval: TimeInterval
        switch videoCredits.currentPlan {
        case .free:    return   // Free: manual only
        case .pro:     interval = 15 * 60
        case .proPlus: interval = 5 * 60
        }
        syncTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.syncTikTokStats()
        }
    }
}

enum AppTab: Hashable {
    case home, analytics, create, actionPlan, profile
}

extension AppContainer {
    static var preview: AppContainer { AppContainer() }
}
