import Foundation
import AuthenticationServices
import Security

// ─── AVENAuthService ──────────────────────────────────────────────────────────
// Manages Sign in with Apple for AVEN.
// Persists the Apple credential in Keychain so login survives app restarts.
// Does NOT affect TikTok OAuth, StoreKit, or any other AVEN subsystem.
//
// Concurrency note:
// The class is @MainActor-isolated. Delegate callbacks from Apple's framework
// arrive on an arbitrary thread; we hop back to MainActor with
// Task { @MainActor in } before touching any isolated state.

@MainActor
final class AVENAuthService: NSObject, ObservableObject {

    // ── Published state ────────────────────────────────────────────────────────
    @Published private(set) var isSignedIn:   Bool   = false
    @Published private(set) var displayName:  String = ""
    @Published private(set) var userEmail:    String = ""
    @Published private(set) var userID:       String = ""
    @Published var showDeleteConfirm:         Bool   = false
    @Published var isLoading:                 Bool   = false
    @Published var error:                     String = ""

    // ── Keychain keys ──────────────────────────────────────────────────────────
    private let keychainService = "com.aven.app.auth"
    private let kcUserID        = "apple.userID"
    private let kcDisplayName   = "apple.displayName"
    private let kcEmail         = "apple.email"

    // Continuation for Sign In flow — only ever accessed on MainActor
    private var signInContinuation: CheckedContinuation<ASAuthorization, Error>?

    // ── Init ──────────────────────────────────────────────────────────────────
    override init() {
        super.init()
        restoreSession()
    }

    // ── Sign In with Apple ────────────────────────────────────────────────────
    func signInWithApple() async {
        isLoading = true; error = ""
        do {
            let auth: ASAuthorization = try await withCheckedThrowingContinuation { cont in
                // Already on MainActor — safe to write signInContinuation
                self.signInContinuation = cont
                let provider   = ASAuthorizationAppleIDProvider()
                let request    = provider.createRequest()
                request.requestedScopes = [.fullName, .email]
                let controller = ASAuthorizationController(authorizationRequests: [request])
                controller.delegate                    = self
                controller.presentationContextProvider = self
                controller.performRequests()
            }
            handleAuthorization(auth)
        } catch let appleErr as ASAuthorizationError where appleErr.code == .canceled {
            // User cancelled — not an error
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    // ── Restore session on launch ─────────────────────────────────────────────
    func restoreSession() {
        guard let uid = keychainLoad(key: kcUserID), !uid.isEmpty else { return }
        let provider = ASAuthorizationAppleIDProvider()
        let displayNameCopy = keychainLoad(key: kcDisplayName) ?? ""
        let emailCopy       = keychainLoad(key: kcEmail) ?? ""
        // getCredentialState calls back on an arbitrary thread
        provider.getCredentialState(forUserID: uid) { [weak self] state, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch state {
                case .authorized:
                    self.userID      = uid
                    self.displayName = displayNameCopy
                    self.userEmail   = emailCopy
                    self.isSignedIn  = true
                case .revoked, .notFound:
                    self.clearKeychainData()
                default:
                    break
                }
            }
        }
    }

    // ── Logout ────────────────────────────────────────────────────────────────
    func logout() {
        clearKeychainData()
        isSignedIn  = false
        displayName = ""
        userEmail   = ""
        userID      = ""
    }

    // ── Delete Account ────────────────────────────────────────────────────────
    func deleteAccount() async {
        isLoading = true
        clearKeychainData()
        UserDefaults.standard.removeObject(forKey: "aven.coach.chatHistory")
        isSignedIn  = false
        displayName = ""
        userEmail   = ""
        userID      = ""
        isLoading   = false
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private func handleAuthorization(_ auth: ASAuthorization) {
        guard let cred = auth.credential as? ASAuthorizationAppleIDCredential else { return }
        let uid   = cred.user
        let name  = [cred.fullName?.givenName, cred.fullName?.familyName]
            .compactMap { $0 }.joined(separator: " ")
        let email = cred.email ?? ""

        keychainSave(key: kcUserID, value: uid)
        if !name.isEmpty  { keychainSave(key: kcDisplayName, value: name)  }
        if !email.isEmpty { keychainSave(key: kcEmail,       value: email) }

        userID      = uid
        displayName = name.isEmpty  ? (keychainLoad(key: kcDisplayName) ?? "Apple-Nutzer") : name
        userEmail   = email.isEmpty ? (keychainLoad(key: kcEmail)       ?? "") : email
        isSignedIn  = true
    }

    private func clearKeychainData() {
        [kcUserID, kcDisplayName, kcEmail].forEach { keychainDelete(key: $0) }
    }

    // ── Keychain ──────────────────────────────────────────────────────────────

    private func keychainSave(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [kSecClass as String:       kSecClassGenericPassword,
                                    kSecAttrService as String: keychainService,
                                    kSecAttrAccount as String: key]
        SecItemDelete(query as CFDictionary)
        var attrs = query; attrs[kSecValueData as String] = data
        SecItemAdd(attrs as CFDictionary, nil)
    }

    private func keychainLoad(key: String) -> String? {
        let query: [String: Any] = [kSecClass as String:       kSecClassGenericPassword,
                                    kSecAttrService as String: keychainService,
                                    kSecAttrAccount as String: key,
                                    kSecReturnData as String:  true,
                                    kSecMatchLimit as String:  kSecMatchLimitOne]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func keychainDelete(key: String) {
        let query: [String: Any] = [kSecClass as String:       kSecClassGenericPassword,
                                    kSecAttrService as String: keychainService,
                                    kSecAttrAccount as String: key]
        SecItemDelete(query as CFDictionary)
    }
}

// ─── ASAuthorizationControllerDelegate ────────────────────────────────────────
// NOTE: We do NOT mark these nonisolated.
// Apple calls these callbacks on an arbitrary thread.
// We use Task { @MainActor in } to safely hop to the MainActor before
// reading or mutating signInContinuation.

extension AVENAuthService: ASAuthorizationControllerDelegate {

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            self.signInContinuation?.resume(returning: authorization)
            self.signInContinuation = nil
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            self.signInContinuation?.resume(throwing: error)
            self.signInContinuation = nil
        }
    }
}

// ─── ASAuthorizationControllerPresentationContextProviding ────────────────────

extension AVENAuthService: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // presentationAnchor is fine as nonisolated — no isolated state accessed
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first(where: \.isKeyWindow) ?? UIWindow()
    }
}
