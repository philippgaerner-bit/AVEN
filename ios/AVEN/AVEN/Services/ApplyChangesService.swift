import Foundation
import UIKit

// ─── Apply Changes Service ────────────────────────────────────────────────────
//
// Handles "Änderungen anwenden" for scan suggestions.
//
// Demo mode (no TikTok account):
//   - Bio-changes: generates improved text + copies to clipboard, opens TikTok
//   - Content-changes: simulates applied state with confirmation
//
// Real mode (MARK: Integration Points below):
//   - Bio: PATCH https://open.tiktokapis.com/v2/user/info/ (requires user.info.write scope)
//   - Content: deep-link into TikTok creator tools
//
// The service is intentionally stateless. Callers manage applied state in their VM.

enum ApplyChangeCategory: String {
    case bio     = "bio"
    case content = "content"
    case feed    = "feed"
    case brand   = "brand"
    case other   = "other"

    static func from(_ raw: String) -> ApplyChangeCategory {
        ApplyChangeCategory(rawValue: raw.lowercased()) ?? .other
    }
}

enum ApplyChangeResult {
    /// Successfully applied (demo or real)
    case applied(note: String)
    /// Text copied, external app opened
    case copiedAndOpened(text: String, note: String)
    /// Real API call succeeded
    case apiSuccess(note: String)
    /// Requires Pro or connected account
    case requiresUpgrade
    /// Failed
    case failed(String)
}

// MARK: - Integration Point
// To connect real TikTok API: inject a real TikTokAPIClient conforming to TikTokChangeClient.
protocol TikTokChangeClient {
    /// Update bio text via TikTok API (requires user.info.write scope).
    func updateBio(_ text: String, accessToken: String) async throws
}

@MainActor
final class ApplyChangesService {

    // MARK: - Integration Point
    // Inject real client when TikTok is connected:
    //   service.tikTokClient = RealTikTokClient(accessToken: token)
    var tikTokClient: TikTokChangeClient? = nil
    var isConnected: Bool { tikTokClient != nil }

    // ── Entry point ───────────────────────────────────────────────────────────

    func apply(
        suggestion: ScanSuggestion,
        result: ScanAnalysisResult
    ) async -> ApplyChangeResult {

        let cat = ApplyChangeCategory.from(suggestion.category)

        if isConnected {
            return await applyReal(suggestion: suggestion, category: cat, result: result)
        } else {
            return applyDemo(suggestion: suggestion, category: cat, result: result)
        }
    }

    // ── Demo mode ─────────────────────────────────────────────────────────────

    private func applyDemo(
        suggestion: ScanSuggestion,
        category: ApplyChangeCategory,
        result: ScanAnalysisResult
    ) -> ApplyChangeResult {

        switch category {
        case .bio:
            let improved = generateImprovedBio(from: suggestion, platform: result.platform)
            // 1. Copy to clipboard immediately
            UIPasteboard.general.string = improved
            // 2. Open TikTok after a short delay so the clipboard write completes
            let tiktokApp  = URL(string: "tiktok://")!
            let tiktokEdit = URL(string: "tiktok://profile/edit")!
            let tiktokWeb  = URL(string: "https://www.tiktok.com")!
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if UIApplication.shared.canOpenURL(tiktokApp) {
                    // Try profile-edit deep link; fall back to app root if unsupported
                    UIApplication.shared.open(tiktokEdit) { success in
                        if !success {
                            UIApplication.shared.open(tiktokApp)
                        }
                    }
                } else {
                    UIApplication.shared.open(tiktokWeb)
                }
            }
            return .copiedAndOpened(
                text: improved,
                note: "Text kopiert ✓  TikTok wird geöffnet – füge den Text in deiner Bio ein."
            )

        case .content:
            // Simulate: in real mode this would trigger TikTok creator tools
            return .applied(note: "Tipp gespeichert. Wende ihn bei deinem nächsten Video an.")

        case .feed, .brand:
            return .applied(note: "Empfehlung gespeichert. Setze sie beim nächsten Post um.")

        default:
            return .applied(note: "Änderung als Aufgabe im Aktionsplan gespeichert.")
        }
    }

    // ── Real mode (TikTok API) ────────────────────────────────────────────────

    private func applyReal(
        suggestion: ScanSuggestion,
        category: ApplyChangeCategory,
        result: ScanAnalysisResult
    ) async -> ApplyChangeResult {

        guard let client = tikTokClient else {
            return applyDemo(suggestion: suggestion, category: category, result: result)
        }

        switch category {
        case .bio:
            // MARK: - Real TikTok Bio Update
            // Requires Login Kit scope: user.info.write
            let improved = generateImprovedBio(from: suggestion, platform: result.platform)
            do {
                // MARK: Integration Point — inject real accessToken
                try await client.updateBio(improved, accessToken: "")
                UIPasteboard.general.string = improved
                return .apiSuccess(note: "Bio wurde direkt in deinem TikTok-Profil aktualisiert.")
            } catch {
                // Fall back to copy-and-open
                UIPasteboard.general.string = improved
                return .copiedAndOpened(
                    text: improved,
                    note: "API-Update fehlgeschlagen. Bio in Zwischenablage kopiert."
                )
            }

        default:
            return applyDemo(suggestion: suggestion, category: category, result: result)
        }
    }

    // ── Bio text generator ────────────────────────────────────────────────────

    private func generateImprovedBio(
        from suggestion: ScanSuggestion,
        platform: ConnectedProfile.SocialPlatform
    ) -> String {
        // Extract the optimized bio from the suggestion detail if it contains one.
        // The detail follows the pattern "...\n\"<bio>\"\n..." — extract quoted text after "Optimierte Bio-Vorlage:" or "Beispiel-Bio:"
        let detail = suggestion.detail
        let lines  = detail.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Look for a quoted bio on its own line
            if trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"") && trimmed.count > 5 {
                return String(trimmed.dropFirst().dropLast())
            }
            // Or the line after "Optimierte" / "Beispiel"
        }
        // Fallback if no quote found
        let emoji: String = platform == .tiktok ? "🎯" : "✨"
        return "\(emoji) [Zielgruppe] + [konkretes Versprechen] | Link unten ↓"
    }
}
