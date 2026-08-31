import SwiftUI
import AuthenticationServices

// ─── TikTok Account Page ──────────────────────────────────────────────────────
//
// Shows the connected TikTok account in AVEN's own premium UI.
// In demo mode: realistic mock data.
// Real mode: replace TikTokAccountService.load() with a real API call.
// Architecture: ViewModel fetches from TikTokAccountServiceProtocol,
// which is swappable between StubTikTokAccountService and a real client.

// ─── Model ────────────────────────────────────────────────────────────────────

struct TikTokAccountData {
    let username:    String
    let displayName: String
    let openId:      String          // "" for demo
    let avatarColor: Color           // demo: colour-based avatar; real: fallback
    let avatarUrl:   String?         // real: remote URL; nil for demo
    let followers:   Int
    let following:   Int
    let likes:       Int
    let videoCount:  Int
    let avenScore:   Int
    let videos:      [TikTokVideoThumb]
    let isDemo:      Bool
}

struct TikTokVideoThumb: Identifiable {
    let id      = UUID()
    let views:   Int
    let color:   Color            // demo placeholder; real: thumbnail URL
    let caption: String
}

// ─── Service protocol ─────────────────────────────────────────────────────────

protocol TikTokAccountServiceProtocol {
    func load() async throws -> TikTokAccountData
}

// ─── Stub (demo) ──────────────────────────────────────────────────────────────

final class StubTikTokAccountService: TikTokAccountServiceProtocol {
    func load() async throws -> TikTokAccountData {
        try await Task.sleep(nanoseconds: 400_000_000)
        // MARK: - Integration Point
        // Replace with real TikTok API calls:
        //   let profile = try await TikTokAPIClient.shared.getUserInfo(accessToken: token)
        //   let videos  = try await TikTokAPIClient.shared.getRecentVideos(accessToken: token)
        //   return TikTokAccountData(from: profile, videos: videos, isDemo: false)
        return TikTokAccountData(
            username:    "@philippxx16",
            displayName: "philippxx16",
            openId:      "",
            avatarColor: Color(hex: "#C23B22"),
            avatarUrl:   nil,
            followers:   1_745,
            following:   94,
            likes:       90,
            videoCount:  5,
            avenScore:   52,
            videos: [
                TikTokVideoThumb(views: 1_395, color: Color(hex: "#1C1C2E"), caption: ""),
                TikTokVideoThumb(views:   842, color: Color(hex: "#12122A"), caption: ""),
                TikTokVideoThumb(views:   531, color: Color(hex: "#0F2040"), caption: ""),
                TikTokVideoThumb(views:   278, color: Color(hex: "#1A1A30"), caption: ""),
                TikTokVideoThumb(views:   193, color: Color(hex: "#1E1E3A"), caption: ""),
            ],
            isDemo: true
        )
    }
}

// ─── ViewModel────────────────────────────────────────────────

// ─── TikTok OAuth flow ───────────────────────────────────────────────────────
//
// Flow:
//  1. GET  /auth/tiktok/initiate  → { authUrl }
//  2. ASWebAuthenticationSession opens authUrl in Safari/TikTok
//     callback URL intercepted: https://muddy-fire-2876.philipp-gaerner.workers.dev/auth/tiktok/callback
//  3. Backend exchanges code, fetches user.info.basic, returns JSON
//  4. App parses { displayName, openId, avatarUrl } and updates UI
//
// Scope: user.info.basic
// Redirect URI registered with TikTok: https://muddy-fire-2876.philipp-gaerner.workers.dev/auth/tiktok/callback
// No client_secret in the iOS app.


@MainActor
final class TikTokAccountViewModel: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {

    @Published var account:      TikTokAccountData?
    @Published var isLoading     = false
    @Published var isConnecting  = false
    @Published var connectError: String?
    @Published var error:        String?

    private let service:         TikTokAccountServiceProtocol
    // Injected from TikTokAccountView.task — weak to avoid retain cycle
    weak var container:          AppContainer?
    // Strong reference — ASWebAuthenticationSession must not be deallocated early
    private var authSession:     ASWebAuthenticationSession?
    private let workerBase       = "https://muddy-fire-2876.philipp-gaerner.workers.dev"
    private let callbackScheme   = "avengrowth"

    init(service: TikTokAccountServiceProtocol = StubTikTokAccountService()) {
        self.service = service
    }

    func load() async {
        // If a real connected account exists in AppContainer, use it directly.
        if let shared = container?.connectedTikTokAccount {
            account = TikTokAccountData(
                username:    shared.username,
                displayName: shared.displayName,
                openId:      shared.openId,
                avatarColor: Color(hex: "#7B61FF"),
                avatarUrl:   shared.avatarUrl,
                followers:   shared.followers,
                following:   shared.following,
                likes:       shared.likes,
                videoCount:  shared.videoCount,
                avenScore:   AVENAnalysisStore.currentScore,
                videos:      [],
                isDemo:      false
            )
            return
        }
        // No connected account — load demo
        isLoading = true; error = nil
        do { account = try await service.load() }
        catch { self.error = error.localizedDescription }
        isLoading = false
    }

    func connectWithTikTok() {
        guard !isConnecting else {
            print("[AVEN TikTok] ⚠️ already connecting, ignoring tap")
            return
        }
        print("[AVEN TikTok] 1/6 button tapped")
        Task { await runOAuthFlow() }
    }

    // ── OAuth flow ────────────────────────────────────────────────────────────
    //
    // Uses ASWebAuthenticationSession which:
    //  - opens the TikTok web/app auth screen in a secure browser
    //  - intercepts any redirect to avengrowth:// BEFORE iOS routing
    //  - requires no CFBundleURLTypes entry, no Associated Domains
    //  - eliminates the "Die App konnte nicht geöffnet werden" error
    //
    // The backend redirects to:  avengrowth://auth/tiktok/callback?code=...
    // or directly to:            avengrowth://auth/tiktok/callback?displayName=...

    private func runOAuthFlow() async {
        isConnecting = true
        connectError = nil
        defer {
            print("[AVEN TikTok] 6/6 flow finished – isConnecting reset")
            authSession  = nil
            isConnecting = false
        }

        // Step 1: fetch authUrl from backend
        guard let initiateURL = URL(string: "\(workerBase)/auth/tiktok/initiate") else {
            connectError = "Ungültige Backend-URL."; return
        }
        print("[AVEN TikTok] 2/6 initiate → \(initiateURL)")
        let authURL: URL
        do {
            let (data, resp) = try await URLSession.shared.data(from: initiateURL)
            let statusCode = (resp as? HTTPURLResponse)?.statusCode ?? 0
            print("[AVEN TikTok] 3/6 initiate response HTTP \(statusCode)")
            guard statusCode == 200 else {
                let body = String(data: data, encoding: .utf8) ?? "<binary>"
                print("[AVEN TikTok] ❌ initiate failed body=\(body)")
                connectError = "Server-Fehler (\(statusCode))."
                return
            }
            struct InitResp: Decodable {
                let authUrl: String?; let auth_url: String?
                var resolved: String? { authUrl ?? auth_url }
            }
            let body = try JSONDecoder().decode(InitResp.self, from: data)
            guard let str = body.resolved, let au = URL(string: str) else {
                let raw = String(data: data, encoding: .utf8) ?? "-"
                print("[AVEN TikTok] ❌ missing authUrl in: \(raw)")
                connectError = "Keine authUrl in Server-Antwort."
                return
            }
            authURL = au
            print("[AVEN TikTok] 4/6 authUrl: \(authURL)")
        } catch {
            print("[AVEN TikTok] ❌ initiate network error: \(error)")
            connectError = "Netzwerkfehler: \(error.localizedDescription)"
            return
        }

        // Step 2: open in ASWebAuthenticationSession with avengrowth:// callback scheme
        print("[AVEN TikTok] 5/6 creating ASWebAuthenticationSession (scheme=avengrowth)")
        let params: [String: String]? = await withCheckedContinuation { cont in
            let session = ASWebAuthenticationSession(
                url:               authURL,
                callbackURLScheme: callbackScheme
            ) { cbURL, error in
                if let error = error {
                    let asErr = error as? ASWebAuthenticationSessionError
                    let code  = asErr?.code.rawValue ?? -1
                    if asErr?.code == .canceledLogin {
                        print("[AVEN TikTok] user cancelled (errorCode=\(code))")
                    } else {
                        print("[AVEN TikTok] ❌ session error errorCode=\(code) error=\(error) errorDescription=\(error.localizedDescription)")
                    }
                    cont.resume(returning: nil)
                    return
                }
                guard let cb = cbURL else {
                    print("[AVEN TikTok] ❌ nil callbackURL with no error")
                    cont.resume(returning: nil); return
                }
                print("[AVEN TikTok] callback received: \(cb)")
                let comps = URLComponents(url: cb, resolvingAgainstBaseURL: false)
                let p = Dictionary(uniqueKeysWithValues:
                    (comps?.queryItems ?? []).compactMap { i -> (String,String)? in
                        guard let v = i.value else { return nil }; return (i.name, v)
                    }
                )
                cont.resume(returning: p)
            }
            session.prefersEphemeralWebBrowserSession = true   // forces fresh login, no cached session
            session.presentationContextProvider = self
            self.authSession = session   // strong reference until defer clears it
            let started = session.start()
            print("[AVEN TikTok] session.start() = \(started)")
            if !started {
                print("[AVEN TikTok] ❌ session failed to start – stopping")
                cont.resume(returning: nil)
            }
        }

        guard let p = params else { return }   // cancelled or error already logged

        if let errParam = p["error"] {
            let desc = p["error_description"] ?? errParam
            connectError = errParam == "access_denied" ? "Zugriff verweigert." : "TikTok-Fehler: \(desc)"
            print("[AVEN TikTok] error=\(errParam) errorDescription=\(desc)")
        } else if let name = p["displayName"] ?? p["display_name"] {
            applyUserInfo(name: name,
                          openId:    p["openId"]    ?? p["open_id"]    ?? "",
                          avatarUrl: p["avatarUrl"] ?? p["avatar_url"] ?? p["avatar_url_100"])
            print("[AVEN TikTok] success (identity only) displayName=\(name) – stats will show as 0")
        } else if let code = p["code"], !code.isEmpty {
            print("[AVEN TikTok] exchanging code")
            await exchangeCodeAndApply(code: code)
        } else {
            connectError = "Unerwartete Server-Antwort."
            print("[AVEN TikTok] unexpected params: \(p)")
        }
    }

    // ── ASWebAuthenticationPresentationContextProviding ───────────────────────
    // Must NOT block the main thread (no DispatchSemaphore.wait on main).
    // ASWebAuthenticationSession calls this on the main thread, so we can
    // access UIApplication synchronously.
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // This is always called on the main thread by the system.
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        ?? UIWindow()
    }

    // ── Code exchange (fallback when backend returns code instead of user info) ──

    private func exchangeCodeAndApply(code: String) async {
        guard let url = URL(string: "\(workerBase)/auth/tiktok/exchange") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Request all fields needed: user.info.basic + user.info.stats
        req.httpBody = try? JSONEncoder().encode([
            "code": code,
            "fields": "open_id,display_name,avatar_url,follower_count,following_count,likes_count,video_count"
        ])
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else {
                let body = String(data: data, encoding: .utf8) ?? ""
                print("[AVEN TikTok] ❌ exchange HTTP \(status) body=\(body)")
                connectError = "Exchange-Fehler (\(status))."
                return
            }
            print("[AVEN TikTok] exchange response: \(String(data: data, encoding: .utf8) ?? "")")
            struct ExchangeResp: Decodable {
                // Identity
                let displayName: String?; let display_name: String?
                let openId: String?;      let open_id: String?
                let avatarUrl: String?;   let avatar_url: String?; let avatar_url_100: String?
                // Stats — may be 0 for real accounts with no content
                let followerCount:  Int?; let follower_count:  Int?
                let followingCount: Int?; let following_count: Int?
                let likesCount:     Int?; let likes_count:     Int?
                let videoCount:     Int?; let video_count:     Int?
                var name:       String { displayName ?? display_name ?? "TikTok-Account" }
                var oId:        String { openId ?? open_id ?? "" }
                var avatar:     String? { avatarUrl ?? avatar_url ?? avatar_url_100 }
                var followers:  Int { followerCount  ?? follower_count  ?? 0 }
                var following:  Int { followingCount ?? following_count ?? 0 }
                var likes:      Int { likesCount     ?? likes_count     ?? 0 }
                var videos:     Int { videoCount     ?? video_count     ?? 0 }
            }
            let body = try JSONDecoder().decode(ExchangeResp.self, from: data)
            applyUserInfo(
                name:          body.name,
                openId:        body.oId,
                avatarUrl:     body.avatar,
                followers:     body.followers,
                following:     body.following,
                likes:         body.likes,
                videoCount:    body.videos
            )
        } catch {
            print("[AVEN TikTok] ❌ exchange error: \(error)")
            connectError = "Netzwerkfehler: \(error.localizedDescription)"
        }
    }

    private func applyUserInfo(name: String, openId: String, avatarUrl: String?,
                               followers: Int = 0, following: Int = 0,
                               likes: Int = 0, videoCount: Int = 0) {
        let username = name.hasPrefix("@") ? name : "@\(name)"
        // Build the shared account record — use real values including zeros
        let shared = ConnectedTikTokAccount(
            openId:      openId,
            username:    username,
            displayName: name,
            avatarUrl:   avatarUrl,
            followers:   followers,
            following:   following,
            likes:       likes,
            videoCount:  videoCount
        )
        // Write to AppContainer (persists to UserDefaults, triggers ProfileView update)
        container?.setConnectedTikTokAccount(shared)
        // Update local account for TikTokAccountView
        account = TikTokAccountData(
            username:    username,
            displayName: name,
            openId:      openId,
            avatarColor: Color(hex: "#7B61FF"),
            avatarUrl:   avatarUrl,
            followers:   followers,
            following:   following,
            likes:       likes,
            videoCount:  videoCount,
            avenScore:   AVENAnalysisStore.currentScore,
            videos:      [],
            isDemo:      false
        )
        print("[AVEN TikTok] account saved: \(username) followers=\(followers) following=\(following) likes=\(likes) videos=\(videoCount)")
    }
}

// ─── View ─────────────────────────────────────────────────────────────────────

struct TikTokAccountView: View {
    @StateObject private var vm = TikTokAccountViewModel()
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    var onNewAnalysis: (() -> Void)? = nil

    var body: some View {
        ZStack {
            AVENColor.backgroundPrimary.ignoresSafeArea()

            if vm.isLoading {
                AccountLoadingView()
            } else if let account = vm.account {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        AccountHeaderView(
                            account:       account,
                            dismiss:       dismiss,
                            isConnecting:  vm.isConnecting,
                            connectError:  vm.connectError,
                            onNewAnalysis: {
                                dismiss()
                                onNewAnalysis?()
                            },
                            onConnectTap:  { vm.connectWithTikTok() },
                            onDisconnect:  { container.disconnectTikTok() }
                        )
                        VideoGridSection(videos: account.videos)
                        Spacer(minLength: AVENSpacing.xxl)
                    }
                }
            } else if let error = vm.error {
                ErrorView(message: error) { Task { await vm.load() } }
            }
        }
        .task {
            vm.container = container
            if container.connectedTikTokAccount == nil {
                // No account yet → skip demo view, go directly to OAuth
                vm.connectWithTikTok()
            } else {
                // Already connected → show real account data
                await vm.load()
            }
        }
    }
}

// ─── Header ───────────────────────────────────────────────────────────────────

private struct AccountHeaderView: View {
    let account:       TikTokAccountData
    let dismiss:       DismissAction
    let isConnecting:  Bool
    let connectError:  String?
    let onNewAnalysis: () -> Void
    let onConnectTap:  () -> Void
    let onDisconnect:  () -> Void
    @State private var scoreAppeared    = false
    @State private var showManageSheet  = false

    var body: some View {
        VStack(spacing: 0) {
            // Nav bar
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AVENColor.textPrimary)
                }
                .buttonStyle(PressButtonStyle())
                Spacer()
                Text("TikTok Account")
                    .font(AVENFont.body(17, weight: .semibold))
                    .foregroundColor(AVENColor.textPrimary)
                Spacer()
                // Balance the chevron
                Color.clear.frame(width: 28, height: 28)
            }
            .padding(.horizontal, AVENSpacing.md)
            .padding(.top, AVENSpacing.md)
            .padding(.bottom, AVENSpacing.sm)

            // Demo badge — tappable to start real TikTok OAuth
            if account.isDemo {
                VStack(spacing: 6) {
                    Button(action: onConnectTap) {
                        HStack(spacing: 6) {
                            if isConnecting {
                                ProgressView().tint(AVENColor.accentPurple).scaleEffect(0.75)
                            } else {
                                Image(systemName: "theatermasks.fill")
                                    .font(.system(size: 11))
                            }
                            Text(isConnecting
                                 ? "TikTok wird verbunden …"
                                 : "Demo Account — Verbinde TikTok für echte Daten")
                                .font(AVENFont.body(12, weight: .medium))
                        }
                        .foregroundColor(AVENColor.accentPurple)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(AVENColor.accentPurple.opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(AVENColor.accentPurple.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(PressButtonStyle())
                    .disabled(isConnecting)

                    if let err = connectError {
                        Text(err)
                            .font(AVENFont.body(11))
                            .foregroundColor(AVENColor.textNegative)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AVENSpacing.lg)
                    }
                }
                .cardAppear(delay: 0)
                .padding(.bottom, AVENSpacing.md)
            }

            // Avatar + name
            VStack(spacing: AVENSpacing.sm) {
                TikTokAvatarView(
                    displayName: account.displayName,
                    avatarUrl:   account.avatarUrl,
                    size:        84,
                    ringColor:   account.avatarColor
                )
                .cardAppear(delay: 0.05)

                VStack(spacing: 3) {
                    Text(account.displayName)
                        .font(AVENFont.display(20))
                        .foregroundColor(AVENColor.textPrimary)
                    Text(account.username)
                        .font(AVENFont.body(14))
                        .foregroundColor(AVENColor.textSecondary)
                }
                .cardAppear(delay: 0.08)
            }
            .padding(.bottom, AVENSpacing.lg)

            // Stats row
            AVENCard(accentBorder: false) {
                HStack(spacing: 0) {
                    AccountStat(value: account.followers, label: "Follower")
                    Divider().background(AVENColor.borderSubtle).frame(height: 36)
                    AccountStat(value: account.following, label: "Following")
                    Divider().background(AVENColor.borderSubtle).frame(height: 36)
                    AccountStat(value: account.likes,     label: "Likes")
                    Divider().background(AVENColor.borderSubtle).frame(height: 36)
                    AccountStat(value: account.videoCount, label: "Videos")
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, AVENSpacing.md)
            .cardAppear(delay: 0.1)

            // AVEN Score card
            AVENCard(accentBorder: true) {
                HStack(spacing: AVENSpacing.lg) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AVEN Score")
                            .font(AVENFont.body(13))
                            .foregroundColor(AVENColor.textSecondary)
                        Text("Gut")
                            .font(AVENFont.display(20))
                            .foregroundStyle(LinearGradient(
                                colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                                startPoint: .leading, endPoint: .trailing))
                        Text("Basierend auf letzter Analyse")
                            .font(AVENFont.body(11))
                            .foregroundColor(AVENColor.textMuted)
                    }
                    Spacer()
                    AnimatedScoreArcView(targetScore: scoreAppeared ? account.avenScore : 0, size: 80)
                }
            }
            .padding(.horizontal, AVENSpacing.md)
            .padding(.top, AVENSpacing.sm)
            .cardAppear(delay: 0.14)
            .onAppear { withAnimation(AVENMotion.scoreArc.delay(0.3)) { scoreAppeared = true } }

            // Action buttons
            VStack(spacing: AVENSpacing.sm) {
                AVENPrimaryButton(title: "Neue Analyse starten", icon: "sparkles") {
                    onNewAnalysis()
                }
                Button { showManageSheet = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "gear")
                            .font(.system(size: 14))
                        Text("TikTok Account verwalten")
                            .font(AVENFont.body(15))
                    }
                    .foregroundColor(AVENColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AVENColor.backgroundCard)
                    .clipShape(RoundedRectangle(cornerRadius: AVENRadius.md))
                    .overlay(RoundedRectangle(cornerRadius: AVENRadius.md)
                        .strokeBorder(AVENColor.borderSubtle, lineWidth: 1))
                }
                .buttonStyle(PressButtonStyle())
                .confirmationDialog("TikTok Account verwalten",
                                    isPresented: $showManageSheet,
                                    titleVisibility: .visible) {
                    Button("Account trennen", role: .destructive) {
                        onDisconnect()
                        dismiss()
                    }
                    Button("Abbrechen", role: .cancel) { }
                } message: {
                    Text("Nur die TikTok-Verbindung wird entfernt. Dein AVEN Score, Analysen und Abo bleiben vollständig erhalten.")
                }
            }
            .padding(.horizontal, AVENSpacing.md)
            .padding(.top, AVENSpacing.sm)
            .cardAppear(delay: 0.18)

            // Videos header
            HStack {
                Text("Letzte Videos")
                    .font(AVENFont.body(15, weight: .semibold))
                    .foregroundColor(AVENColor.textPrimary)
                Spacer()
                Text("\(account.videoCount) gesamt")
                    .font(AVENFont.body(13))
                    .foregroundColor(AVENColor.textSecondary)
            }
            .padding(.horizontal, AVENSpacing.md)
            .padding(.top, AVENSpacing.lg)
            .padding(.bottom, AVENSpacing.sm)
            .cardAppear(delay: 0.22)
        }
    }
}

// ─── Stats pill ───────────────────────────────────────────────────────────────

private struct AccountStat: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            AnimatedCounterView(target: value, font: AVENFont.display(18), color: AVENColor.textPrimary)
            Text(label)
                .font(AVENFont.body(11))
                .foregroundColor(AVENColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AVENSpacing.sm)
    }
}

// ─── Video grid ───────────────────────────────────────────────────────────────

private struct VideoGridSection: View {
    let videos: [TikTokVideoThumb]

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(Array(videos.enumerated()), id: \.element.id) { idx, video in
                VideoThumbCard(video: video, isFeatured: idx == 0)
                    .staggerAppear(index: idx, baseDelay: 0.06)
            }
        }
        .padding(.horizontal, AVENSpacing.sm)
    }
}

private struct VideoThumbCard: View {
    let video: TikTokVideoThumb
    let isFeatured: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                // Colour placeholder (real: thumbnail image)
                RoundedRectangle(cornerRadius: AVENRadius.sm)
                    .fill(video.color)
                    .overlay(
                        // MARK: - Integration Point: AsyncImage(url: video.thumbnailURL)
                        LinearGradient(
                            colors: [.clear, .black.opacity(isFeatured ? 0.65 : 0.55)],
                            startPoint: .center, endPoint: .bottom)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AVENRadius.sm))

                // Play icon centre
                Image(systemName: isFeatured ? "play.circle.fill" : "play.fill")
                    .font(.system(size: isFeatured ? 28 : 16, weight: .semibold))
                    .foregroundColor(.white.opacity(isFeatured ? 0.9 : 0.65))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // View count
                HStack(spacing: 3) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 9))
                    Text(formatK(video.views))
                        .font(AVENFont.mono(11))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.bottom, 6)
            }
            .frame(width: geo.size.width, height: geo.size.width * 1.78)
            .overlay(
                isFeatured
                    ? RoundedRectangle(cornerRadius: AVENRadius.sm)
                        .strokeBorder(AVENColor.accentPurple.opacity(0.7), lineWidth: 1.5)
                    : nil
            )
        }
        .aspectRatio(9.0/16.0, contentMode: .fit)
    }
}

// ─── Loading / Error ──────────────────────────────────────────────────────────

private struct AccountLoadingView: View {
    @State private var rotation: Double = 0
    var body: some View {
        VStack(spacing: AVENSpacing.xl) {
            Spacer()
            ZStack {
                Circle().stroke(AVENColor.borderSubtle, lineWidth: 3).frame(width: 52, height: 52)
                Circle()
                    .trim(from: 0, to: 0.6)
                    .stroke(LinearGradient(
                        colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                        startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 52, height: 52)
                    .rotationEffect(.degrees(rotation))
                    .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: rotation)
            }
            .onAppear { rotation = 360 }
            Text("Lade Account…")
                .font(AVENFont.body(15))
                .foregroundColor(AVENColor.textSecondary)
            Spacer()
        }
    }
}

private struct ErrorView: View {
    let message: String
    let retry:   () -> Void
    var body: some View {
        VStack(spacing: AVENSpacing.lg) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(AVENColor.textNegative)
            Text(message)
                .font(AVENFont.body(14))
                .foregroundColor(AVENColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AVENSpacing.xl)
            Button(action: retry) {
                Text("Erneut versuchen")
                    .font(AVENFont.body(15, weight: .semibold))
                    .foregroundColor(AVENColor.accentPurple)
            }
            .buttonStyle(PressButtonStyle())
            Spacer()
        }
    }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

private func formatK(_ n: Int) -> String {
    if n >= 1_000_000 { return String(format: "%.1fM", Double(n)/1_000_000) }
    if n >= 1_000     { return String(format: "%.1fK", Double(n)/1_000) }
    return "\(n)"
}

#Preview {
    TikTokAccountView()
}
