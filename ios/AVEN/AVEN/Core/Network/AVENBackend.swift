import Foundation
import UIKit
import Vision

// ─── AVENBackend ──────────────────────────────────────────────────────────────
// Single gateway to the AVEN Cloudflare Worker backend.
// The Worker holds the Anthropic API key — no key is ever stored in the app.
// All 4 AI endpoints route through here.

struct AVENBackend {

    // ── Base URL from plist ────────────────────────────────────────────────────
    static var baseURL: String {
        if let path = Bundle.main.path(forResource: "AVENConfig", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let url = plist["BackendURL"] as? String, !url.isEmpty {
            return url.hasSuffix("/") ? String(url.dropLast()) : url
        }
        return "https://muddy-fire-2876.philipp-gaerner.workers.dev"
    }

    // ── Shared URLSession ──────────────────────────────────────────────────────
    static let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest  = 60
        cfg.timeoutIntervalForResource = 120
        return URLSession(configuration: cfg)
    }()

    // ── Generic POST ──────────────────────────────────────────────────────────
    static func post(endpoint: String, body: [String: Any]) async throws -> [String: Any] {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw AVENBackendError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
            // Try to extract error message
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = json["error"] as? String {
                throw AVENBackendError.serverError(msg)
            }
            throw AVENBackendError.httpError(http.statusCode)
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AVENBackendError.invalidResponse
        }
        return json
    }

    // ── Multipart POST (for video upload) ─────────────────────────────────────
    static func postMultipart(endpoint: String,
                              fields: [String: String],
                              fileData: Data,
                              filename: String,
                              mimeType: String) async throws -> [String: Any] {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw AVENBackendError.invalidURL
        }
        let boundary = "AVENBoundary-\(UUID().uuidString)"
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        for (k, v) in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(k)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(v)\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
            throw AVENBackendError.httpError(http.statusCode)
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AVENBackendError.invalidResponse
        }
        return json
    }
}

// ─── Errors ────────────────────────────────────────────────────────────────────

enum AVENBackendError: LocalizedError {
    case invalidURL
    case httpError(Int)
    case serverError(String)
    case invalidResponse
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:        return "Ungültige Backend-URL."
        case .httpError(let c):  return "Server-Fehler \(c). Bitte versuche es erneut."
        case .serverError(let m): return m
        case .invalidResponse:   return "Ungültige Antwort vom Server."
        case .noData:            return "Keine Daten empfangen."
        }
    }
}

// ─── /profile-analysis ────────────────────────────────────────────────────────

struct ProfileAnalysisRequest {
    let imageBase64: String    // JPEG compressed, base64
    let platform:    String    // "tiktok" | "instagram"
}

struct ProfileAnalysisResponse {
    let score:       Int
    let status:      String
    let handle:      String?
    let displayName: String?
    let bio:         String?
    let hasCTA:      Bool
    let hasEmoji:    Bool
    let hasKeyword:  Bool
    let follower:    Int?
    let strengths:   [String]
    let weaknesses:  [String]
    let bioSuggestion: String?
    let dimensions:  [[String: Any]]
    let rawJSON:     [String: Any]

    init(json: [String: Any]) {
        score       = json["score"]        as? Int    ?? 50
        status      = json["status"]       as? String ?? "Analysiert"
        handle      = json["handle"]       as? String
        displayName = json["displayName"]  as? String
        bio         = json["bio"]          as? String
        hasCTA      = json["hasCTA"]       as? Bool   ?? false
        hasEmoji    = json["hasEmoji"]     as? Bool   ?? false
        hasKeyword  = json["hasKeyword"]   as? Bool   ?? false
        follower    = json["follower"]     as? Int
        strengths   = json["strengths"]    as? [String] ?? []
        weaknesses  = json["weaknesses"]   as? [String] ?? []
        bioSuggestion = json["bioSuggestion"] as? String
        dimensions  = json["dimensions"]   as? [[String: Any]] ?? []
        rawJSON     = json
    }
}

extension AVENBackend {
    static func analyzeProfile(_ req: ProfileAnalysisRequest) async throws -> ProfileAnalysisResponse {
        let body: [String: Any] = [
            "image":    req.imageBase64,
            "platform": req.platform,
        ]
        let json = try await post(endpoint: "/profile-analysis", body: body)
        return ProfileAnalysisResponse(json: json)
    }
}

// ─── /video-analysis ──────────────────────────────────────────────────────────

struct VideoAnalysisResponse {
    let overallScore: Int
    let hookScore:    Int
    let structScore:  Int
    let ctaScore:     Int
    let lengthScore:  Int
    let strengths:    [String]
    let weaknesses:   [String]
    let tips:         [String]
    let durationSec:  Double

    init(json: [String: Any], localDuration: Double) {
        overallScore = json["overallScore"] as? Int ?? 60
        hookScore    = json["hookScore"]    as? Int ?? 60
        structScore  = json["structScore"]  as? Int ?? 60
        ctaScore     = json["ctaScore"]     as? Int ?? 60
        lengthScore  = json["lengthScore"]  as? Int ?? 60
        strengths    = json["strengths"]    as? [String] ?? []
        weaknesses   = json["weaknesses"]   as? [String] ?? []
        tips         = json["tips"]         as? [String] ?? []
        durationSec  = json["durationSec"]  as? Double ?? localDuration
    }
}

extension AVENBackend {
    /// Sends up to 4 extracted frame images + duration to the backend for analysis.
    /// Falls back to client-side frame analysis when the backend is unavailable.
    static func analyzeVideo(frames: [UIImage], durationSec: Double) async throws -> VideoAnalysisResponse {
        // Compress frames to JPEG base64
        let frameB64s: [String] = frames.compactMap { img in
            img.jpegData(compressionQuality: 0.5)?.base64EncodedString()
        }
        let body: [String: Any] = [
            "frames":      frameB64s,
            "durationSec": durationSec,
        ]
        let json = try await post(endpoint: "/video-analysis", body: body)
        return VideoAnalysisResponse(json: json, localDuration: durationSec)
    }
}

// ─── /video-blueprint ─────────────────────────────────────────────────────────

struct VideoBlueprintRequest {
    let topic:     String
    let platform:  String
    let style:     String
    let seconds:   Int       // 1–90
}

struct VideoBlueprintResponse {
    let hook:     String
    let script:   String
    let scenes:   [[String: String]]   // [{label, description, duration}]
    let cta:      String
    let caption:  String
    let hashtags: [String]

    init(json: [String: Any]) {
        hook     = json["hook"]     as? String   ?? ""
        script   = json["script"]   as? String   ?? ""
        scenes   = json["scenes"]   as? [[String: String]] ?? []
        cta      = json["cta"]      as? String   ?? ""
        caption  = json["caption"]  as? String   ?? ""
        hashtags = json["hashtags"] as? [String] ?? []
    }
}

extension AVENBackend {
    static func generateBlueprint(_ req: VideoBlueprintRequest) async throws -> VideoBlueprintResponse {
        let body: [String: Any] = [
            "topic":    req.topic,
            "platform": req.platform,
            "style":    req.style,
            "seconds":  min(90, max(1, req.seconds)),
        ]
        let json = try await post(endpoint: "/video-blueprint", body: body)
        return VideoBlueprintResponse(json: json)
    }
}

// ─── /coach ───────────────────────────────────────────────────────────────────

struct CoachRequest {
    let question:   String
    let imageB64:   String?    // optional profile screenshot
    let avenContext: String    // pre-built context string (score, weaknesses, etc.)
    let history:    [[String: String]]   // [{role, content}]
}

extension AVENBackend {
    static func askCoach(_ req: CoachRequest) async throws -> String {
        var body: [String: Any] = [
            "question":    req.question,
            "avenContext": req.avenContext,
            "history":     req.history,
        ]
        if let img = req.imageB64 { body["image"] = img }
        let json = try await post(endpoint: "/coach", body: body)
        return json["reply"] as? String ?? "Keine Antwort erhalten."
    }
}
