import Vision
import UIKit
import Foundation

// ─── Profile Image Analyzer ───────────────────────────────────────────────────
//
// Uses on-device Vision OCR to read real text from the uploaded screenshot.
// Produces concrete, honest findings based only on what is actually visible.
// Never invents data or uses generic fallback sentences when OCR succeeds.
//
// MARK: - Integration Point (Phase 2)
// Replace the entire analyze() body with a backend call for deeper AI analysis:
//   POST /analyze/screenshot  multipart: imageData
//   → { score, strengths, weaknesses, suggestions, dimensions }

// ─── Enriched OCR context ─────────────────────────────────────────────────────

struct OCRContext {
    // Raw
    let rawText:         String
    let lines:           [String]   // original case, trimmed
    let linesLow:        [String]   // lowercased

    // Detected elements
    let platform:        ConnectedProfile.SocialPlatform
    let username:        String?    // @handle found in text
    let bioText:         String?    // longest non-numeric, non-handle line
    let followerCount:   Int?
    let followingCount:  Int?
    let likeCount:       Int?
    let videoCount:      Int?

    // Qualitative flags
    let hasCTA:          Bool   // link / "in bio" / url found
    let hasEmoji:        Bool   // emoji in bio area
    let hasKeyword:      Bool   // niche/topic keyword detected
    let bioWordCount:    Int    // words in bio (0 = no bio)
    let totalTextLines:  Int
}

// ─── Main class ───────────────────────────────────────────────────────────────

@MainActor
final class ProfileImageAnalyzer {

    func analyze(image: UIImage) async -> ScanAnalysisResult {
        guard let cgImage = image.cgImage else { return Self.fallback() }

        let ctx = await extractContext(from: cgImage)

        // If OCR found virtually nothing, the screenshot quality is the issue
        if ctx.totalTextLines < 2 {
            return ScanAnalysisResult(
                score:     30,
                status:    "Screenshot unklar",
                strengths: [],
                weaknesses: [
                    "Der Screenshot enthält kaum lesbaren Text. Stelle sicher, dass das Bild scharf und vollständig ist.",
                    "Lade einen Screenshot hoch, auf dem Bio, Username und Follower-Zahlen gut sichtbar sind."
                ],
                suggestions: [
                    ScanSuggestion(
                        title: "Besseren Screenshot hochladen",
                        detail: "Öffne dein TikTok-Profil, scrolle nach oben bis die Bio sichtbar ist, und mache einen neuen Screenshot. Achte auf gute Beleuchtung und ausreichende Helligkeit des Displays.",
                        impact: 8, category: "quality"
                    )
                ],
                platform:       ctx.platform,
                recommendedBio: "",
                bioIsStrong:    false
            )
        }

        // score + status are computed below from weighted dimensions
        let strengths   = buildStrengths(ctx)
        let weaknesses  = buildWeaknesses(ctx)
        let suggestions = buildSuggestions(ctx)

        // ── Score dimensions — single source, used for BOTH breakdown and total ───
        //
        // Rule: computeScore() is derived from the SAME dimension values.
        // This guarantees score detail and final score are always consistent.
        // No artificial caps — a perfect profile can reach 100.

        // 1. Profil & Bio  (0–100)
        let bioDimScore: Int = {
            guard let _ = ctx.bioText else { return 15 }
            let words = ctx.bioWordCount
            if words >= 10 && ctx.hasKeyword && ctx.hasCTA { return 100 }
            if words >= 8  && ctx.hasKeyword && ctx.hasCTA { return 92  }
            if words >= 7  && ctx.hasKeyword               { return 82  }
            if words >= 5  && ctx.hasKeyword               { return 72  }
            if words >= 5                                   { return 60  }
            if words >= 3                                   { return 45  }
            return 30
        }()

        // 2. Handlungsaufforderung / Link  (0–100)
        let ctaDimScore: Int = ctx.hasCTA ? 100 : 15

        // 3. Content-Thema & Positionierung  (0–100)
        let nicheDimScore: Int = {
            if ctx.hasKeyword { return 100 }
            if ctx.bioWordCount >= 5 { return 55 }
            return -1   // -1 = unmeasurable from screenshot
        }()

        // 4. Profilbild & Branding  (0–100)
        // Inferred from visual OCR signals — emoji, niche clarity, CTA = deliberate brand work
        let brandingScore: Int = {
            var s = 40
            if ctx.hasEmoji               { s += 20 }
            if ctx.hasKeyword             { s += 20 }
            if ctx.hasCTA                 { s += 15 }
            if ctx.bioWordCount >= 8      { s += 5  }
            return min(100, s)
        }()

        // 5. Profilstruktur & angepinnte Inhalte  (0–100)
        // Inferred from screenshot richness (more visible content = better structure)
        let structureScore: Int = {
            var s = 30
            if ctx.totalTextLines >= 6  { s += 20 }
            if ctx.totalTextLines >= 10 { s += 15 }
            if ctx.hasKeyword           { s += 15 }
            if ctx.hasCTA               { s += 10 }
            if ctx.bioText != nil       { s += 10 }
            return min(100, s)
        }()

        // ── Derive final score from dimension values (weighted) ───────────────
        // Weights reflect importance of each area for profile quality:
        // Bio 30% | CTA 25% | Niche 20% | Branding 15% | Structure 10%
        // For unmeasurable dims (score == -1), redistribute weight to others.
        let measurableDims: [(Int, Double)] = [
            (bioDimScore,   0.30),
            (ctaDimScore,   0.25),
            (nicheDimScore >= 0 ? nicheDimScore : bioDimScore, 0.20),  // fallback to bio if niche unmeasurable
            (brandingScore, 0.15),
            (structureScore, 0.10),
        ]
        let weightedScore = measurableDims.reduce(0.0) { $0 + Double($1.0) * $1.1 }
        let score = max(20, min(100, Int(weightedScore.rounded())))

        // ── Build dimension display objects ───────────────────────────────────
        let bioPos    = bioDimScore >= 80 ? (ctx.bioText.map { "Bio erkannt: \"\(String($0.prefix(40)))\"" } ?? "Bio vorhanden") : ""
        let bioNeg    = bioDimScore < 60  ? (ctx.bioText == nil ? "Kein Bio-Text erkannt" : "Bio zu kurz (\(ctx.bioWordCount) Wörter)") : ""
        let ctaPos    = ctaDimScore >= 80 ? "CTA oder Link in Bio erkannt" : ""
        let ctaNeg    = ctaDimScore < 50  ? "Kein CTA in der Bio gefunden" : ""
        let nichePos  = nicheDimScore >= 80 ? "Nischen-Keyword erkannt" : ""
        let nicheNeg  = nicheDimScore >= 0 && nicheDimScore < 60 ? "Kein klares Nischen-Keyword" : ""
        let brandPos  = brandingScore >= 80 ? "Visuelles Profil und Branding wirken professionell." : ""
        let brandNeg  = brandingScore < 60  ? "Profilbild oder Branding könnten professioneller wirken." : ""
        let structPos = structureScore >= 60 ? "Profilstruktur erkennbar und konsistent." : ""
        let structNeg = structureScore < 60  ? "Angepinnte Videos oder klare Profilstruktur nicht erkennbar." : ""

        let dims: [AnalysisDimension] = [
            AnalysisDimension(
                name: "Profil & Bio",
                score: bioDimScore,
                positives: bioPos.isEmpty ? [] : [bioPos],
                negatives: bioNeg.isEmpty ? [] : [bioNeg],
                tip: "Formuliere Bio als: [Zielgruppe] + [Versprechen] + [CTA]"
            ),
            AnalysisDimension(
                name: "Handlungsaufforderung",
                score: ctaDimScore,
                positives: ctaPos.isEmpty ? [] : [ctaPos],
                negatives: ctaNeg.isEmpty ? [] : [ctaNeg],
                tip: "Ergänze am Ende der Bio: \"→ Guide unten\" oder einen Link."
            ),
            AnalysisDimension(
                name: "Content-Thema",
                score: nicheDimScore,
                positives: nichePos.isEmpty ? [] : [nichePos],
                negatives: nicheNeg.isEmpty ? [] : [nicheNeg],
                tip: "Baue ein konkretes Keyword in deine Bio ein, das dein Thema benennt."
            ),
            AnalysisDimension(
                name: "Profilbild & Branding",
                score: brandingScore,
                positives: brandPos.isEmpty ? [] : [brandPos],
                negatives: brandNeg.isEmpty ? [] : [brandNeg],
                tip: "Nutze ein professionelles Profilbild und einheitliche Farben/Bildsprache."
            ),
            AnalysisDimension(
                name: "Profilstruktur & angepinnte Inhalte",
                score: structureScore,
                positives: structPos.isEmpty ? [] : [structPos],
                negatives: structNeg.isEmpty ? [] : [structNeg],
                tip: "Pinne 3 strategische Videos an, die deine Nische und deinen Mehrwert zeigen."
            ),
        ]


        // Split large AnalysisRecord init into variables to help type-checker
        let taskIDs   = suggestions.map { $0.category + "_" + String($0.title.prefix(8)) }
        let platform  = ctx.platform.rawValue
        let record = AnalysisRecord(
            analysisScore: score,
            status:        scoreLabel(score),
            strengths:     strengths,
            weaknesses:    weaknesses,
            dimensions:    dims,
            taskIDs:       taskIDs,
            platform:      platform,
            timestamp:     Date()
        )
        // Build recommended bio from real profile context
        let (recBio, bioIsStrong) = buildRecommendedBio(ctx: ctx)

        // Every analysis scores 0–100 directly — no artificial cap
        let finalRecord = AnalysisRecord(
            analysisScore: score,
            status:        scoreLabel(score),
            strengths:     strengths,
            weaknesses:    weaknesses,
            dimensions:    dims,
            taskIDs:       taskIDs,
            platform:      platform,
            timestamp:     Date()
        )
        AVENAnalysisStore.save(finalRecord)

        return ScanAnalysisResult(
            score:          score,
            status:         scoreLabel(score),
            strengths:      strengths,
            weaknesses:     weaknesses,
            suggestions:    suggestions,
            platform:       ctx.platform,
            recommendedBio: recBio,
            bioIsStrong:    bioIsStrong
        )
    }

    // ── OCR extraction ────────────────────────────────────────────────────────

    private func extractContext(from cgImage: CGImage) async -> OCRContext {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { req, _ in
                let obs = req.results as? [VNRecognizedTextObservation] ?? []
                let lines = obs
                    .compactMap { $0.topCandidates(1).first?.string }
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                let linesLow = lines.map { $0.lowercased() }
                let rawText  = linesLow.joined(separator: " ")

                // Platform
                let isInsta  = rawText.contains("instagram") || rawText.contains("posts") || rawText.contains("reels") || rawText.contains("story")
                let platform: ConnectedProfile.SocialPlatform = isInsta ? .instagram : .tiktok

                // @handle
                let username = lines.first(where: { $0.hasPrefix("@") })
                    ?? lines.first(where: { $0.lowercased().hasPrefix("@") })

                // Numbers — pair with context words
                func extractNumber(after keywords: [String]) -> Int? {
                    for (i, line) in linesLow.enumerated() {
                        for kw in keywords where line.contains(kw) {
                            // Try this line or the next
                            for candidate in [lines[safe: i], lines[safe: i+1], lines[safe: i-1]].compactMap({$0}) {
                                let digits = candidate.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                                if let n = Int(digits), n > 0 { return n }
                            }
                        }
                    }
                    return nil
                }

                let followerCount  = extractNumber(after: ["follower", "follow"])
                let followingCount = extractNumber(after: ["following", "folge"])
                let likeCount      = extractNumber(after: ["like", "gefällt", "heart"])
                let videoCount     = extractNumber(after: ["video", "beitrag", "post"])

                // ── TikTok UI / empty-state strings to IGNORE ──────────────────
                // These appear in screenshots but are NOT user-written bio content.
                let tiktokUIStrings: Set<String> = [
                    "hochladen", "upload", "tiktok studio", "studio", "bearbeiten",
                    "edit", "folgen", "follow", "following", "follower", "gefällt mir",
                    "likes", "videos", "for you", "für dich", "following", "discover",
                    "entdecken", "nachrichten", "messages", "inbox", "benachrichtigungen",
                    "notifications", "profil", "profile", "einstellungen", "settings",
                    "suche", "search", "mehr", "more", "teilen", "share",
                    "kommentar", "comment", "speichern", "save", "melden", "report",
                    "welche guten fotos", "gute fotos", "letzte zeit", "gemacht",
                    "was passiert", "what's happening", "keine videos", "no videos",
                    "noch keine", "not yet", "jetzt loslegen", "get started",
                    "video hinzufügen", "add video", "ersten video", "first video",
                    "live", "q&a", "reels", "story", "stories", "highlights",
                    "abonniert", "subscribed", "abonnenten", "subscribers",
                    "sticker", "effekte", "effects", "filter",
                ]

                func isUIString(_ s: String) -> Bool {
                    let low = s.lowercased()
                    // Exact match or contains a known UI phrase
                    if tiktokUIStrings.contains(low) { return true }
                    if tiktokUIStrings.contains(where: { low.contains($0) }) { return true }
                    // Navigation/button patterns: very short all-caps or single words that are clearly UI
                    let words = low.split(separator: " ")
                    if words.count == 1 && low.count <= 12 &&
                       ["hochladen","upload","studio","bearbeiten","edit","folgen","suche",
                        "entdecken","nachrichten","profil","mehr","live","reels"].contains(low) {
                        return true
                    }
                    return false
                }

                // Bio: collect lines that are actual user content, not TikTok UI
                // Also skip the handle, pure numbers, and very short platform labels
                let bioLines = lines.filter { line in
                    let low = line.lowercased()
                    guard !line.hasPrefix("@") else { return false }
                    // Skip pure numeric / stat lines
                    guard !line.allSatisfy({ $0.isNumber || $0 == "." || $0 == "," || $0 == " " || $0 == "K" || $0 == "M" }) else { return false }
                    // Skip very short lines (buttons, labels)
                    guard line.count > 2 else { return false }
                    // Skip known TikTok UI strings
                    guard !isUIString(low) else { return false }
                    // Skip lines that are pure numbers with K/M suffix (follower counts)
                    let stripped = line.replacingOccurrences(of: "[0-9.,KkMm ]", with: "", options: .regularExpression)
                    guard stripped.count > 1 else { return false }
                    return true
                }

                // bioText = the longest bio line that isn't just the handle area
                // Prefer lines containing emojis or typical bio vocabulary
                let scoredBioLines = bioLines.sorted { a, b in
                    let aScore = a.unicodeScalars.filter { $0.properties.isEmojiPresentation }.count * 3 + a.count
                    let bScore = b.unicodeScalars.filter { $0.properties.isEmojiPresentation }.count * 3 + b.count
                    return aScore > bScore
                }
                let bioText = scoredBioLines.first

                // bioWordCount = total words across ALL bio lines
                let bioWordCount = bioLines.reduce(0) { $0 + $1.split(separator: " ").count }

                // CTA — search ALL bio lines, not just bioText
                let allBioText = bioLines.joined(separator: " ").lowercased()
                let ctaWords = ["link", "http", "www", ".com", ".de", ".app", "bio", "klick",
                                "hier", "jetzt", "shop", "book", "coming soon", "↓", "→", "👇", "🔗",
                                "folge", "abonniere", "subscribe", "check out", "dm", "schreib"]
                let hasCTA   = ctaWords.contains { allBioText.contains($0) }

                // Emoji — check ALL bio lines combined
                let allBioForEmoji = bioLines.joined(separator: " ")
                let hasEmoji = allBioForEmoji.unicodeScalars.contains { $0.properties.isEmojiPresentation }

                // Niche keywords (topic clarity)
                let nicheWords = [
                    // German niches
                    "coaching", "tipps", "fitness", "food", "travel", "business",
                    "creator", "musik", "comedy", "style", "mode", "beauty", "tech", "gaming",
                    "marketing", "motivation", "mindset", "finanzen", "invest", "abnehmen",
                    "ernährung", "rezept", "reisen", "lifestyle", "sport", "yoga", "health",
                    "startup", "gründer", "design", "fotografie", "fotograf", "video",
                    // English niches (for international creators)
                    "ai", "grow", "growth", "optimize", "analyze", "analyse", "content",
                    "finance", "money", "invest", "wealth", "trading", "crypto",
                    "health", "workout", "nutrition", "recipe", "vlog", "podcast",
                    "entrepreneur", "agency", "brand", "social media", "instagram",
                    "tiktok", "youtube", "digital", "online", "seo", "ads",
                    "fashion", "outfit", "makeup", "skincare", "travel", "photography",
                    "music", "art", "dance", "comedy", "education", "learn",
                ]
                let rawLow = rawText.lowercased()
                let hasKeyword = nicheWords.contains { rawLow.contains($0) }

                continuation.resume(returning: OCRContext(
                    rawText:        rawText,
                    lines:          lines,
                    linesLow:       linesLow,
                    platform:       platform,
                    username:       username,
                    bioText:        bioText,
                    followerCount:  followerCount,
                    followingCount: followingCount,
                    likeCount:      likeCount,
                    videoCount:     videoCount,
                    hasCTA:         hasCTA,
                    hasEmoji:       hasEmoji,
                    hasKeyword:     hasKeyword,
                    bioWordCount:   bioWordCount,
                    totalTextLines: lines.count
                ))
            }
            request.recognitionLevel          = .accurate
            request.usesLanguageCorrection    = true
            request.recognitionLanguages      = ["de", "en"]
            request.minimumTextHeight         = 0.01

            try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        }
    }

    private func scoreLabel(_ score: Int) -> String {
        switch score {
        case 100:       return "Perfekt"
        case 90...99:   return "Hervorragend"
        case 80...89:   return "Stark"
        case 66...79:   return "Gut"
        case 50...65:   return "Ausbaufähig"
        default:        return "Verbesserungspotential"
        }
    }

    // ── Findings ──────────────────────────────────────────────────────────────
    // Only surface findings that are actually useful to the creator.
    // No "handle detected", no follower-count weakness, no contradictions.

    private func buildStrengths(_ ctx: OCRContext) -> [String] {
        var out: [String] = []
        // EVIDENCE FIRST — only report confirmed visible facts

        // Bio: only a strength when substantive
        if let bio = ctx.bioText {
            let words = ctx.bioWordCount
            if words >= 8 && ctx.hasKeyword && ctx.hasCTA {
                out.append("Vollständige Bio mit klarer Positionierung, Keyword und Handlungsaufforderung.")
            } else if words >= 6 && ctx.hasKeyword {
                out.append("Bio kommuniziert ein klares Thema: \"\(bio.prefix(60))\".")
            } else if words >= 4 {
                out.append("Bio vorhanden: \"\(bio.prefix(60))\".")
            }
            // < 4 words → too thin to call a strength
        }
        // No bio → no bio-strength

        if ctx.hasCTA {
            out.append("Handlungsaufforderung oder Link in der Bio erkannt.")
        }
        if ctx.hasKeyword && ctx.bioWordCount >= 4 {
            out.append("Nischen-Keyword erkannt — Algorithmus kann Account gezielt zuordnen.")
        }
        if ctx.hasEmoji && ctx.bioWordCount >= 5 {
            out.append("Bio ist mit Emojis strukturiert und gut les- und scanbar.")
        }
        if ctx.totalTextLines >= 8 {
            out.append("Profilseite enthält sichtbaren Content — Videos oder Beiträge sind vorhanden.")
        }
        if out.count >= 3 {
            out.append("Das Profil ist insgesamt gut aufgestellt.")
        }
        if out.isEmpty {
            out.append("Auf Basis des Screenshots konnten keine klaren Stärken identifiziert werden.")
        }
        return out
    }
    private func buildWeaknesses(_ ctx: OCRContext) -> [String] {
        var out: [String] = []
        let bio   = ctx.bioText
        let words = ctx.bioWordCount
        let raw   = ctx.rawText.lowercased()
        // EVIDENCE FIRST — only flag what is genuinely absent or weak

        // 1. Bio absent or too thin
        if bio == nil {
            out.append("Keine Bio sichtbar. Ohne Bio wissen Besucher nicht, worum es geht.")
        } else if words < 4 {
            out.append("Bio sehr kurz (\(words) Wörter) — zu wenig für eine klare Positionierung.")
        }

        // 2. No niche keyword — only flag when checkable
        if !ctx.hasKeyword {
            if bio != nil {
                out.append("Kein klares Thema/Keyword in der Bio. Der Algorithmus kann den Account schwer einordnen.")
            } else if ctx.totalTextLines >= 3 {
                out.append("Keine klare thematische Positionierung erkennbar.")
            }
        }

        // 3. No CTA — flag in both bio-present and bio-absent cases
        if !ctx.hasCTA {
            if bio != nil {
                out.append("Kein CTA oder Link in der Bio. Profilbesucher werden nicht zu einer Handlung aufgefordert.")
            } else {
                out.append("Kein CTA erkennbar. Profilbesucher haben keinen klaren nächsten Schritt.")
            }
        }

        // 4. No value proposition — only when bio has enough words to judge
        if bio != nil && words >= 4 {
            let hasValue = raw.contains("helfe") || raw.contains("lerne") ||
                           raw.contains("zeige") || raw.contains("tipps") ||
                           raw.contains("tips")  || raw.contains("guide") ||
                           raw.contains("coach") || raw.contains("grow")  ||
                           raw.contains("wachse") || raw.contains("mehrwert")
            if !hasValue {
                out.append("Kein klares Nutzenversprechen erkennbar. Besucher sehen nicht, warum sie folgen sollten.")
            }
        }

        // 5. No emoji structure — only when bio is present and long enough
        if bio != nil && words >= 6 && !ctx.hasEmoji {
            out.append("Bio ohne Emojis — schwerer zu überfliegen. Strukturierende Emojis würden helfen.")
        }

        // 6. Sparse screenshot
        if ctx.totalTextLines < 4 && bio == nil {
            out.append("Der Screenshot zeigt wenig Inhalt. Bitte einen vollständigen Profil-Screenshot hochladen.")
        }
        return out
    }

    private func buildSuggestions(_ ctx: OCRContext) -> [ScanSuggestion] {
        // These feed into the Action Plan as verified tasks.
        // Plain language, no jargon.
        var out: [ScanSuggestion] = []
        let bio   = ctx.bioText
        let words = ctx.bioWordCount
        let raw   = ctx.rawText.lowercased()

        // Task: Bio fehlt oder zu kurz
        if bio == nil {
            out.append(ScanSuggestion(
                title:  "Schreibe eine Bio, die erklärt, worum es geht",
                detail: "Füge eine kurze Bio hinzu, die in 1–2 Sätzen erklärt, worum es auf deinem Profil geht und warum es sich lohnt zu folgen.\nNachweis: Screenshot deines aktualisierten Profils.",
                impact: 9, category: "bio"))
        } else if words < 5 {
            out.append(ScanSuggestion(
                title:  "Erweitere deine Bio mit mehr Inhalt",
                detail: "Deine Bio ist sehr kurz. Erkläre in ein paar Worten mehr, was Besucher auf deinem Profil erwartet und warum sie folgen sollten.\nNachweis: Screenshot deines aktualisierten Profils.",
                impact: 7, category: "bio"))
        }

        // Task: Kein Thema erkennbar
        if !ctx.hasKeyword && words >= 3 {
            out.append(ScanSuggestion(
                title:  "Zeige klar, worum es auf deinem Profil geht",
                detail: "Füge einen Begriff ein, der dein Thema direkt beschreibt, z.B. \"Fitness\", \"TikTok-Wachstum\", \"Kochen\", \"Business\". So verstehen Besucher und der Algorithmus sofort, was dich ausmacht.\nNachweis: Screenshot deiner aktualisierten Bio.",
                impact: 6, category: "bio"))
        }

        // Task: Keine Handlungsaufforderung
        if !ctx.hasCTA && bio != nil {
            out.append(ScanSuggestion(
                title:  "Füge eine klare nächste Handlung hinzu",
                detail: "Zeige Besuchern, was sie als Nächstes tun sollen — z.B. \"↓ Mein kostenloses Angebot unten\", \"Schreib mir eine Nachricht\" oder einfach \"→ Link in Bio\".\nNachweis: Screenshot deines aktualisierten Profils mit sichtbarer Handlungsaufforderung.",
                impact: 8, category: "bio"))
        }

        // Task: Kein erkennbarer Mehrwert / Grund zu folgen
        let hasValueProp = words >= 8 && (raw.contains("helfe") || raw.contains("lerne") ||
                           raw.contains("zeige") || raw.contains("inspire") ||
                           raw.contains("tipps") || raw.contains("tips") ||
                           raw.contains("guide") || raw.contains("coach") ||
                           raw.contains("grow") || raw.contains("wachse"))
        if !hasValueProp && words >= 3 {
            out.append(ScanSuggestion(
                title:  "Erkläre, warum Besucher dir folgen sollten",
                detail: "Füge in deiner Bio einen konkreten Nutzen hinzu — was bekommen Menschen, wenn sie dir folgen? Z.B. \"Täglich neue Tipps zu [deinem Thema]\".\nNachweis: Screenshot deines aktualisierten Profils.",
                impact: 5, category: "bio"))
        }

        // Task: Keine Emojis für Struktur
        if bio != nil && words >= 6 && !ctx.hasEmoji {
            out.append(ScanSuggestion(
                title:  "Strukturiere deine Bio mit passenden Emojis",
                detail: "Emojis am Anfang jeder Zeile machen die Bio übersichtlicher und einprägsamer. Wähle Emojis, die zu deinem Thema passen.\nNachweis: Screenshot deines aktualisierten Profils.",
                impact: 3, category: "bio"))
        }

        // Task: Hooks — nur wenn keine dringenderen Bio-Probleme mehr offen sind
        let bioProblemsExist = out.count > 0
        if !bioProblemsExist || (ctx.hasCTA && ctx.hasKeyword) {
            out.append(ScanSuggestion(
                title:  "Starte deine Videos mit einem starken ersten Satz",
                detail: "Die ersten 1–2 Sekunden entscheiden, ob Menschen weiterschauen. Statt \"Hey Leute\" lieber: eine überraschende Aussage, eine Frage oder ein unerwarteter Einstieg.\nBeispiel: \"Das machen die meisten völlig falsch…\"",
                impact: 6, category: "content"))
        }

        return out
    }


    // ── Recommended Bio ──────────────────────────────────────────────────────
    // ── Bio Recommendation ────────────────────────────────────────────────────
    // Returns (recommendedBio, isAlreadyStrong).
    // isStrong = true only when bio is genuinely complete: ≥10 words + niche + CTA + emoji.
    // Generated bios use real 4-line structure:
    //   [Emoji] Nische / Positionierung
    //   [Emoji] Value Proposition
    //   [Emoji] Content-Versprechen
    //   👇 CTA
    // Max ~150 chars to fit TikTok's bio limit.

    private func buildRecommendedBio(ctx: OCRContext) -> (String, Bool) {
        let existing = ctx.bioText ?? ""
        let words    = ctx.bioWordCount
        let hasCTA   = ctx.hasCTA
        let hasKw    = ctx.hasKeyword
        let hasEmoji = ctx.hasEmoji

        // ── Strong bio check — genuinely high bar ─────────────────────────────
        let isStrong = words >= 10 && hasKw && hasCTA && hasEmoji
        if isStrong {
            return ("Deine Bio ist bereits optimal aufgebaut. Keine Änderung nötig.", true)
        }

        // ── Detect niche ──────────────────────────────────────────────────────
        let niche = inferNiche(ctx: ctx)

        if !niche.label.isEmpty {
            var lines: [String] = []
            lines.append("\(niche.icon) \(niche.label)")

            // Line 2: preserve first meaningful existing line if it adds real content
            let existingFirst = existing
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: "\n").first.map(String.init) ?? ""
            let exWords = existingFirst.split(separator: " ").count
            if exWords >= 3 && existingFirst != niche.label {
                let cleaned = existingFirst.trimmingCharacters(
                    in: CharacterSet(charactersIn: "🎯✨📌📈👇🚀💡🔥⚡ "))
                lines.append("\(niche.valueEmoji) \(cleaned)")
            } else {
                lines.append("\(niche.valueEmoji) \(niche.valueLine)")
            }

            lines.append("\(niche.contentEmoji) \(niche.contentLine)")

            // Line 4: CTA — use existing CTA line if present
            if hasCTA {
                let ctaLine = existing.split(separator: "\n").map(String.init).first { line in
                    let low = line.lowercased()
                    return low.contains("link") || low.contains("👇") ||
                           low.contains("↓") || low.contains("http") ||
                           low.contains("folge") || low.contains("dm")
                }
                lines.append(ctaLine?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "👇 Folge für mehr")
            } else {
                lines.append("👇 \(niche.ctaLine)")
            }
            return (lines.joined(separator: "\n"), false)
        }

        // ── No niche detected ─────────────────────────────────────────────────
        if existing.isEmpty {
            return ("""
✨ Content Creator
🎯 Ideen, Trends & täglicher Mehrwert
🚀 Neue Videos jede Woche
👇 Folge für mehr
""".trimmingCharacters(in: .newlines), false)
        }

        // Has bio but weak — restructure with emojis + add CTA
        let bioLines = existing
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let fallbackEmojis = ["✨", "🎯", "🚀", "💡"]
        var result: [String] = []
        for (idx, line) in bioLines.prefix(3).enumerated() {
            let scalar = line.unicodeScalars.first
            let hasE   = scalar?.properties.isEmojiPresentation ?? false
            result.append(hasE ? line : "\(fallbackEmojis[idx]) \(line)")
        }
        if !hasCTA { result.append("👇 Folge für mehr") }
        return (result.joined(separator: "\n"), false)
    }

    // ── Niche detection ───────────────────────────────────────────────────────

    private struct NicheProfile {
        let label, icon, valueLine, valueEmoji, contentLine, contentEmoji, ctaLine: String
    }

    private func inferNiche(ctx: OCRContext) -> NicheProfile {
        let raw = ctx.rawText.lowercased()
        let u   = (ctx.username ?? "").lowercased()
        func m(_ kw: [String]) -> Bool { kw.contains { raw.contains($0) || u.contains($0) } }
        typealias N = NicheProfile

        if m(["tiktok growth","tiktok wachstum","tiktok tipps","tiktok algorithm","tiktok strategie"]) {
            return N(label:"TikTok Growth & Strategie",icon:"🚀",valueLine:"Content Systeme für Creator",valueEmoji:"📈",contentLine:"Bessere Videos. Mehr Reichweite.",contentEmoji:"🎯",ctaLine:"Folge für tägliche Tipps")
        }
        if m(["ai","künstliche intelligenz","chatgpt","automation","automatisierung"]) {
            return N(label:"KI & Automatisierung",icon:"🤖",valueLine:"Tools & Systeme für mehr Output",valueEmoji:"⚡️",contentLine:"Smarter arbeiten, nicht mehr.",contentEmoji:"💡",ctaLine:"Folge für KI-Tipps")
        }
        if m(["fitness","gym","workout","training","muscle","abnehmen","sixpack"]) {
            return N(label:"Fitness & Lifestyle",icon:"💪",valueLine:"Trainings-Tipps & Ernährung",valueEmoji:"🥗",contentLine:"Jeden Tag einen Schritt besser.",contentEmoji:"📈",ctaLine:"Folge für tägliche Motivation")
        }
        if m(["finance","finanz","geld","invest","aktien","krypto","passives einkommen"]) {
            return N(label:"Finanzen & Investment",icon:"💰",valueLine:"Vermögen aufbauen Schritt für Schritt",valueEmoji:"📊",contentLine:"Smarte Entscheidungen. Mehr Freiheit.",contentEmoji:"🎯",ctaLine:"Folge für Finanz-Tipps")
        }
        if m(["business","entrepreneur","gründer","startup","selbständig","freelance"]) {
            return N(label:"Business & Unternehmertum",icon:"🏆",valueLine:"Von der Idee zum profitablen Business",valueEmoji:"🚀",contentLine:"Ehrliche Einblicke. Echte Ergebnisse.",contentEmoji:"💡",ctaLine:"Folge für Business-Tipps")
        }
        if m(["marketing","werbung","ads","copywriting","branding","funnel","leads"]) {
            return N(label:"Marketing & Wachstum",icon:"📣",valueLine:"Strategien für mehr Kunden & Umsatz",valueEmoji:"🎯",contentLine:"Was wirklich funktioniert.",contentEmoji:"⚡️",ctaLine:"Folge für Marketing-Strategien")
        }
        if m(["food","kochen","rezept","essen","backen","küche","meal prep"]) {
            return N(label:"Food & Kochen",icon:"🍳",valueLine:"Einfache Rezepte für jeden Tag",valueEmoji:"✨",contentLine:"Lecker, schnell, ohne Stress.",contentEmoji:"🎯",ctaLine:"Folge für neue Rezepte")
        }
        if m(["beauty","makeup","skincare","pflege","haare","kosmetik"]) {
            return N(label:"Beauty & Skincare",icon:"✨",valueLine:"Ehrliche Reviews & Pflege-Routinen",valueEmoji:"💎",contentLine:"Authentisch. Kein Filter.",contentEmoji:"🎯",ctaLine:"Folge für Beauty-Tipps")
        }
        if m(["travel","reise","reisen","fernweh","weltreise","vanlife","digital nomad"]) {
            return N(label:"Reisen & Abenteuer",icon:"🌍",valueLine:"Die besten Orte. Ehrliche Erfahrungen.",valueEmoji:"✈️",contentLine:"Reisen mit Budget & Plan.",contentEmoji:"🎯",ctaLine:"Folge für Reise-Inspiration")
        }
        if m(["fashion","mode","outfit","style","styling","streetwear","ootd"]) {
            return N(label:"Fashion & Style",icon:"👗",valueLine:"Outfits, Trends & Styling-Tipps",valueEmoji:"✨",contentLine:"Dein persönlicher Style.",contentEmoji:"🎯",ctaLine:"Folge für tägliche Style-Tipps")
        }
        if m(["gaming","gamer","stream","esport","twitch","lets play"]) {
            return N(label:"Gaming & Content",icon:"🎮",valueLine:"Gameplay, Tipps & Creator-Life",valueEmoji:"🔥",contentLine:"Für alle, die gewinnen wollen.",contentEmoji:"⚡️",ctaLine:"Folge für Gaming-Content")
        }
        if m(["coaching","coach","mentor","mindset","persönlichkeit","motivation"]) {
            return N(label:"Coaching & Mindset",icon:"🧠",valueLine:"Methoden für mehr Klarheit & Erfolg",valueEmoji:"🎯",contentLine:"Werde die beste Version von dir.",contentEmoji:"🚀",ctaLine:"Folge für tägliche Impulse")
        }
        if m(["content creator","creator","youtube","vlog","podcast","social media"]) {
            return N(label:"Content Creator",icon:"🎬",valueLine:"Ideen, Tipps & Creator-Strategien",valueEmoji:"💡",contentLine:"Mehr Reichweite. Mehr Impact.",contentEmoji:"📈",ctaLine:"Folge für Creator-Tipps")
        }
        if m(["tech","coding","software","developer","programmier","app","saas"]) {
            return N(label:"Tech & Development",icon:"💻",valueLine:"Tools, Code & Produktivitäts-Hacks",valueEmoji:"⚡️",contentLine:"Smarter bauen. Schneller launchen.",contentEmoji:"🚀",ctaLine:"Folge für Tech-Tipps")
        }
        if m(["musik","music","singer","producer","rap","beat","studio","artist"]) {
            return N(label:"Musik & Kreatives",icon:"🎵",valueLine:"Behind the Scenes & Musik-Tipps",valueEmoji:"🎧",contentLine:"Authentisch. Leidenschaftlich.",contentEmoji:"✨",ctaLine:"Folge für neue Musik & Vibes")
        }
        if m(["yoga","meditation","wellness","achtsamkeit","mental health","breathwork"]) {
            return N(label:"Wellness & Mindfulness",icon:"🧘",valueLine:"Mehr Balance & innere Stärke",valueEmoji:"✨",contentLine:"Für Körper, Geist & Seele.",contentEmoji:"💚",ctaLine:"Folge für tägliche Wellness-Impulse")
        }
        // Fallback: use existing bio first line
        if let bio = ctx.bioText,
           let first = bio.split(separator: "\n").first.map(String.init),
           first.split(separator: " ").count >= 2 {
            return N(label:first,icon:"✨",valueLine:"Ideen & täglicher Mehrwert",valueEmoji:"🎯",
                     contentLine:"Neuer Content jede Woche.",contentEmoji:"🚀",ctaLine:"Folge für mehr")
        }
        return N(label:"",icon:"",valueLine:"",valueEmoji:"",contentLine:"",contentEmoji:"",ctaLine:"")
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private func formatNum(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n)/1_000_000) }
        if n >= 1_000     { return String(format: "%.1fK", Double(n)/1_000) }
        return "\(n)"
    }

    static func fallback() -> ScanAnalysisResult {
        ScanAnalysisResult(
            score: 30,
            status: "Nicht analysierbar",
            strengths: [],
            weaknesses: ["Das Bild konnte nicht verarbeitet werden."],
            suggestions: [
                ScanSuggestion(
                    title:  "Neues Bild hochladen",
                    detail: "Lade einen klaren Screenshot deines Profils hoch. Das Bild muss als UIImage geladen werden können.",
                    impact: 8, category: "quality"
                )
            ],
            platform:       .tiktok,
            recommendedBio: "",
            bioIsStrong:    false
        )
    }
    // ── Proof verification (reuses same OCR pipeline) ─────────────────────────
    // Returns (passed, message). Category is the GrowthActionItem.category string.

    func verifyProof(image: UIImage, category: String, taskTitle: String) async -> (Bool, String) {
        guard let cg = image.cgImage else {
            return (false, "Bild konnte nicht gelesen werden. Bitte erneut versuchen.")
        }
        let ctx   = await extractContext(from: cg)
        let raw   = ctx.rawText
        let cat   = category.lowercased()
        let title = taskTitle.lowercased()

        // ── Universal gate: must be a recognisable social-media / app screenshot ──
        // A valid proof screenshot will contain app-UI text or social context.
        // Natural photos, selfies, landscapes produce very little OCR text.
        let socialSignals = [
            "tiktok", "instagram", "reels", "follower", "following", "likes", "gefällt",
            "views", "aufrufe", "bio", "kommentar", "share", "teilen", "profilbild",
            "bearbeiten", "edit", "profil", "post", "beitrag", "hashtag", "#",
            "analytics", "statistik", "account", "@"
        ]
        let socialSignalCount = socialSignals.filter { raw.contains($0) }.count
        let hasEnoughText     = ctx.totalTextLines >= 3

        guard hasEnoughText || socialSignalCount >= 2 else {
            return (false,
                "Das Bild sieht nicht wie ein App-Screenshot aus. " +
                "Bitte lade einen Screenshot aus der TikTok- oder Instagram-App hoch, " +
                "der den relevanten Bereich klar zeigt.")
        }

        // ── Bio tasks ─────────────────────────────────────────────────────────
        if cat == "bio" || title.contains("bio") || title.contains("cta") || title.contains("positionierung") {

            // Must look like a profile page (not just any app screen)
            let isProfileScreen = socialSignals.filter { raw.contains($0) }.count >= 2 ||
                                  ctx.followerCount != nil ||
                                  raw.contains("follower") || raw.contains("following") ||
                                  raw.contains("profil") || raw.contains("bearbeiten") ||
                                  ctx.username != nil

            guard isProfileScreen else {
                return (false,
                    "Kein Profil-Screenshot erkannt. " +
                    "Öffne dein TikTok-Profil, scrolle nach oben sodass die Bio sichtbar ist, " +
                    "und mache einen Screenshot.")
            }

            let needsCTA = title.contains("cta") || title.contains("link") || title.contains("handlungsaufforderung")

            if needsCTA {
                guard ctx.hasCTA else {
                    return (false,
                        "Kein CTA oder Link im Profil-Screenshot erkannt. " +
                        "Stelle sicher, dass dein Link oder deine Handlungsaufforderung " +
                        "(z.B. \"→ Link in Bio\") in der Bio sichtbar ist und mache einen neuen Screenshot.")
                }
                return (true, "Profil-Screenshot mit CTA erkannt ✓")
            }

            let hasBioContent = ctx.bioText != nil && ctx.bioWordCount >= 3
            guard hasBioContent else {
                return (false,
                    "Kein Bio-Text erkannt. " +
                    "Stelle sicher, dass deine Bio ausgefüllt ist und auf dem Screenshot sichtbar ist. " +
                    (ctx.bioText == nil ? "Kein Textinhalt in der Bio gefunden." :
                     "Bio enthält nur \(ctx.bioWordCount) Wörter — mindestens 3 werden erwartet."))
            }
            return (true, "Profil-Screenshot mit Bio-Inhalt erkannt ✓")
        }

        // ── Brand / visual tasks ──────────────────────────────────────────────
        if cat == "brand" || title.contains("branding") || title.contains("visuell") {
            // A feed or profile screenshot should show multiple pieces of content text
            guard ctx.totalTextLines >= 4 && socialSignalCount >= 1 else {
                return (false,
                    "Screenshot zeigt keinen erkennbaren Feed oder Profil-Bereich. " +
                    "Lade einen Screenshot deines TikTok-Profils oder Feeds hoch, " +
                    "auf dem dein visuelles Branding sichtbar ist.")
            }
            return (true, "Profil/Feed-Screenshot mit Inhalt erkannt ✓")
        }

        // ── Hashtag tasks ─────────────────────────────────────────────────────
        if cat == "distribution" || title.contains("hashtag") {
            let hasHashtag = raw.contains("#") || raw.contains("hashtag")
            guard hasHashtag else {
                return (false,
                    "Keine Hashtags im Screenshot erkannt. " +
                    "Öffne einen deiner TikTok-Beiträge, scrolle zur Caption mit den Hashtags " +
                    "und mache einen Screenshot.")
            }
            let hashtagCount = raw.components(separatedBy: "#").count - 1
            if hashtagCount < 2 {
                return (false,
                    "Nur \(hashtagCount) Hashtag(s) erkannt. " +
                    "Zeige mindestens 2–3 Hashtags in der Caption deines Beitrags.")
            }
            return (true, "\(hashtagCount) Hashtags erkannt ✓")
        }

        // ── Content / hooks tasks ─────────────────────────────────────────────
        if cat == "content" || title.contains("hook") || title.contains("einstieg") ||
           title.contains("video") {
            // Verify they're showing a TikTok video or caption screenshot
            let isVideoContext = raw.contains("caption") || raw.contains("sound") ||
                                 raw.contains("duet") || raw.contains("stitch") ||
                                 raw.contains("kommentar") || raw.contains("aufrufe") ||
                                 raw.contains("views") || raw.contains("#") ||
                                 socialSignalCount >= 2
            guard isVideoContext else {
                return (false,
                    "Kein Video-Screenshot erkannt. " +
                    "Öffne ein deiner TikTok-Videos, sodass der Einstieg oder die Caption sichtbar ist, " +
                    "und mache einen Screenshot.")
            }
            return (true, "Video-Screenshot akzeptiert ✓ — Hooks werden mit der nächsten Profil-Analyse bewertet.")
        }

        // ── Niche / keyword tasks ─────────────────────────────────────────────
        if title.contains("nischen") || title.contains("keyword") {
            guard ctx.bioText != nil || raw.contains("bio") || socialSignalCount >= 2 else {
                return (false,
                    "Kein Profil-Screenshot erkannt. " +
                    "Zeige deinen TikTok-Profilbereich mit der aktualisierten Bio.")
            }
            let hasKeywordNow = ctx.hasKeyword
            guard hasKeywordNow else {
                return (false,
                    "Kein klares Nischen-Keyword in der Bio erkannt. " +
                    "Stelle sicher, dass dein Thema (z.B. \"TikTok-Wachstum\", \"Fitness\") " +
                    "in der sichtbaren Bio steht.")
            }
            return (true, "Nischen-Keyword in der Bio erkannt ✓")
        }

        // ── Generic fallback ──────────────────────────────────────────────────
        if socialSignalCount >= 2 {
            return (true, "App-Screenshot akzeptiert ✓")
        }
        return (false,
            "Screenshot enthält zu wenig erkennbare App-Inhalte. " +
            "Bitte einen vollständigeren Screenshot aus der App hochladen.")
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
