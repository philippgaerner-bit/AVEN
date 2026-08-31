// ─── TikTok redirect URI ─────────────────────────────────────────────────────
// This URI is registered in the TikTok Developer Portal.
// The backend receives the OAuth code at this endpoint and redirects
// the user back to the app via the avengrowth:// custom URL scheme.
// The iOS app never sees this URI directly — ASWebAuthenticationSession
// intercepts the avengrowth:// deep-link after the backend redirects.
//
// Registered redirect URI: https://avencreator.app/auth/tiktok/callback
// iOS callback scheme:     avengrowth://auth/tiktok/complete
//
// client_key is passed to the backend only (never stored in the iOS app).
// client_secret lives exclusively on the backend.

import Foundation
import AuthenticationServices

// ─── TikTok OAuth Service ─────────────────────────────────────────────────────
//
// Architecture:
//   The iOS app never holds TikTok client_secret or access tokens.
//   All secret operations happen on the AVEN backend.
//
// Full OAuth flow:
//   1. iOS calls GET /auth/tiktok/initiate?profileId=... (with auth token)
//      Backend generates PKCE verifier, state token, returns TikTok auth URL.
//   2. iOS opens TikTok auth URL in ASWebAuthenticationSession.
//      The session intercepts ANY redirect to avengrowth:// as a callback.
//   3. User logs in on TikTok → TikTok redirects to backend callback URL.
//   4. Backend validates state, exchanges code (with PKCE), links account.
//   5. Backend redirects to avengrowth://auth/tiktok/complete?success=...
//   6. ASWebAuthenticationSession intercepts the deep-link → completion handler fires.
//   7. iOS parses deep-link params and updates UI state.
//
// Development prerequisites:
//   1. Register TikTok Developer App at https://developers.tiktok.com
//   2. Set in Xcode scheme env: AVEN_API_URL = http://localhost:3000
//   3. Set backend env: TIKTOK_CLIENT_KEY, TIKTOK_CLIENT_SECRET
//   4. Add URL scheme "avengrowth" in Xcode → Target → Info → URL Types
//   5. Set TIKTOK_REDIRECT_URI = https://avencreator.app/auth/tiktok/callback
//      (must be https and registered in TikTok portal; localhost won't work for redirect)

// ─── Backend configuration ────────────────────────────────────────────────────

enum AVENBackendConfig {
    /// Backend base URL from env var (Xcode scheme) or AVENConfig.plist.
    /// Returns nil if not set → UI shows clear setup state.
    static var backendURL: String? {
        if let v = ProcessInfo.processInfo.environment["AVEN_API_URL"], !v.isEmpty {
            return v.hasSuffix("/") ? String(v.dropLast()) : v
        }
        if let path  = Bundle.main.path(forResource: "AVENConfig", ofType: "plist"),
           let plist  = NSDictionary(contentsOfFile: path),
           let url    = plist["BackendURL"] as? String, !url.isEmpty {
            return url.hasSuffix("/") ? String(url.dropLast()) : url
        }
        return nil
    }
}

// ─── Connection state ─────────────────────────────────────────────────────────

enum TikTokConnectionState: Equatable {
    case disconnected
    case connecting
    case connected(username: String, accountId: String)
    case error(TikTokOAuthError)
    /// Backend URL not configured in environment — show setup instructions.
    case unconfigured
}

enum TikTokOAuthError: Error, Equatable {
    case backendNotConfigured
    case userCancelled
    case invalidCallback(String)
    case networkError(String)
    case stateMismatch
    case unknown(String)

    var userMessage: String {
        switch self {
        case .backendNotConfigured:
            return "TikTok-Verbindung ist nicht eingerichtet.\n\nSetze AVEN_API_URL in den Xcode-Schema-Umgebungsvariablen und starte das AVEN-Backend mit TIKTOK_CLIENT_KEY und TIKTOK_CLIENT_SECRET."
        case .userCancelled:
            return "Anmeldung abgebrochen."
        case .invalidCallback(let msg):
            return "Rückgabe-Fehler: \(msg)"
        case .networkError(let msg):
            return msg
        case .stateMismatch:
            return "Sicherheitsfehler: State-Token ungültig. Bitte erneut versuchen."
        case .unknown(let msg):
            return "Unbekannter Fehler: \(msg)"
        }
    }
}

// ─── Service ──────────────────────────────────────────────────────────────────

@MainActor
final class TikTokOAuthService: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {

    // The deep-link scheme that the backend redirects to after OAuth.
    // Must match the URL scheme registered in Xcode → Target → Info → URL Types.
    private let callbackURLScheme = "avengrowth"

    private var authSession: ASWebAuthenticationSession?

    // ─── Public API ───────────────────────────────────────────────────────────

    /// Returns true when AVEN_API_URL (or AVENConfig.plist BackendURL) is set.
    func isBackendConfigured() -> Bool {
        AVENBackendConfig.backendURL != nil
    }

    /// Polls the backend to check if TikTok credentials are configured there.
    func checkServerConfiguration() async -> Bool {
        guard let base = AVENBackendConfig.backendURL,
              let url  = URL(string: "\(base)/auth/tiktok/status") else { return false }
        do {
            let (data, res) = try await URLSession.shared.data(from: url)
            guard let http = res as? HTTPURLResponse, http.statusCode == 200 else { return false }
            return (try? JSONDecoder().decode([String: Bool].self, from: data))?["configured"] ?? false
        } catch { return false }
    }

    /// Starts the full TikTok OAuth flow.
    /// Returns `.unconfigured` immediately if the backend URL is not set.
    func connect(profileId: String, token: String) async -> TikTokConnectionState {
        guard let baseURL = AVENBackendConfig.backendURL else {
            return .unconfigured
        }

        switch await initiateOAuth(baseURL: baseURL, profileId: profileId, token: token) {
        case .failure(let err):
            return .error(err)
        case .success(let (authURL, _)):
            // state is encoded inside authURL as a query param by the backend.
            // The backend's callback route validates it — iOS never needs to send it separately.
            return await startWebAuthSession(url: authURL)
        }
    }

    // ─── Private: Initiate ────────────────────────────────────────────────────

    private func initiateOAuth(
        baseURL: String,
        profileId: String,
        token: String
    ) async -> Result<(URL, String), TikTokOAuthError> {
        guard var comps = URLComponents(string: "\(baseURL)/auth/tiktok/initiate") else {
            return .failure(.networkError("Ungültige Backend-URL: \(baseURL)"))
        }
        comps.queryItems = [URLQueryItem(name: "profileId", value: profileId)]
        guard let url = comps.url else {
            return .failure(.networkError("URL konnte nicht erstellt werden"))
        }

        var request       = URLRequest(url: url, timeoutInterval: 8)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure(.networkError("Ungültige Serverantwort"))
            }
            guard http.statusCode == 200 else {
                return .failure(.networkError("Backend antwortete mit Status \(http.statusCode)"))
            }

            struct Body: Decodable {
                let configured: Bool
                let authUrl:    String
                let state:      String
                let message:    String?
            }
            let body = try JSONDecoder().decode(Body.self, from: data)

            guard body.configured else {
                return .failure(.backendNotConfigured)
            }
            guard let authURL = URL(string: body.authUrl) else {
                return .failure(.networkError("Backend lieferte ungültige Auth-URL"))
            }
            return .success((authURL, body.state))

        } catch let urlError as URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .failure(.networkError("Keine Internetverbindung"))
            case .timedOut:
                return .failure(.networkError("Backend antwortet nicht (Timeout)"))
            case .cannotConnectToHost, .cannotFindHost:
                return .failure(.networkError("Backend nicht erreichbar. Läuft der AVEN-Server?"))
            default:
                return .failure(.networkError("Netzwerkfehler: \(urlError.localizedDescription)"))
            }
        } catch {
            return .failure(.networkError("Verbindungsfehler"))
        }
    }

    // ─── Private: ASWebAuthenticationSession ─────────────────────────────────

    private func startWebAuthSession(url: URL) async -> TikTokConnectionState {
        return await withCheckedContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url:                  url,
                callbackURLScheme:    callbackURLScheme
            ) { [weak self] callbackURL, error in
                guard let self else {
                    continuation.resume(returning: .error(.unknown("Session deallocated")))
                    return
                }

                if let asError = error as? ASWebAuthenticationSessionError {
                    switch asError.code {
                    case .canceledLogin:
                        continuation.resume(returning: .error(.userCancelled))
                    default:
                        continuation.resume(returning: .error(.unknown(asError.localizedDescription)))
                    }
                    return
                }
                if let error {
                    continuation.resume(returning: .error(.unknown(error.localizedDescription)))
                    return
                }
                guard let callbackURL else {
                    continuation.resume(returning: .error(.unknown("Kein Callback erhalten")))
                    return
                }

                continuation.resume(returning: self.parseCallback(callbackURL))
            }

            // Allow TikTok to reuse an existing login session (cookies).
            session.prefersEphemeralWebBrowserSession = false
            session.presentationContextProvider = self
            self.authSession = session

            let started = session.start()
            if !started {
                continuation.resume(returning: .error(.unknown("ASWebAuthenticationSession konnte nicht gestartet werden")))
            }
        }
    }

    // ─── Private: Parse deep-link callback ───────────────────────────────────
    //
    // Expected format (from backend):
    //   avengrowth://auth/tiktok/complete?success=true&accountId=...&username=...
    //   avengrowth://auth/tiktok/complete?success=false&error=...

    private func parseCallback(_ url: URL) -> TikTokConnectionState {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = comps.queryItems else {
            return .error(.invalidCallback("Ungültige Callback-URL: \(url.absoluteString)"))
        }

        let params = Dictionary(uniqueKeysWithValues:
            items.compactMap { i -> (String, String)? in
                guard let v = i.value else { return nil }
                return (i.name, v)
            }
        )

        guard params["success"] == "true" else {
            let errCode = params["error"] ?? "unknown"
            switch errCode {
            case "access_denied", "user_cancel":
                return .error(.userCancelled)
            case "invalid_state":
                return .error(.stateMismatch)
            default:
                return .error(.invalidCallback(errCode))
            }
        }

        let accountId = params["accountId"] ?? ""
        let username  = params["username"]  ?? ""
        return .connected(
            username:  username.isEmpty ? "TikTok-Account" : username,
            accountId: accountId
        )
    }

    // ─── ASWebAuthenticationPresentationContextProviding ─────────────────────

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Must return a window — dispatch to main synchronously since this
        // delegate method is called on an arbitrary thread.
        var anchor = ASPresentationAnchor()
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.main.async {
            if let scene  = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first,
               let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first {
                anchor = window
            }
            semaphore.signal()
        }
        semaphore.wait()
        return anchor
    }
}
