import Foundation
import UIKit
import AVFoundation


// MARK: - Diagnostics

enum AVENBackendDiagnostics {
    private static let endpointKey = "aven.ai.lastEndpoint"
    private static let successKey = "aven.ai.lastSuccess"
    private static let errorKey = "aven.ai.lastError"

    static var lastEndpoint: String { UserDefaults.standard.string(forKey: endpointKey) ?? "" }
    static var lastSuccess: Date? { UserDefaults.standard.object(forKey: successKey) as? Date }
    static var lastError: String { UserDefaults.standard.string(forKey: errorKey) ?? "" }

    static func success(_ endpoint: String) {
        UserDefaults.standard.set(endpoint, forKey: endpointKey)
        UserDefaults.standard.set(Date(), forKey: successKey)
        UserDefaults.standard.removeObject(forKey: errorKey)
    }

    static func failure(_ endpoint: String, _ message: String) {
        UserDefaults.standard.set(endpoint, forKey: endpointKey)
        UserDefaults.standard.set(message, forKey: errorKey)
    }
}

// MARK: - AVENBackend
// Central gateway for AVEN's AI endpoints. API secrets stay in the Cloudflare Worker.
// TikTok OAuth intentionally keeps using BackendURL; AI uses AIBackendURL so the
// two backends cannot accidentally overwrite each other.

struct AVENBackend {
    static var baseURL: String {
        if let path = Bundle.main.path(forResource: "AVENConfig", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let raw = plist["AIBackendURL"] as? String,
           !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return raw.hasSuffix("/") ? String(raw.dropLast()) : raw
        }
        return "https://avencreator.app"
    }

    static let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 60
        cfg.timeoutIntervalForResource = 120
        return URLSession(configuration: cfg)
    }()

    static func post(endpoint: String, body: [String: Any]) async throws -> [String: Any] {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else { throw AVENBackendError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        do {
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse else {
                AVENBackendDiagnostics.failure(endpoint, "Keine HTTP-Antwort")
                throw AVENBackendError.invalidResponse
            }
            guard (200..<300).contains(http.statusCode) else {
                let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
                let error = msg ?? "Server-Fehler \(http.statusCode)."
                AVENBackendDiagnostics.failure(endpoint, error)
                throw AVENBackendError.serverError(error)
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                AVENBackendDiagnostics.failure(endpoint, "Ungültige JSON-Antwort")
                throw AVENBackendError.invalidResponse
            }
            AVENBackendDiagnostics.success(endpoint)
            return json
        } catch {
            if AVENBackendDiagnostics.lastError.isEmpty {
                AVENBackendDiagnostics.failure(endpoint, error.localizedDescription)
            }
            throw error
        }
    }
}

enum AVENBackendError: LocalizedError {
    case invalidURL, invalidResponse, noData
    case serverError(String)
    case validation(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Ungültige Backend-URL."
        case .invalidResponse: return "Ungültige Antwort vom AVEN-Server."
        case .noData: return "Keine Daten empfangen."
        case .serverError(let msg), .validation(let msg): return msg
        }
    }
}

// MARK: - Shared AI Context

struct AVENAIContextBuilder {
    static func make(account: ConnectedTikTokAccount?, analysis: AnalysisRecord?) -> String {
        var parts: [String] = []
        if let account {
            parts.append("TikTok: \(account.username), \(account.followers) Follower, \(account.following) Following, \(account.likes) Likes, \(account.videoCount) Videos")
        }
        if let analysis {
            parts.append("Letzter AVEN Score: \(analysis.analysisScore)/100")
            if !analysis.strengths.isEmpty { parts.append("Stärken: \(analysis.strengths.prefix(3).joined(separator: "; "))") }
            if !analysis.weaknesses.isEmpty { parts.append("Potenziale: \(analysis.weaknesses.prefix(3).joined(separator: "; "))") }
        }
        if let goal = AVENUserGoalStore.current {
            var goalText = "Wachstumsziel: \(goal.title) – Zielwert \(goal.target) \(goal.unit)"
            if !goal.deadline.isEmpty { goalText += " in \(goal.deadline)" }
            if !goal.current.isEmpty { goalText += "; aktueller Wert \(goal.current)" }
            parts.append(goalText)
        }
        return parts.joined(separator: "\n")
    }
}

// MARK: - AI Coach

extension AVENBackend {
    static func askCoach(question: String, history: [[String: String]], avenContext: String) async throws -> String {
        let json = try await post(endpoint: "/coach", body: [
            "question": question,
            "history": history,
            "avenContext": avenContext
        ])
        guard let reply = json["reply"] as? String,
              !reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AVENBackendError.validation("Der AI Coach hat keine verwertbare Antwort geliefert.")
        }
        return reply
    }

    /// The /coach endpoint is conversational by default. For app-internal flows
    /// that need structured data, request JSON and automatically repair/retry once
    /// if the first model answer contains prose or malformed JSON.
    static func askCoachForJSONObject(
        question: String,
        avenContext: String,
        schemaHint: String,
        diagnosticLabel: String
    ) async throws -> [String: Any] {
        let firstReply = try await askCoach(question: question, history: [], avenContext: avenContext)
        if let root = decodeJSONObject(from: firstReply) {
            AVENBackendDiagnostics.success("/coach · \(diagnosticLabel)")
            return root
        }

        let clipped = String(firstReply.prefix(6_000))
        let repairQuestion = """
        Deine vorherige Antwort konnte von der AVEN App nicht als JSON gelesen werden.
        Formatiere den Inhalt jetzt NEU und antworte AUSSCHLIESSLICH mit einem einzigen validen JSON-Objekt.
        Kein Markdown, keine Code-Fences, kein Text davor oder danach.

        Exaktes Schema:
        \(schemaHint)

        Vorherige Antwort, deren Inhalt du in dieses Schema überführen sollst:
        \(clipped)
        """

        let repairedReply = try await askCoach(question: repairQuestion, history: [], avenContext: avenContext)
        guard let root = decodeJSONObject(from: repairedReply) else {
            AVENBackendDiagnostics.failure("/coach · \(diagnosticLabel)", "Die KI-Antwort war auch nach automatischer Reparatur nicht als JSON lesbar.")
            throw AVENBackendError.validation("AVEN AI konnte die Antwort nicht sauber strukturieren. Bitte erneut analysieren.")
        }
        AVENBackendDiagnostics.success("/coach · \(diagnosticLabel)")
        return root
    }

    private static func decodeJSONObject(from text: String) -> [String: Any]? {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```JSON", with: "")
            .replacingOccurrences(of: "```", with: "")
            .replacingOccurrences(of: "“", with: "\"")
            .replacingOccurrences(of: "”", with: "\"")
            .replacingOccurrences(of: "’", with: "'")

        guard let start = cleaned.firstIndex(of: "{"),
              let end = cleaned.lastIndex(of: "}"),
              start <= end else { return nil }
        cleaned = String(cleaned[start...end])

        guard let data = cleaned.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return root
    }
}


// MARK: - AI-refined profile analysis + action plan

struct AVENAIProfileReview {
    let summary: String
    let strengths: [String]
    let weaknesses: [String]
    let recommendedBio: String?
    let tasks: [AVENAIPlanTask]
}

extension AVENBackend {
    /// Uses the local Vision/OCR result as evidence, then asks AVEN AI to rewrite
    /// the analysis into specific, useful feedback and a concrete action plan.
    /// The score itself is never invented or changed by AI.
    static func generateProfileReview(record: AnalysisRecord,
                                      localResult: ScanAnalysisResult,
                                      account: ConnectedTikTokAccount?) async throws -> AVENAIProfileReview {
        var evidence: [String] = []
        evidence.append("Plattform: \(record.platform)")
        evidence.append("Lokaler AVEN Score: \(record.analysisScore)/100 (darf NICHT verändert werden)")
        for dimension in record.dimensions {
            let positive = dimension.positives.joined(separator: "; ")
            let negative = dimension.negatives.joined(separator: "; ")
            evidence.append("Bereich \(dimension.name): Score \(dimension.score). Positiv: \(positive.isEmpty ? "nichts sicher erkannt" : positive). Problem: \(negative.isEmpty ? "nichts sicher erkannt" : negative). Lokaler Tipp: \(dimension.tip)")
        }
        if !localResult.suggestions.isEmpty {
            evidence.append("Lokale Vorschläge: " + localResult.suggestions.map { "\($0.title): \($0.detail)" }.joined(separator: " | "))
        }
        if !localResult.recommendedBio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            evidence.append("Lokaler Bio-Entwurf: \(localResult.recommendedBio)")
        }

        var context = AVENAIContextBuilder.make(account: account, analysis: record)
        context += "\n\nEVIDENZ AUS DER AKTUELLEN PROFILANALYSE:\n" + evidence.joined(separator: "\n")

        let schema = """
        {"summary":"kurzer Satz","strengths":["..."],"weaknesses":["..."],"recommendedBio":"","tasks":[{"title":"...","detail":"...","priority":"high","category":"content","xp":40,"requiresProof":true}]}
        """

        let question = """
        Du bist der persönliche TikTok Growth Coach in AVEN. Verfeinere die aktuelle Profilanalyse ausschließlich anhand der EVIDENZ im Kontext.

        REGELN FÜR DIE ANALYSE:
        - Verändere den AVEN Score NICHT.
        - Erfinde KEINE Views, Watchtime, Retention, Engagementrate, Zielgruppe oder Profilbestandteile.
        - Jede Stärke und jede Schwäche muss direkt auf der aktuellen Evidenz beruhen.
        - Wenn etwas nicht sicher erkennbar ist, nenne es NICHT als Schwäche.
        - Maximal 3 relevante Stärken und maximal 3 relevante Verbesserungen.
        - Keine pauschalen Algorithmus-Behauptungen wie "TikTok kann dich nicht einordnen".
        - Eine neue Bio nur dann liefern, wenn die Bio laut Evidenz wirklich unklar oder schwach ist. Sonst recommendedBio leer lassen.

        REGELN FÜR DEN AKTIONSPLAN:
        - Erstelle 4 bis 6 konkrete Aufgaben, sofern die Evidenz genug hergibt.
        - Maximal 2 Aufgaben dürfen reine Bio-/Profil-Kosmetik sein. Ähnliche Bio-Probleme zu EINER Aufgabe zusammenfassen.
        - Wenn ein Wachstumsziel vorhanden ist, muss mindestens 1 Aufgabe direkt darauf einzahlen.
        - Wenn sinnvoll, mindestens 1 Content-Aufgabe mit konkretem Test, z. B. 3 Hooks testen oder 3 Videos mit klarer Struktur veröffentlichen.
        - Keine reine "Emojis hinzufügen"-Aufgabe, außer die Lesbarkeit ist laut Evidenz tatsächlich ein Problem.
        - Jede Aufgabe braucht ein klares Erledigt-Kriterium. Keine leeren Tipps.
        - Keine garantierten Wachstumsversprechen. Formuliere Tests und konkrete Handlungen, keine erfundenen Resultate.

        Antworte AUSSCHLIESSLICH als valides JSON ohne Markdown im folgenden Schema:
        \(schema)

        priority nur high, medium oder low. category nur bio, profile, content, timing, engagement oder goal. xp 20-80.
        """

        let root = try await askCoachForJSONObject(
            question: question,
            avenContext: context,
            schemaHint: schema,
            diagnosticLabel: "Profilanalyse"
        )

        func cleanStrings(_ value: Any?) -> [String] {
            (value as? [String] ?? [])
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        let summary = (root["summary"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let strengths = Array(cleanStrings(root["strengths"]).prefix(3))
        let weaknesses = Array(cleanStrings(root["weaknesses"]).prefix(3))
        let bioRaw = (root["recommendedBio"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let rawTasks = root["tasks"] as? [[String: Any]] ?? []

        var tasks: [AVENAIPlanTask] = []
        var seenTitles = Set<String>()
        var profileTaskCount = 0
        for (index, raw) in rawTasks.prefix(8).enumerated() {
            let title = (raw["title"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let detail = (raw["detail"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let priority = (raw["priority"] as? String ?? "medium").lowercased()
            let category = (raw["category"] as? String ?? "profile").lowercased()
            let xp = min(80, max(20, raw["xp"] as? Int ?? 30))
            let requiresProof = raw["requiresProof"] as? Bool ?? true
            guard !title.isEmpty, !detail.isEmpty, ["high", "medium", "low"].contains(priority) else { continue }

            let normalized = title.lowercased().replacingOccurrences(of: " ", with: "")
            guard !seenTitles.contains(normalized) else { continue }
            let isProfileTask = category == "bio" || category == "profile"
            if isProfileTask && profileTaskCount >= 2 { continue }
            if normalized.contains("emoji") && !context.lowercased().contains("emoji") { continue }

            seenTitles.insert(normalized)
            if isProfileTask { profileTaskCount += 1 }
            let slug = title.lowercased().replacingOccurrences(of: " ", with: "-")
                .filter { $0.isLetter || $0.isNumber || $0 == "-" }
            tasks.append(AVENAIPlanTask(
                id: "ai-\(index)-\(String(slug.prefix(28)))",
                title: title, detail: detail, priority: priority,
                category: category, xp: xp, requiresProof: requiresProof
            ))
            if tasks.count == 6 { break }
        }

        if tasks.count < 3, let strongerPlan = try? await generateActionPlan(record: record, account: account), strongerPlan.count > tasks.count {
            tasks = strongerPlan
        }

        guard !tasks.isEmpty else {
            throw AVENBackendError.validation("AVEN AI hat keinen verwertbaren Aktionsplan geliefert.")
        }
        guard !strengths.isEmpty || !weaknesses.isEmpty else {
            throw AVENBackendError.validation("AVEN AI hat keine konkreten Profil-Findings geliefert.")
        }

        return AVENAIProfileReview(
            summary: summary,
            strengths: strengths,
            weaknesses: weaknesses,
            recommendedBio: bioRaw.isEmpty ? nil : bioRaw,
            tasks: tasks
        )
    }
}

// MARK: - AI Action Plan after profile analysis

extension AVENBackend {
    static func generateActionPlan(record: AnalysisRecord, account: ConnectedTikTokAccount?) async throws -> [AVENAIPlanTask] {
        let goal = AVENUserGoalStore.current
        var context = AVENAIContextBuilder.make(account: account, analysis: record)
        if let goal {
            context += "\nGesetztes Ziel: \(goal.title), Zielwert \(goal.target) \(goal.unit), Zeitraum \(goal.deadline)."
            if !goal.current.isEmpty { context += " Aktueller Wert: \(goal.current)." }
        }

        let schema = """
        {"tasks":[{"title":"kurzer Titel","detail":"konkrete Schritte + Erledigt-Kriterium + warum","priority":"high","category":"content","xp":40,"requiresProof":true}]}
        """
        let question = """
        Erstelle aus den ECHTEN Analyse-Findings einen persönlichen TikTok-Aktionsplan.
        Nutze keine erfundenen Views, Retention-, Engagement- oder Wachstumswerte.
        Priorisiere nur Dinge, die durch Analyse oder gesetztes Ziel begründet sind.

        QUALITÄTSREGELN:
        - 4 bis maximal 6 konkrete Aufgaben, sofern genug Evidenz vorhanden ist.
        - Maximal 2 Aufgaben zu Bio/Profil. Ähnliche Profilprobleme zu EINER starken Aufgabe bündeln.
        - Mindestens 1 umsetzbare Content-Aufgabe, wenn das Wachstumsziel Follower, Views oder Engagement betrifft.
        - Mindestens 1 Aufgabe direkt zum gesetzten Ziel, wenn eines vorhanden ist.
        - Keine isolierte Emoji-Aufgabe und keine generischen Füllaufgaben.
        - Jede Aufgabe muss ein klares Erledigt-Kriterium enthalten.
        - Aufgaben dürfen Verhalten verlangen (z. B. 3 Hooks testen, 3 Videos veröffentlichen), aber KEIN Ergebnis garantieren.
        - requiresProof nur true, wenn ein Screenshot die Umsetzung tatsächlich belegen kann.

        Antworte AUSSCHLIESSLICH als valides JSON ohne Markdown in diesem Schema:
        \(schema)

        priority nur high, medium oder low. xp zwischen 20 und 80. category nur bio, profile, content, timing, engagement oder goal.
        """

        let root = try await askCoachForJSONObject(
            question: question,
            avenContext: context,
            schemaHint: schema,
            diagnosticLabel: "Aktionsplan"
        )
        guard let rawTasks = root["tasks"] as? [[String: Any]] else {
            throw AVENBackendError.validation("AVEN AI hat keinen gültigen Aktionsplan geliefert.")
        }

        var tasks: [AVENAIPlanTask] = []
        for (index, raw) in rawTasks.prefix(6).enumerated() {
            let title = (raw["title"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let detail = (raw["detail"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let priority = (raw["priority"] as? String ?? "medium").lowercased()
            let category = (raw["category"] as? String ?? "profile").lowercased()
            let xp = min(80, max(20, raw["xp"] as? Int ?? 30))
            let requiresProof = raw["requiresProof"] as? Bool ?? true
            guard !title.isEmpty, !detail.isEmpty, ["high", "medium", "low"].contains(priority) else { continue }
            let slug = title.lowercased()
                .replacingOccurrences(of: " ", with: "-")
                .filter { $0.isLetter || $0.isNumber || $0 == "-" }
            tasks.append(AVENAIPlanTask(
                id: "ai-\(index)-\(String(slug.prefix(28)))",
                title: title,
                detail: detail,
                priority: priority,
                category: category,
                xp: xp,
                requiresProof: requiresProof
            ))
        }
        guard !tasks.isEmpty else {
            throw AVENBackendError.validation("AVEN AI hat keine verwertbaren Aufgaben geliefert.")
        }
        return tasks
    }

}

// MARK: - Content Ideas

struct AVENContentIdea: Identifiable {
    let id = UUID()
    let hook: String
    let angle: String
    let format: String
}

extension AVENBackend {
    static func contentIdeas(topic: String, count: Int, avenContext: String) async throws -> [AVENContentIdea] {
        let json = try await post(endpoint: "/content-ideas", body: [
            "topic": topic,
            "platform": "tiktok",
            "count": min(10, max(1, count)),
            "avenContext": avenContext
        ])
        let raw = json["ideas"] as? [[String: Any]] ?? []
        let ideas = raw.compactMap { item -> AVENContentIdea? in
            let hook = (item["hook"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let angle = (item["angle"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let format = (item["format"] as? String ?? "Video").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !hook.isEmpty else { return nil }
            return AVENContentIdea(hook: hook, angle: angle, format: format.isEmpty ? "Video" : format)
        }
        guard !ideas.isEmpty else { throw AVENBackendError.validation("Die KI hat keine brauchbaren Content-Ideen geliefert.") }
        return ideas
    }
}

// MARK: - Account Performance

struct AVENAccountPerformance {
    let assessment: String
    let strengths: [String]
    let weaknesses: [String]
    let recommendations: [String]
}

extension AVENBackend {
    static func accountPerformance(account: ConnectedTikTokAccount) async throws -> AVENAccountPerformance {
        let json = try await post(endpoint: "/account-performance", body: [
            "username": account.username,
            "followers": account.followers,
            "following": account.following,
            "likes": account.likes,
            "videoCount": account.videoCount,
            "platform": "tiktok"
        ])
        let assessment = (json["assessment"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let strengths = (json["strengths"] as? [String] ?? []).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let weaknesses = (json["weaknesses"] as? [String] ?? []).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let recommendations = (json["recommendations"] as? [String] ?? []).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !assessment.isEmpty, !recommendations.isEmpty else {
            throw AVENBackendError.validation("Die Account-Auswertung war unvollständig. Bitte erneut versuchen.")
        }
        return AVENAccountPerformance(assessment: assessment, strengths: strengths, weaknesses: weaknesses, recommendations: recommendations)
    }
}

// MARK: - Posting Time

struct AVENPostingTimeSlot: Identifiable {
    let id = UUID()
    let day: String
    let time: String
    let reason: String
}

struct AVENPostingTimeResult {
    let suggestions: [AVENPostingTimeSlot]
    let note: String
}

extension AVENBackend {
    static func postingTime(account: ConnectedTikTokAccount) async throws -> AVENPostingTimeResult {
        let context = "@\(account.username.replacingOccurrences(of: "@", with: "")), \(account.followers) Follower, \(account.videoCount) Videos, \(account.likes) Likes"
        let json = try await post(endpoint: "/posting-time", body: [
            "platform": "tiktok",
            "tiktokContext": context
        ])
        let raw = json["suggestions"] as? [[String: Any]] ?? []
        let slots = raw.compactMap { item -> AVENPostingTimeSlot? in
            let day = (item["day"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let time = (item["time"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let reason = (item["reason"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !day.isEmpty, !time.isEmpty else { return nil }
            return AVENPostingTimeSlot(day: day, time: time, reason: reason)
        }
        let note = (json["note"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !slots.isEmpty else {
            throw AVENBackendError.validation(note.isEmpty ? "Für eine persönliche Posting-Zeit sind noch nicht genügend echte Account-Daten verfügbar." : note)
        }
        return AVENPostingTimeResult(suggestions: slots, note: note)
    }
}

// MARK: - Growth Experiment AI Evaluation

struct AVENExperimentEvaluation {
    let suggestedStatus: String
    let explanation: String
    let reasoning: String
    let nextAction: String
}

extension AVENBackend {
    static func evaluateExperiment(hypothesis: String, metric: String, before: Double, after: Double, durationDays: Int, tiktokContext: String?) async throws -> AVENExperimentEvaluation {
        var body: [String: Any] = [
            "hypothesis": hypothesis,
            "metric": metric,
            "unit": "value",
            "beforeValue": before,
            "afterValue": after,
            "durationDays": durationDays
        ]
        if let tiktokContext, !tiktokContext.isEmpty { body["tiktokContext"] = tiktokContext }
        let json = try await post(endpoint: "/experiment-evaluation", body: body)
        let status = (json["suggestedStatus"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let explanation = (json["explanation"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let reasoning = (json["reasoning"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let nextAction = (json["nextAction"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard ["works", "unclear", "doesntWork"].contains(status), !explanation.isEmpty, !reasoning.isEmpty, !nextAction.isEmpty else {
            throw AVENBackendError.validation("Die KI-Auswertung des Experiments war unvollständig.")
        }
        return AVENExperimentEvaluation(suggestedStatus: status, explanation: explanation, reasoning: reasoning, nextAction: nextAction)
    }
}

// MARK: - Video Analysis

struct AVENVideoCategory {
    let score: Int
    let feedback: String
}

struct AVENVideoAnalysis {
    let hook: AVENVideoCategory
    let content: AVENVideoCategory
    let cta: AVENVideoCategory
    let pacing: AVENVideoCategory
    let clarity: AVENVideoCategory
    let improvements: [String]
    let overallScore: Int
}

extension AVENBackend {
    private struct ExtractedVideoFrames {
        let frames: [Data]
        let timestamps: [Double]
        let durationSeconds: Double
    }

    static func analyzeVideo(url: URL, avenContext: String) async throws -> AVENVideoAnalysis {
        let payload = try extractVideoFrames(from: url)
        guard let endpoint = URL(string: "\(baseURL)/video-analysis") else { throw AVENBackendError.invalidURL }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.timeoutInterval = 120
        let boundary = "AVENBoundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = buildVideoFramesMultipart(boundary: boundary, payload: payload, avenContext: avenContext)

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw AVENBackendError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            let error = msg ?? "Videoanalyse fehlgeschlagen (\(http.statusCode))."
            AVENBackendDiagnostics.failure("/video-analysis", error)
            throw AVENBackendError.serverError(error)
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            AVENBackendDiagnostics.failure("/video-analysis", "Ungültige JSON-Antwort")
            throw AVENBackendError.invalidResponse
        }
        let result = try validateVideo(json)
        AVENBackendDiagnostics.success("/video-analysis")
        return result
    }

    private static func extractVideoFrames(from url: URL) throws -> ExtractedVideoFrames {
        let asset = AVURLAsset(url: url)
        let duration = CMTimeGetSeconds(asset.duration)
        guard duration.isFinite, duration > 0.15 else { throw AVENBackendError.validation("Die Videodauer konnte nicht gelesen werden.") }
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.15, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.15, preferredTimescale: 600)

        var frames: [Data] = []
        var timestamps: [Double] = []
        for seconds in representativeTimestamps(duration: duration) {
            do {
                var actual = CMTime.zero
                let cg = try generator.copyCGImage(at: CMTime(seconds: seconds, preferredTimescale: 600), actualTime: &actual)
                let resized = resizeImage(UIImage(cgImage: cg), maxDimension: 960)
                guard let jpeg = resized.jpegData(compressionQuality: 0.72), jpeg.count <= 2_000_000 else { continue }
                frames.append(jpeg)
                let actualSeconds = CMTimeGetSeconds(actual)
                timestamps.append(actualSeconds.isFinite ? actualSeconds : seconds)
            } catch { continue }
        }
        guard frames.count >= 4 else { throw AVENBackendError.validation("Aus dem Video konnten nicht genügend Frames für eine zuverlässige Analyse extrahiert werden.") }
        return ExtractedVideoFrames(frames: Array(frames.prefix(12)), timestamps: Array(timestamps.prefix(12)), durationSeconds: duration)
    }

    private static func representativeTimestamps(duration: Double) -> [Double] {
        let early = [0.15, 0.6, 1.2, 2.0, 3.0].filter { $0 < duration }
        let later = [0.25, 0.45, 0.65, 0.82, 0.96].map { max(0.05, min(duration - 0.05, duration * $0)) }
        var result: [Double] = []
        for value in early + later where value >= 0 && value < duration {
            if !result.contains(where: { abs($0 - value) < 0.08 }) { result.append(value) }
        }
        return Array(result.prefix(12)).sorted()
    }

    private static func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let largest = max(image.size.width, image.size.height)
        guard largest > maxDimension, largest > 0 else { return image }
        let scale = maxDimension / largest
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return UIGraphicsImageRenderer(size: target).image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
    }

    private static func buildVideoFramesMultipart(boundary: String, payload: ExtractedVideoFrames, avenContext: String) -> Data {
        var body = Data(); let crlf = "\r\n"
        func text(_ name: String, _ value: String) {
            body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\(crlf)\(crlf)".data(using: .utf8)!)
            body.append(value.data(using: .utf8)!)
            body.append(crlf.data(using: .utf8)!)
        }
        for (index, frame) in payload.frames.enumerated() {
            body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"frames[]\"; filename=\"frame_\(index).jpg\"\(crlf)".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\(crlf)\(crlf)".data(using: .utf8)!)
            body.append(frame); body.append(crlf.data(using: .utf8)!)
            if index < payload.timestamps.count { text("timestamps[]", String(format: "%.3f", payload.timestamps[index])) }
        }
        text("durationSeconds", String(format: "%.3f", payload.durationSeconds))
        text("avenContext", avenContext)
        body.append("--\(boundary)--\(crlf)".data(using: .utf8)!)
        return body
    }

    private static func validateVideo(_ json: [String: Any]) throws -> AVENVideoAnalysis {
        func category(_ key: String) throws -> AVENVideoCategory {
            guard let d = json[key] as? [String: Any], let score = d["score"] as? Int, (0...100).contains(score),
                  let feedback = d["feedback"] as? String, !feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AVENBackendError.validation("Unvollständige Videoanalyse: \(key).")
            }
            return AVENVideoCategory(score: score, feedback: feedback)
        }
        guard let overall = json["overallScore"] as? Int, (0...100).contains(overall) else {
            throw AVENBackendError.validation("Ungültiger Gesamt-Score der Videoanalyse.")
        }
        let improvements = (json["improvements"] as? [String] ?? []).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !improvements.isEmpty else { throw AVENBackendError.validation("Die Videoanalyse enthält keine konkreten Verbesserungen.") }
        return AVENVideoAnalysis(
            hook: try category("hook"), content: try category("content"), cta: try category("cta"),
            pacing: try category("pacing"), clarity: try category("clarity"), improvements: improvements, overallScore: overall
        )
    }
}

// MARK: - Existing Video Blueprint integration

struct VideoBlueprintRequest {
    let topic: String
    let platform: String
    let style: String
    let seconds: Int
}

struct VideoBlueprintResponse {
    let hook: String
    let script: String
    let scenes: [[String: String]]
    let cta: String
    let caption: String
    let hashtags: [String]

    init(json: [String: Any]) {
        hook = json["hook"] as? String ?? ""
        script = json["script"] as? String ?? ""
        scenes = json["scenes"] as? [[String: String]] ?? []
        cta = json["cta"] as? String ?? ""
        caption = json["caption"] as? String ?? ""
        hashtags = json["hashtags"] as? [String] ?? []
    }
}

extension AVENBackend {
    static func generateBlueprint(_ req: VideoBlueprintRequest) async throws -> VideoBlueprintResponse {
        let json = try await post(endpoint: "/video-blueprint", body: [
            "topic": req.topic,
            "platform": req.platform,
            "style": req.style,
            "seconds": min(90, max(1, req.seconds))
        ])
        return VideoBlueprintResponse(json: json)
    }
}
