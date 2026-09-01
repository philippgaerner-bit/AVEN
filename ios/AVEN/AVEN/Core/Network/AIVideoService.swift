import Foundation

// ─── AI Video models ──────────────────────────────────────────────────────────

enum VideoPlatform: String, CaseIterable {
    case tiktok    = "TikTok"
    case reels     = "Instagram Reels"
    case shorts    = "YouTube Shorts"

    var icon: String {
        switch self {
        case .tiktok:  return "play.rectangle.fill"
        case .reels:   return "camera.fill"
        case .shorts:  return "play.circle.fill"
        }
    }
}

enum VideoStyle: String, CaseIterable {
    case clean        = "Clean"
    case viral        = "Viral"
    case storytelling = "Storytelling"
    case educational  = "Educational"
    case cinematic    = "Cinematic"

    var description: String {
        switch self {
        case .clean:        return "Minimalistisch, klar, professionell"
        case .viral:        return "Energetisch, trendy, aufmerksamkeitsstark"
        case .storytelling: return "Narrativ, emotional, mitreißend"
        case .educational:  return "Informativ, strukturiert, wertvoll"
        case .cinematic:    return "Visuell stark, atmosphärisch, hochwertig"
        }
    }
}

enum VideoDuration: String, CaseIterable {
    case short  = "15 Sek"
    case medium = "30 Sek"
    case long   = "60 Sek"

    var seconds: Int {
        switch self { case .short: return 15; case .medium: return 30; case .long: return 60 }
    }
}

struct AIVideoRequest {
    let platform:     VideoPlatform
    let topic:        String
    let style:        VideoStyle
    let duration:     VideoDuration
    let fromInsights: Bool
    var customSeconds: Int = 0   // 0 = use duration.seconds; >0 = user-specified
}

struct AIVideoConceptScene: Identifiable {
    let id   = UUID()
    let number: Int
    let label: String
    let description: String
    let duration: String
}

struct AIVideoConcept {
    let platform:   VideoPlatform
    let style:      VideoStyle
    let duration:   VideoDuration
    let hook:       String
    let script:     String
    let caption:    String
    let cta:        String
    let scenes:     [AIVideoConceptScene]
    let hashtags:   [String]
    // NOTE: This is a CONCEPT only — no actual video file is generated
    let generatedAt: Date

    /// Full formatted blueprint for copying to clipboard or sending to a video AI
    var blueprintText: String {
        var lines: [String] = []
        lines.append("🎬 VIDEO BLUEPRINT")
        lines.append("Plattform: \(platform.rawValue) | Stil: \(style.rawValue) | Länge: \(duration.seconds)s")
        lines.append("")
        lines.append("HOOK:")
        lines.append(hook)
        lines.append("")
        lines.append("SZENEN:")
        for (i, scene) in scenes.enumerated() {
            lines.append("Szene \(i+1) [\(scene.duration)] – \(scene.label): \(scene.description)")
        }
        lines.append("")
        lines.append("SPEAKER-SKRIPT:")
        lines.append(script)
        lines.append("")
        lines.append("CTA:")
        lines.append(cta)
        lines.append("")
        lines.append("CAPTION:")
        lines.append(caption)
        if !hashtags.isEmpty {
            lines.append("")
            lines.append("HASHTAGS: " + hashtags.map { "#\($0)" }.joined(separator: " "))
        }
        return lines.joined(separator: "\n")
    }
}

// ─── Service ──────────────────────────────────────────────────────────────────

protocol AIVideoServiceProtocol {
    func generateConcept(request: AIVideoRequest) async throws -> AIVideoConcept
}

final class LiveAIVideoService: AIVideoServiceProtocol {
    func generateConcept(request: AIVideoRequest) async throws -> AIVideoConcept {
        let topic = request.topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !topic.isEmpty else { throw AVENBackendError.validation("Bitte gib zuerst ein Thema für dein Video ein.") }
        let seconds = request.customSeconds > 0 ? request.customSeconds : request.duration.seconds
        let resp = try await AVENBackend.generateBlueprint(VideoBlueprintRequest(
            topic: topic,
            platform: request.platform.rawValue,
            style: request.style.rawValue,
            seconds: seconds
        ))
        guard !resp.hook.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !resp.script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !resp.cta.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !resp.scenes.isEmpty else {
            throw AVENBackendError.validation("Der AVEN-Server hat keinen vollständigen Video-Blueprint geliefert.")
        }
        let scenes = resp.scenes.enumerated().compactMap { idx, raw -> AIVideoConceptScene? in
            let description = (raw["description"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !description.isEmpty else { return nil }
            return AIVideoConceptScene(
                number: idx + 1,
                label: raw["label"] ?? "Szene \(idx + 1)",
                description: description,
                duration: raw["duration"] ?? ""
            )
        }
        guard !scenes.isEmpty else { throw AVENBackendError.validation("Der Video-Blueprint enthält keine verwertbaren Szenen.") }
        return AIVideoConcept(
            platform: request.platform,
            style: request.style,
            duration: request.duration,
            hook: resp.hook,
            script: resp.script,
            caption: resp.caption,
            cta: resp.cta,
            scenes: scenes,
            hashtags: resp.hashtags,
            generatedAt: Date()
        )
    }
}

// ─── Video Render models ──────────────────────────────────────────────────────

/// Status of an asynchronous video render job
enum VideoRenderStatus: Equatable {
    case queued
    case processing(progressPercent: Double)
    case completed(videoURL: URL)
    case failed(String)
}

/// Result returned once rendering is complete
struct VideoRenderResult {
    let videoURL:   URL
    let thumbnailURL: URL?
    let duration:   Double   // seconds
    let platform:   VideoPlatform
}

// ─── Video render service protocol ───────────────────────────────────────────
//
// Architecture: The iOS app sends the AIVideoConcept to the AVEN backend.
// The backend calls the chosen video-generation provider (e.g. Runway ML Gen-3,
// Kling AI, or Pika 2.0), then polls until complete and returns the video URL.
//
// Secrets (provider API keys) are kept on the backend only.
// The iOS app never holds any provider credential.

protocol AVENVideoRenderServiceProtocol {
    /// Submit a concept for video generation. Returns a job ID.
    func submitRenderJob(concept: AIVideoConcept, backendBaseURL: String, authToken: String) async throws -> String
    /// Poll the backend for render job status.
    func pollJobStatus(jobId: String, backendBaseURL: String, authToken: String) async throws -> VideoRenderStatus
    /// Cancel a pending render job.
    func cancelJob(jobId: String, backendBaseURL: String, authToken: String) async throws
}

// ─── Backend-proxied render service ──────────────────────────────────────────
//
// Calls AVEN backend endpoints:
//   POST /video/render        – submit job
//   GET  /video/render/:id    – poll status
//   DELETE /video/render/:id  – cancel
//
// The backend then communicates with the actual video provider (Runway ML etc.)

final class BackendVideoRenderService: AVENVideoRenderServiceProtocol {

    func submitRenderJob(
        concept: AIVideoConcept,
        backendBaseURL: String,
        authToken: String
    ) async throws -> String {
        guard let url = URL(string: "\(backendBaseURL)/video/render") else {
            throw VideoRenderError.backendNotConfigured
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let payload: [String: Any] = [
            "platform":  concept.platform.rawValue,
            "style":     concept.style.rawValue,
            "duration":  concept.duration.seconds,
            "hook":      concept.hook,
            "script":    concept.script,
            "scenes":    concept.scenes.map { ["label": $0.label, "description": $0.description, "duration": $0.duration] },
            "caption":   concept.caption,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 201 || http.statusCode == 200 else {
            throw VideoRenderError.serverError("Backend antwortete mit Fehler")
        }
        let json = try JSONDecoder().decode([String: String].self, from: data)
        guard let jobId = json["jobId"] else { throw VideoRenderError.serverError("Keine Job-ID erhalten") }
        return jobId
    }

    func pollJobStatus(
        jobId: String,
        backendBaseURL: String,
        authToken: String
    ) async throws -> VideoRenderStatus {
        guard let url = URL(string: "\(backendBaseURL)/video/render/\(jobId)") else {
            throw VideoRenderError.backendNotConfigured
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw VideoRenderError.serverError("Status-Abfrage fehlgeschlagen")
        }

        struct StatusResponse: Decodable {
            let status:   String
            let progress: Double?
            let videoURL: String?
            let error:    String?
        }
        let body = try JSONDecoder().decode(StatusResponse.self, from: data)
        switch body.status {
        case "queued":     return .queued
        case "processing": return .processing(progressPercent: body.progress ?? 0)
        case "completed":
            guard let urlStr = body.videoURL, let url = URL(string: urlStr) else {
                throw VideoRenderError.serverError("Keine Video-URL erhalten")
            }
            return .completed(videoURL: url)
        case "failed":
            return .failed(body.error ?? "Generierung fehlgeschlagen")
        default:
            return .processing(progressPercent: body.progress ?? 0)
        }
    }

    func cancelJob(jobId: String, backendBaseURL: String, authToken: String) async throws {
        guard let url = URL(string: "\(backendBaseURL)/video/render/\(jobId)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        _ = try? await URLSession.shared.data(for: request)
    }
}

// ─── Error types ──────────────────────────────────────────────────────────────

enum VideoRenderError: Error, LocalizedError {
    case backendNotConfigured
    case serverError(String)
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .backendNotConfigured:
            return "AVEN-Backend nicht erreichbar. Setze AVEN_API_URL in den Xcode-Umgebungsvariablen."
        case .serverError(let msg):
            return msg
        case .notConfigured:
            return "Video-Generierung ist noch nicht konfiguriert."
        }
    }
}
