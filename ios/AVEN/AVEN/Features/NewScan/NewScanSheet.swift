import SwiftUI
import PhotosUI

// ─── NewScanSheet ─────────────────────────────────────────────────────────────

struct NewScanSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = ScanViewModel()

    var body: some View {
        ZStack {
            AVENColor.backgroundPrimary.ignoresSafeArea()
            Group {
                switch vm.state {
                case .idle:
                    IdleView(vm: vm)
                case .imagePicked:
                    ImagePreviewView(vm: vm)
                case .analyzing:
                    AnalyzingView(vm: vm)
                case .result(let result):
                    ResultView(result: result, vm: vm, dismiss: { dismiss() })
                case .failed(let msg):
                    FailedView(message: msg, vm: vm)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: vm.stateTag)
        }
        .presentationDetents([.large])
        .presentationCornerRadius(28)
        .presentationBackground(AVENColor.backgroundPrimary)
    }
}

// ─── State tag for animation value ───────────────────────────────────────────

private extension ScanViewModel {
    var stateTag: Int {
        switch state {
        case .idle:        return 0
        case .imagePicked: return 1
        case .analyzing:   return 2
        case .result:      return 3
        case .failed:      return 4
        }
    }
}

// ─── Idle ─────────────────────────────────────────────────────────────────────

private struct IdleView: View {
    @ObservedObject var vm: ScanViewModel
    @State private var photoItem: PhotosPickerItem?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: AVENSpacing.xl) {
            DragHandle()
            Spacer()

            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [AVENColor.accentPurple.opacity(0.2), AVENColor.accentBlue.opacity(0.1)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 100, height: 100)
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 44))
                    .foregroundStyle(LinearGradient(
                        colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .scaleEffect(1.0)
            .onAppear { }

            VStack(spacing: AVENSpacing.sm) {
                Text("Neue Analyse")
                    .font(AVENFont.display(26))
                    .foregroundColor(AVENColor.textPrimary)
                Text("Lade einen Screenshot deines TikTok- oder\nInstagram-Profils hoch, um deinen AVEN Score\nzu berechnen.")
                    .font(AVENFont.body(15))
                    .foregroundColor(AVENColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Spacer()

            VStack(spacing: AVENSpacing.sm) {
                PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Screenshot auswählen")
                            .font(AVENFont.body(16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(LinearGradient(
                        colors: [AVENColor.accentGradientStart, AVENColor.accentGradientEnd],
                        startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: AVENRadius.md))
                    .foregroundColor(.white)
                    .shadow(color: AVENColor.accentPurple.opacity(0.4), radius: 12, y: 4)
                }
                .onChange(of: photoItem) { _, item in
                    Task { await vm.loadImage(from: item) }
                }
                .buttonStyle(.plain)

                Button { dismiss() } label: {
                    Text("Abbrechen")
                        .font(AVENFont.body(15))
                        .foregroundColor(AVENColor.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(PressButtonStyle())
            }
            .padding(.horizontal, AVENSpacing.md)
            .padding(.bottom, AVENSpacing.lg)
        }
    }
}

// ─── Image preview before analysis ───────────────────────────────────────────

private struct ImagePreviewView: View {
    @ObservedObject var vm: ScanViewModel

    var pickedImage: UIImage? {
        if case .imagePicked(let img) = vm.state { return img }
        return nil
    }

    var body: some View {
        VStack(spacing: AVENSpacing.lg) {
            DragHandle()

            Text("Screenshot bereit")
                .font(AVENFont.display(22))
                .foregroundColor(AVENColor.textPrimary)
                .padding(.top, AVENSpacing.sm)

            if let img = pickedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: AVENRadius.lg))
                    .overlay(RoundedRectangle(cornerRadius: AVENRadius.lg)
                        .strokeBorder(AVENColor.borderAccent, lineWidth: 1))
                    .frame(maxHeight: 320)
                    .padding(.horizontal, AVENSpacing.md)
                    .transition(.scale.combined(with: .opacity))
            }

            Spacer()

            VStack(spacing: AVENSpacing.sm) {
                AVENPrimaryButton(title: "Jetzt analysieren", icon: "sparkles") {
                    Task { await vm.startAnalysis() }
                }

                Button { vm.reset() } label: {
                    Text("Anderes Bild wählen")
                        .font(AVENFont.body(15))
                        .foregroundColor(AVENColor.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(PressButtonStyle())
            }
            .padding(.horizontal, AVENSpacing.md)
            .padding(.bottom, AVENSpacing.lg)
        }
    }
}

// ─── Analyzing ────────────────────────────────────────────────────────────────

private struct AnalyzingView: View {
    @ObservedObject var vm: ScanViewModel
    @State private var phase       = 0
    @State private var dotCount    = 0
    @State private var progress: CGFloat = 0
    @State private var scanY: CGFloat = -1
    @State private var orbPulse    = false

    private let steps = [
        "Profil wird erkannt",
        "Bio wird analysiert",
        "Feed wird geprüft",
        "Score wird berechnet",
    ]

    private var statusText: String {
        if case .building = vm.aiPlanState { return "AVEN AI erstellt deinen Plan" }
        return steps[min(phase, steps.count - 1)]
    }

    var body: some View {
        VStack(spacing: AVENSpacing.xl) {
            DragHandle()
            Spacer()

            // Scanning orb
            ZStack {
                // Ambient rings
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [AVENColor.accentPurple.opacity(0.18 - Double(i) * 0.04),
                                         AVENColor.accentBlue.opacity(0.10 - Double(i) * 0.02)],
                                startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1)
                        .frame(width: CGFloat(96 + i * 28), height: CGFloat(96 + i * 28))
                        .scaleEffect(orbPulse ? 1.0 + CGFloat(i+1) * 0.04 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.4).repeatForever(autoreverses: true).delay(Double(i) * 0.25),
                            value: orbPulse)
                }
                // Core circle
                Circle()
                    .fill(LinearGradient(
                        colors: [AVENColor.accentPurple.opacity(0.22), AVENColor.accentBlue.opacity(0.14)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 84, height: 84)
                    .avGlow(color: AVENColor.accentPurple, radius: 16, breathes: true)
                // Icon
                Image(systemName: "sparkles")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(LinearGradient(
                        colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                        startPoint: .topLeading, endPoint: .bottomTrailing))

                // Scan line (AVEN cyan stripe sweeping down)
                GeometryReader { geo in
                    AVENShimmer()
                        .frame(height: 3)
                        .opacity(0.7)
                        .offset(y: geo.size.height * ((scanY + 1) / 2))
                        .clipShape(Circle().scale(1.2))
                }
                .frame(width: 84, height: 84)
                .clipShape(Circle())
            }

            VStack(spacing: AVENSpacing.sm) {
                Text("Analysiere dein Profil")
                    .font(AVENFont.display(22))
                    .foregroundColor(AVENColor.textPrimary)

                Text(statusText + String(repeating: ".", count: (dotCount % 3) + 1))
                    .font(AVENFont.body(15))
                    .foregroundColor(AVENColor.textSecondary)
                    .animation(.none, value: dotCount)
                    .contentTransition(.opacity)
            }

            // Progress bar with shimmer overlay
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4).fill(AVENColor.borderSubtle)
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(
                            colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * progress)
                        .animation(AVENMotion.smooth, value: progress)
                        .overlay(
                            AVENShimmer()
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .opacity(0.5)
                        )
                }
            }
            .frame(height: 6)
            .padding(.horizontal, AVENSpacing.xl)

            Spacer()
            Spacer()
        }
        .onAppear {
            orbPulse = true
            progress = 0.05
            // Sweep scan line continuously
            withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                scanY = 1
            }
            Timer.scheduledTimer(withTimeInterval: 0.55, repeats: true) { _ in
                dotCount += 1
                withAnimation(AVENMotion.smooth) { progress = min(progress + 0.17, 0.92) }
                if dotCount % 4 == 0 && phase < steps.count - 1 {
                    withAnimation(AVENMotion.smooth) { phase += 1 }
                }
            }
        }
    }
}

// ─── Result ───────────────────────────────────────────────────────────────────

private struct ResultView: View {
    let result: ScanAnalysisResult
    @ObservedObject var vm: ScanViewModel
    let dismiss: () -> Void
    @EnvironmentObject private var container: AppContainer
    @State private var appeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AVENSpacing.lg) {
                DragHandle()

                // Score
                VStack(spacing: AVENSpacing.sm) {
                    Text("Dein AVEN Score")
                        .font(AVENFont.body(14))
                        .foregroundColor(AVENColor.textSecondary)

                    ScoreArcView(score: appeared ? result.score : 0, size: 160)
                        .animation(.spring(response: 1.2, dampingFraction: 0.7), value: appeared)

                    Text(result.status)
                        .font(AVENFont.display(22))
                        .foregroundStyle(LinearGradient(
                            colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                            startPoint: .leading, endPoint: .trailing))

                    // Show that this analysis set the new current score
                    ScoreUpdateBadge(newScore: result.score)
                }
                .padding(.top, AVENSpacing.sm)

                // Strengths
                ResultSection(title: "✅  Stärken", color: AVENColor.textPositive, items: result.strengths)
                    .offset(y: appeared ? 0 : 20).opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.3), value: appeared)

                // Weaknesses (only if present)
                if !result.weaknesses.isEmpty {
                    ResultSection(title: "⚠️  Schwächen", color: AVENColor.textNegative, items: result.weaknesses)
                        .offset(y: appeared ? 0 : 20).opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.5).delay(0.5), value: appeared)
                }

                // Only show a bio when AVEN has a clean, non-empty recommendation.
                if !result.recommendedBio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    RecommendedBioCard(bio: result.recommendedBio, isStrong: result.bioIsStrong)
                        .offset(y: appeared ? 0 : 20).opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.5).delay(0.65), value: appeared)
                }

                AIPlanStatusCard(state: vm.aiPlanState)
                    .offset(y: appeared ? 0 : 16)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.45).delay(0.75), value: appeared)

                // CTAs
                VStack(spacing: AVENSpacing.sm) {
                    AVENPrimaryButton(title: "Zum Aktionsplan", icon: "checkmark.circle.fill") {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            container.selectedTab = .actionPlan
                        }
                    }
                    Button { vm.reset() } label: {
                        Text("Neue Analyse starten")
                            .font(AVENFont.body(15))
                            .foregroundColor(AVENColor.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(PressButtonStyle())
                }
                .padding(.bottom, AVENSpacing.xl)
            }
            .padding(.horizontal, AVENSpacing.md)
        }
        .onAppear { withAnimation { appeared = true } }
    }
}

private struct AIPlanStatusCard: View {
    let state: AIPlanGenerationState

    var body: some View {
        AVENCard {
            HStack(spacing: 11) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.11))
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AVENFont.body(13, weight: .semibold))
                        .foregroundColor(AVENColor.textPrimary)
                    Text(subtitle)
                        .font(AVENFont.body(10.5))
                        .foregroundColor(AVENColor.textSecondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var icon: String {
        switch state {
        case .ready: return "sparkles"
        case .failed: return "exclamationmark.triangle"
        case .building: return "wand.and.stars"
        case .idle: return "checkmark.circle"
        }
    }
    private var iconColor: Color {
        if case .failed = state { return Color.orange }
        return AVENColor.accentPurple
    }
    private var title: String {
        switch state {
        case .ready(let count): return "AVEN AI Plan erstellt · \(count) Aufgaben"
        case .failed: return "Analyse fertig · KI-Verfeinerung nicht geladen"
        case .building: return "AVEN AI erstellt deinen Plan"
        case .idle: return "Analyse abgeschlossen"
        }
    }
    private var subtitle: String {
        switch state {
        case .ready: return "Dein Aktionsplan wurde aus deinen echten Findings und deinem Ziel personalisiert."
        case .failed(let message): return message
        case .building: return "Deine Findings werden gerade priorisiert."
        case .idle: return "Öffne den Aktionsplan für deine nächsten Schritte."
        }
    }
}

private struct ResultSection: View {
    let title: String
    let color: Color
    let items: [String]

    var body: some View {
        AVENCard {
            VStack(alignment: .leading, spacing: AVENSpacing.sm) {
                Text(title)
                    .font(AVENFont.body(15, weight: .semibold))
                    .foregroundColor(AVENColor.textPrimary)
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Circle().fill(color).frame(width: 5, height: 5).padding(.top, 6)
                        Text(item)
                            .font(AVENFont.body(13))
                            .foregroundColor(AVENColor.textSecondary)
                            .lineSpacing(3)
                    }
                }
            }
        }
    }
}

// ─── Failed ───────────────────────────────────────────────────────────────────

private struct FailedView: View {
    let message: String
    @ObservedObject var vm: ScanViewModel

    var body: some View {
        VStack(spacing: AVENSpacing.xl) {
            DragHandle()
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(AVENColor.textNegative)
            Text("Analyse fehlgeschlagen")
                .font(AVENFont.display(20))
                .foregroundColor(AVENColor.textPrimary)
            Text(message)
                .font(AVENFont.body(14))
                .foregroundColor(AVENColor.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            AVENPrimaryButton(title: "Erneut versuchen") { vm.reset() }
                .padding(.horizontal, AVENSpacing.md)
                .padding(.bottom, AVENSpacing.lg)
        }
    }
}

// ─── Shared UI helpers ────────────────────────────────────────────────────────

private struct DragHandle: View {
    var body: some View {
        Capsule()
            .fill(AVENColor.borderSubtle)
            .frame(width: 36, height: 4)
            .padding(.top, AVENSpacing.sm)
    }
}

// ─── ViewModel ────────────────────────────────────────────────────────────────

enum AIPlanGenerationState: Equatable {
    case idle
    case building
    case ready(Int)
    case failed(String)
}

@MainActor
final class ScanViewModel: ObservableObject {
    @Published var aiPlanState: AIPlanGenerationState = .idle
    @Published var state: ScanFlowState = .idle

    func loadImage(from item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            state = .failed("Das Bild konnte nicht geladen werden.")
            return
        }
        withAnimation { state = .imagePicked(image) }
    }

    func startAnalysis() async {
        // Capture image BEFORE changing state
        guard case .imagePicked(let image) = state else {
            withAnimation { state = .failed("Kein Bild ausgewählt.") }
            return
        }

        withAnimation { state = .analyzing }

        // Run Vision analysis and enforce minimum display time (~4 s) in parallel,
        // so the user sees all step labels before the result is revealed.
        async let analysisResult = ProfileImageAnalyzer().analyze(image: image)
        async let minimumDelay: Void = Task.sleep(nanoseconds: 4_000_000_000)
        var result = await analysisResult
        try? await minimumDelay

        // Vision/OCR supplies the evidence and score. AVEN AI then rewrites the
        // findings into specific feedback and builds the personal action plan.
        // If the AI request fails, the real local analysis remains available.
        if let record = AVENAnalysisStore.load() {
            aiPlanState = .building
            do {
                let account = Self.persistedTikTokAccount()
                let review = try await AVENBackend.generateProfileReview(
                    record: record,
                    localResult: result,
                    account: account
                )

                let refinedRecord = AnalysisRecord(
                    analysisScore: record.analysisScore,
                    status: record.status,
                    strengths: review.strengths,
                    weaknesses: review.weaknesses,
                    dimensions: record.dimensions,
                    taskIDs: review.tasks.map(\.id),
                    platform: record.platform,
                    timestamp: record.timestamp
                )
                AVENAnalysisStore.replaceCurrent(refinedRecord)
                AVENAIActionPlanStore.save(tasks: review.tasks, for: refinedRecord)
                _ = AVENGrowthMissionStore.ensure(account: account)

                result = ScanAnalysisResult(
                    score: result.score,
                    status: result.status,
                    strengths: review.strengths,
                    weaknesses: review.weaknesses,
                    suggestions: result.suggestions,
                    platform: result.platform,
                    recommendedBio: review.recommendedBio ?? "",
                    bioIsStrong: review.recommendedBio == nil
                )
                aiPlanState = .ready(review.tasks.count)
            } catch {
                // Keep the evidence-based local score/findings, but never present a
                // potentially garbled OCR-generated bio as an AI recommendation.
                result = ScanAnalysisResult(
                    score: result.score,
                    status: result.status,
                    strengths: result.strengths,
                    weaknesses: result.weaknesses,
                    suggestions: result.suggestions,
                    platform: result.platform,
                    recommendedBio: "",
                    bioIsStrong: false
                )
                aiPlanState = .failed(error.localizedDescription)
            }
        }

        withAnimation { state = .result(result) }
    }

    func reset() {
        aiPlanState = .idle
        withAnimation { state = .idle }
    }

    private static func persistedTikTokAccount() -> ConnectedTikTokAccount? {
        guard let data = UserDefaults.standard.data(forKey: "aven.connectedTikTokAccount") else { return nil }
        return try? JSONDecoder().decode(ConnectedTikTokAccount.self, from: data)
    }
}

// ─── Press button style ───────────────────────────────────────────────────────

// PressButtonStyle is defined in Components.swift

// ─── Suggestion card with apply-changes ──────────────────────────────────────

private struct SuggestionCard: View {
    let suggestion: ScanSuggestion
    let result:     ScanAnalysisResult
    @ObservedObject var vm: ScanViewModel
    @State private var applyState: ApplySuggestionState = .idle

    private let service = ApplyChangesService()
    private var isBio: Bool { suggestion.category.lowercased() == "bio" }

    var body: some View {
        AVENCard {
            VStack(alignment: .leading, spacing: AVENSpacing.sm) {
                // Title + impact
                HStack {
                    Text(suggestion.title)
                        .font(AVENFont.body(14, weight: .semibold))
                        .foregroundColor(AVENColor.textPrimary)
                    Spacer()
                    Text("+\(suggestion.impact) pts")
                        .font(AVENFont.mono(12))
                        .foregroundColor(AVENColor.accentPurpleLight)
                }
                Text(suggestion.detail)
                    .font(AVENFont.body(13))
                    .foregroundColor(AVENColor.textSecondary)
                    .lineSpacing(3)

                // Apply button / result
                switch applyState {
                case .idle:
                    HStack(spacing: AVENSpacing.sm) {
                        if isBio {
                            Button { Task { await applyNow() } } label: {
                                Label("Kopieren & TikTok öffnen", systemImage: "doc.on.clipboard")
                                    .font(AVENFont.body(13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(LinearGradient(
                                        colors: [AVENColor.accentGradientStart, AVENColor.accentGradientEnd],
                                        startPoint: .leading, endPoint: .trailing))
                                    .clipShape(RoundedRectangle(cornerRadius: AVENRadius.sm))
                            }
                            .buttonStyle(PressButtonStyle())
                        } else {
                            Button { Task { await applyNow() } } label: {
                                Label("Direkt anwenden", systemImage: "bolt.fill")
                                    .font(AVENFont.body(13, weight: .semibold))
                                    .foregroundColor(AVENColor.accentPurple)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(AVENColor.accentPurple.opacity(0.10))
                                    .clipShape(RoundedRectangle(cornerRadius: AVENRadius.sm))
                                    .overlay(RoundedRectangle(cornerRadius: AVENRadius.sm)
                                        .strokeBorder(AVENColor.accentPurple.opacity(0.3), lineWidth: 1))
                            }
                            .buttonStyle(PressButtonStyle())
                        }
                    }

                case .applying:
                    HStack(spacing: 8) {
                        ProgressView().tint(AVENColor.accentPurple).scaleEffect(0.75)
                        Text("Wird angewendet…")
                            .font(AVENFont.body(13))
                            .foregroundColor(AVENColor.textSecondary)
                    }
                    .padding(.vertical, 6)

                case .done(let note):
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AVENColor.textPositive)
                                .font(.system(size: 13))
                            Text("✓ Angewendet (Demo)")
                                .font(AVENFont.body(13, weight: .semibold))
                                .foregroundColor(AVENColor.textPositive)
                        }
                        Text(note)
                            .font(AVENFont.body(12))
                            .foregroundColor(AVENColor.textSecondary)
                            .lineSpacing(3)
                    }
                    .padding(.vertical, 4)

                case .failed(let msg):
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundColor(AVENColor.textNegative)
                            .font(.system(size: 13))
                        Text(msg)
                            .font(AVENFont.body(12))
                            .foregroundColor(AVENColor.textNegative)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func applyNow() async {
        withAnimation(AVENMotion.springFast) { applyState = .applying }
        // Short artificial delay so the user sees the state change
        try? await Task.sleep(nanoseconds: 700_000_000)
        let outcome = await service.apply(suggestion: suggestion, result: result)
        AVENHaptic.success()
        withAnimation(AVENMotion.spring) {
            switch outcome {
            case .applied(let note), .copiedAndOpened(_, let note), .apiSuccess(let note):
                applyState = .done(note: note)
            case .failed(let msg):
                applyState = .failed(msg)
            case .requiresUpgrade:
                applyState = .failed("AVEN Pro erforderlich.")
            }
        }
    }
}

private enum ApplySuggestionState {
    case idle
    case applying
    case done(note: String)
    case failed(String)
}

// ─── Recommended Bio Card ─────────────────────────────────────────────────────

private struct RecommendedBioCard: View {
    let bio:      String
    let isStrong: Bool
    @State private var copied = false

    var body: some View {
        AVENCard(accentBorder: true) {
            VStack(alignment: .leading, spacing: AVENSpacing.sm) {
                HStack {
                    Text(isStrong ? "✨  Deine Bio (optimiert)" : "✨  Empfohlene Bio")
                        .font(AVENFont.body(15, weight: .semibold))
                        .foregroundColor(AVENColor.textPrimary)
                    Spacer()
                    if isStrong {
                        Text("Bereits stark")
                            .font(AVENFont.body(11, weight: .medium))
                            .foregroundColor(AVENColor.textPositive)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(AVENColor.textPositive.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                Text(bio)
                    .font(AVENFont.body(14))
                    .foregroundColor(AVENColor.textSecondary)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 4)

                HStack(spacing: AVENSpacing.sm) {
                    Button {
                        UIPasteboard.general.string = bio
                        withAnimation(.spring(response: 0.3)) { copied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { copied = false }
                        }
                    } label: {
                        Label(copied ? "Kopiert ✓" : "Bio kopieren",
                              systemImage: copied ? "checkmark.circle.fill" : "doc.on.clipboard")
                            .font(AVENFont.body(13, weight: .semibold))
                            .foregroundColor(copied ? AVENColor.textPositive : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background {
                                if copied {
                                    AVENColor.textPositive.opacity(0.15)
                                } else {
                                    LinearGradient(colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                                                   startPoint: .leading, endPoint: .trailing)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: AVENRadius.sm))
                    }
                    .buttonStyle(PressButtonStyle())
                    .animation(.spring(response: 0.3), value: copied)

                    Button {
                        if let url = URL(string: "https://www.tiktok.com/") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("TikTok öffnen", systemImage: "arrow.up.right.square")
                            .font(AVENFont.body(13))
                            .foregroundColor(AVENColor.accentPurple)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                            .background(AVENColor.accentPurple.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: AVENRadius.sm))
                    }
                    .buttonStyle(PressButtonStyle())
                }
            }
        }
    }
}

// ─── Score Update Badge ────────────────────────────────────────────────────────
// Shows after each analysis to confirm the AVEN Score was updated.

private struct ScoreUpdateBadge: View {
    let newScore: Int
    @State private var appeared = false

    private var previousScore: Int {
        // Get the second-to-last history entry if it exists
        let history = AVENAnalysisStore.loadHistory()
        guard history.count >= 2 else { return newScore }
        return history[history.count - 2].score
    }

    var body: some View {
        let prev  = previousScore
        let delta = newScore - prev
        let isFirst = AVENAnalysisStore.loadHistory().count <= 1

        HStack(spacing: 6) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 11))
            if isFirst {
                Text("AVEN Score gesetzt: \(newScore)")
            } else if delta > 0 {
                Text("AVEN Score: \(prev) → \(newScore) (+\(delta) Punkte)")
            } else if delta < 0 {
                Text("AVEN Score: \(prev) → \(newScore) (\(delta) Punkte)")
            } else {
                Text("AVEN Score unverändert: \(newScore)")
            }
        }
        .font(AVENFont.body(12, weight: .medium))
        .foregroundColor(delta >= 0 ? AVENColor.textPositive : AVENColor.textNegative)
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background((delta >= 0 ? AVENColor.textPositive : AVENColor.textNegative).opacity(0.1))
        .clipShape(Capsule())
        .scaleEffect(appeared ? 1 : 0.8).opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.4)) { appeared = true }
        }
    }
}

#Preview {
    NewScanSheet()
}
