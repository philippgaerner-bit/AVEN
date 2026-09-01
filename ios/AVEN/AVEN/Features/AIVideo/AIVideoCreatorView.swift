import SwiftUI
import AVKit
import Photos

struct AIVideoCreatorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var container: AppContainer
    @StateObject private var vm = AIVideoCreatorViewModel()
    @State private var showPaywall     = false
    @State private var showLimitSheet  = false

    var body: some View {
        ZStack {
            AVENColor.backgroundPrimary.ignoresSafeArea()
            VStack(spacing: 0) {
                if vm.step < .generating {
                    StepProgressBar(current: vm.step.rawValue, total: 3)
                        .padding(.horizontal, AVENSpacing.md)
                        .padding(.top, AVENSpacing.md)
                }
                Group {
                    switch vm.step {
                    case .platform:   PlatformStep(vm: vm)
                    case .topic:      TopicStep(vm: vm)
                    case .settings:   SettingsStep(vm: vm)
                    case .generating: GeneratingStep()
                    case .result:
                        if let concept = vm.concept {
                            ResultStep(
                                concept: concept, vm: vm,
                                dismiss: { dismiss() },
                                onGenerateVideo: { handleGenerateVideo() }
                            )
                        }
                    case .rendering:
                        VideoRenderingStep(vm: vm)
                    case .videoResult:
                        if let status = vm.videoStatus {
                            switch status {
                            case .completed(let url):
                                VideoResultStep(videoURL: url, vm: vm, dismiss: { dismiss() })
                            case .failed(let msg):
                                VideoRenderFailedView(message: msg, vm: vm, dismiss: { dismiss() })
                            default:
                                VideoRenderingStep(vm: vm)
                            }
                        } else {
                            VideoRenderingStep(vm: vm)
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: vm.step)
            }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(28)
        .presentationBackground(AVENColor.backgroundPrimary)
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(isPresented: $showLimitSheet) {
            VideoLimitSheet(credits: container.videoCredits)
        }
    }

    private func handleGenerateVideo() {
        let credits = container.videoCredits
        if !credits.isProUser {
            showPaywall = true
            return
        }
        if !credits.canGenerate {
            showLimitSheet = true
            return
        }
        credits.consumeCredit()
        Task { await vm.startVideoRender() }
    }
}

private struct StepProgressBar: View {
    let current: Int; let total: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i <= current ? AVENColor.accentPurple : AVENColor.borderSubtle)
                    .frame(height: 4)
                    .animation(.spring(response: 0.4), value: current)
            }
        }
    }
}

// ─── Step 1 ───────────────────────────────────────────────────────────────────

private struct PlatformStep: View {
    @ObservedObject var vm: AIVideoCreatorViewModel
    @State private var appeared = false
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AVENSpacing.xl) {
                VideoDragHandle()
                VStack(spacing: AVENSpacing.sm) {
                    Text("Für welche Plattform?")
                        .font(AVENFont.display(24)).foregroundColor(AVENColor.textPrimary)
                    Text("Wähle die Zielplattform für dein Video-Konzept.")
                        .font(AVENFont.body(14)).foregroundColor(AVENColor.textSecondary).multilineTextAlignment(.center)
                }
                .padding(.top, AVENSpacing.sm)
                VStack(spacing: AVENSpacing.sm) {
                    ForEach(Array(VideoPlatform.allCases.enumerated()), id: \.element) { idx, p in
                        PlatformCard(platform: p, selected: vm.platform == p) {
                            withAnimation(.spring(response: 0.3)) { vm.platform = p }
                        }
                        .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 20)
                        .animation(.spring(response: 0.5).delay(Double(idx)*0.07), value: appeared)
                    }
                }
                AVENPrimaryButton(title: "Weiter", icon: "arrow.right") { withAnimation { vm.step = .topic } }
                    .padding(.bottom, AVENSpacing.lg)
            }
            .padding(.horizontal, AVENSpacing.md)
        }
        .onAppear { withAnimation { appeared = true } }
    }
}

private struct PlatformCard: View {
    let platform: VideoPlatform; let selected: Bool; let onSelect: () -> Void
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: AVENSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(selected ? AVENColor.accentPurple : AVENColor.backgroundElevated)
                        .frame(width: 42, height: 42)
                    Image(systemName: platform.icon).font(.system(size: 18))
                        .foregroundColor(selected ? .white : AVENColor.textSecondary)
                }
                Text(platform.rawValue).font(AVENFont.body(16, weight: .medium)).foregroundColor(AVENColor.textPrimary)
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(selected ? AVENColor.accentPurple : AVENColor.borderSubtle)
                    .animation(.spring(response: 0.3), value: selected)
            }
            .padding(AVENSpacing.md)
            .background(selected ? AVENColor.backgroundElevated : AVENColor.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: AVENRadius.lg))
            .overlay(RoundedRectangle(cornerRadius: AVENRadius.lg)
                .strokeBorder(selected ? AVENColor.accentPurple : AVENColor.borderSubtle, lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(PressButtonStyle())
    }
}

// ─── Step 2 ───────────────────────────────────────────────────────────────────

private struct TopicStep: View {
    @ObservedObject var vm: AIVideoCreatorViewModel
    @FocusState private var focused: Bool
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AVENSpacing.xl) {
                VideoDragHandle()
                VStack(spacing: AVENSpacing.sm) {
                    Text("Deine Video-Idee").font(AVENFont.display(24)).foregroundColor(AVENColor.textPrimary)
                    Text("Gib ein Thema ein oder lass AVEN deine Insights nutzen.")
                        .font(AVENFont.body(14)).foregroundColor(AVENColor.textSecondary).multilineTextAlignment(.center)
                }
                .padding(.top, AVENSpacing.sm)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Thema / Prompt").font(AVENFont.body(13, weight: .semibold)).foregroundColor(AVENColor.textSecondary)
                    ZStack(alignment: .topLeading) {
                        if vm.topic.isEmpty {
                            Text("z.B. \"Wie ich in 30 Tagen 5.000 Follower gewann\"")
                                .font(AVENFont.body(14)).foregroundColor(AVENColor.textMuted).padding(12)
                        }
                        TextEditor(text: $vm.topic)
                            .font(AVENFont.body(14)).foregroundColor(AVENColor.textPrimary)
                            .scrollContentBackground(.hidden).frame(minHeight: 90).focused($focused)
                    }
                    .padding(4).background(AVENColor.backgroundCard)
                    .clipShape(RoundedRectangle(cornerRadius: AVENRadius.md))
                    .overlay(RoundedRectangle(cornerRadius: AVENRadius.md)
                        .strokeBorder(focused ? AVENColor.accentPurple : AVENColor.borderSubtle, lineWidth: 1))
                }
                Button {
                    vm.topic = "Creator Wachstum & Profil-Optimierung"
                    vm.fromInsights = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles").foregroundColor(AVENColor.accentPurple)
                        Text("Aus meinen AVEN Insights erstellen")
                            .font(AVENFont.body(14, weight: .medium)).foregroundColor(AVENColor.accentPurple)
                        Spacer()
                        if vm.fromInsights { Image(systemName: "checkmark.circle.fill").foregroundColor(AVENColor.accentPurple) }
                    }
                    .padding(AVENSpacing.md).background(AVENColor.accentPurple.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: AVENRadius.md))
                    .overlay(RoundedRectangle(cornerRadius: AVENRadius.md)
                        .strokeBorder(AVENColor.accentPurple.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(PressButtonStyle())
                HStack(spacing: AVENSpacing.sm) {
                    BackButton { withAnimation { vm.step = .platform } }
                    AVENPrimaryButton(title: "Weiter", icon: "arrow.right") {
                        focused = false; withAnimation { vm.step = .settings }
                    }
                }
                .padding(.bottom, AVENSpacing.lg)
            }
            .padding(.horizontal, AVENSpacing.md)
        }
    }
}

// ─── Step 3 ───────────────────────────────────────────────────────────────────

private struct SettingsStep: View {
    @ObservedObject var vm: AIVideoCreatorViewModel
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AVENSpacing.lg) {
                VideoDragHandle()
                Text("Video-Einstellungen").font(AVENFont.display(22)).foregroundColor(AVENColor.textPrimary).padding(.top, AVENSpacing.sm)
                VStack(alignment: .leading, spacing: AVENSpacing.sm) {
                    Text("Stil").font(AVENFont.body(13, weight: .semibold)).foregroundColor(AVENColor.textSecondary)
                    VStack(spacing: 6) {
                        ForEach(VideoStyle.allCases, id: \.self) { s in
                            Button { vm.style = s } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(s.rawValue).font(AVENFont.body(14, weight: vm.style==s ? .semibold : .regular)).foregroundColor(AVENColor.textPrimary)
                                        Text(s.description).font(AVENFont.body(12)).foregroundColor(AVENColor.textSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: vm.style==s ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(vm.style==s ? AVENColor.accentPurple : AVENColor.borderSubtle)
                                }
                                .padding(AVENSpacing.sm)
                                .background(vm.style==s ? AVENColor.backgroundElevated : AVENColor.backgroundCard)
                                .clipShape(RoundedRectangle(cornerRadius: AVENRadius.sm))
                                .overlay(RoundedRectangle(cornerRadius: AVENRadius.sm)
                                    .strokeBorder(vm.style==s ? AVENColor.accentPurple.opacity(0.5) : AVENColor.borderSubtle, lineWidth: 1))
                            }
                            .buttonStyle(PressButtonStyle())
                        }
                    }
                }
                VStack(alignment: .leading, spacing: AVENSpacing.sm) {
                    Text("Videolänge").font(AVENFont.body(13, weight: .semibold)).foregroundColor(AVENColor.textSecondary)
                    HStack(spacing: 10) {
                        TextField("30", text: $vm.customDurationText)
                            .keyboardType(.numberPad)
                            .font(AVENFont.display(22))
                            .foregroundColor(AVENColor.textPrimary)
                            .multilineTextAlignment(.center)
                            .frame(width: 80).padding(.vertical, 10)
                            .background(AVENColor.backgroundCard)
                            .clipShape(RoundedRectangle(cornerRadius: AVENRadius.sm))
                            .overlay(RoundedRectangle(cornerRadius: AVENRadius.sm)
                                .strokeBorder(AVENColor.accentPurple.opacity(0.4), lineWidth: 1))
                        Text("Sekunden")
                            .font(AVENFont.body(15)).foregroundColor(AVENColor.textSecondary)
                        Spacer()
                    }
                }
                HStack(spacing: AVENSpacing.sm) {
                    BackButton { withAnimation { vm.step = .topic } }
                    AVENPrimaryButton(title: "Konzept erstellen", icon: "sparkles") {
                        Task { await vm.generate() }
                    }
                }
                .padding(.bottom, AVENSpacing.lg)
            }
            .padding(.horizontal, AVENSpacing.md)
        }
    }
}

// ─── Generating ───────────────────────────────────────────────────────────────

private struct GeneratingStep: View {
    @State private var rotation: Double = 0
    @State private var pulse = false
    @State private var labelIdx = 0
    private let labels = ["Analysiere dein Profil…","Erstelle Hook…","Schreibe Script…","Optimiere Konzept…"]
    var body: some View {
        VStack(spacing: AVENSpacing.xl) {
            Spacer()
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle().stroke(AVENColor.accentPurple.opacity(0.06+Double(2-i)*0.05), lineWidth: 1)
                        .frame(width: CGFloat(80+i*28), height: CGFloat(80+i*28))
                        .scaleEffect(pulse ? 1.04 : 1.0)
                        .animation(.easeInOut(duration:1.5).repeatForever().delay(Double(i)*0.2), value: pulse)
                }
                Circle().fill(LinearGradient(colors:[AVENColor.accentPurple.opacity(0.2),AVENColor.accentBlue.opacity(0.1)],startPoint:.topLeading,endPoint:.bottomTrailing)).frame(width:80,height:80)
                Image(systemName:"sparkles").font(.system(size:34))
                    .foregroundStyle(LinearGradient(colors:[AVENColor.accentPurple,AVENColor.accentBlue],startPoint:.topLeading,endPoint:.bottomTrailing))
                    .rotationEffect(.degrees(rotation))
                    .animation(.easeInOut(duration:3).repeatForever(autoreverses:true), value: rotation)
            }
            VStack(spacing: AVENSpacing.sm) {
                Text("Video-Konzept wird erstellt").font(AVENFont.display(22)).foregroundColor(AVENColor.textPrimary)
                Text(labels[labelIdx]).font(AVENFont.body(15)).foregroundColor(AVENColor.textSecondary).animation(.easeInOut, value: labelIdx)
            }
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(AVENColor.accentBlue).font(.system(size: 13))
                Text("AVEN erstellt ein Konzept — kein fertiges Video.")
                    .font(AVENFont.body(12)).foregroundColor(AVENColor.textSecondary)
            }
            .padding(.horizontal, AVENSpacing.xl)
            Spacer()
        }
        .onAppear {
            pulse = true; rotation = 360
            Timer.scheduledTimer(withTimeInterval: 0.9, repeats: true) { _ in labelIdx = (labelIdx+1) % labels.count }
        }
    }
}

// ─── Result ───────────────────────────────────────────────────────────────────

private struct ResultStep: View {
    let concept: AIVideoConcept
    @ObservedObject var vm: AIVideoCreatorViewModel
    let dismiss: () -> Void
    var onGenerateVideo: () -> Void = {}
    @EnvironmentObject private var container: AppContainer
    @State private var appeared = false
    @State private var showShareSheet = false
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AVENSpacing.lg) {
                VideoDragHandle()
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName:"checkmark.circle.fill").foregroundColor(AVENColor.textPositive)
                        Text("Konzept fertig").font(AVENFont.body(14,weight:.semibold)).foregroundColor(AVENColor.textPositive)
                    }
                    Text("Dein Video-Konzept").font(AVENFont.display(22)).foregroundColor(AVENColor.textPrimary)
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle").font(.system(size: 11)).foregroundColor(AVENColor.accentBlue)
                        Text("Konzept — kein fertiges Video").font(AVENFont.body(11)).foregroundColor(AVENColor.textSecondary)
                    }
                }
                .padding(.top, AVENSpacing.sm).opacity(appeared ? 1 : 0).animation(.easeOut(duration:0.4), value: appeared)

                Group {
                    VideoConceptSection(title:"🎣  Hook",    content: concept.hook)
                    VideoConceptSection(title:"📝  Script",  content: concept.script)
                    AVENCard {
                        VStack(alignment:.leading, spacing: AVENSpacing.sm) {
                            Text("🎬  Szenen-Struktur").font(AVENFont.body(14,weight:.semibold)).foregroundColor(AVENColor.textPrimary)
                            ForEach(concept.scenes) { scene in
                                HStack(alignment:.top, spacing: AVENSpacing.sm) {
                                    Text("\(scene.number)").font(AVENFont.mono(12)).foregroundColor(AVENColor.accentPurple).frame(width:18)
                                    VStack(alignment:.leading, spacing:2) {
                                        HStack {
                                            Text(scene.label).font(AVENFont.body(13,weight:.semibold)).foregroundColor(AVENColor.textPrimary)
                                            Spacer()
                                            Text(scene.duration).font(AVENFont.mono(11)).foregroundColor(AVENColor.textMuted)
                                        }
                                        Text(scene.description).font(AVENFont.body(12)).foregroundColor(AVENColor.textSecondary).lineSpacing(3)
                                    }
                                }
                                if scene.number < concept.scenes.count { Divider().background(AVENColor.borderSubtle) }
                            }
                        }
                    }
                    VideoConceptSection(title:"✍️  Caption", content: concept.caption)
                    AVENCard {
                        VStack(alignment:.leading, spacing:8) {
                            Text("#  Hashtags").font(AVENFont.body(14,weight:.semibold)).foregroundColor(AVENColor.textPrimary)
                            Text(concept.hashtags.joined(separator:"  ")).font(AVENFont.body(13)).foregroundColor(AVENColor.accentPurpleLight)
                        }
                    }
                }
                .offset(y: appeared ? 0 : 16).opacity(appeared ? 1 : 0).animation(.easeOut(duration:0.5).delay(0.15), value: appeared)

                VStack(spacing: AVENSpacing.sm) {

                    // Blueprint copy section
                    VStack(spacing: 12) {
                        Text("🎬 **Bereit zur Umsetzung?** Kopiere diesen Video-Plan und sende ihn an eine KI, die Videos generiert.")
                            .font(AVENFont.body(14, weight: .semibold))
                            .foregroundColor(AVENColor.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AVENSpacing.sm)

                        AVENPrimaryButton(title: "Video-Plan kopieren", icon: "doc.on.clipboard") {
                            if let concept = vm.concept {
                                UIPasteboard.general.string = concept.blueprintText
                            }
                        }
                    }

                    HStack(spacing: AVENSpacing.sm) {
                        Button { Task { await vm.regenerate() } } label: {
                            Label("Neu erstellen", systemImage:"arrow.clockwise")
                                .font(AVENFont.body(14,weight:.semibold)).foregroundColor(AVENColor.accentPurple)
                                .frame(maxWidth:.infinity).padding(.vertical,14)
                                .background(AVENColor.accentPurple.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius:AVENRadius.md))
                        }
                        .buttonStyle(PressButtonStyle())
                        Button { showShareSheet = true } label: {
                            Label("Teilen", systemImage:"square.and.arrow.up")
                                .font(AVENFont.body(14,weight:.semibold)).foregroundColor(AVENColor.textSecondary)
                                .frame(maxWidth:.infinity).padding(.vertical,14)
                                .background(AVENColor.backgroundCard)
                                .clipShape(RoundedRectangle(cornerRadius:AVENRadius.md))
                                .overlay(RoundedRectangle(cornerRadius:AVENRadius.md).strokeBorder(AVENColor.borderSubtle,lineWidth:1))
                        }
                        .buttonStyle(PressButtonStyle())
                    }
                    Button { dismiss() } label: {
                        Text("Fertig").font(AVENFont.body(15)).foregroundColor(AVENColor.textSecondary)
                            .frame(maxWidth:.infinity).padding(.vertical,14)
                    }
                    .buttonStyle(PressButtonStyle())
                }
                .padding(.bottom, AVENSpacing.xl)
            }
            .padding(.horizontal, AVENSpacing.md)
        }
        .onAppear { withAnimation { appeared = true } }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [buildShareText(concept)])
        }
    }
    private func buildShareText(_ c: AIVideoConcept) -> String {
        "AVEN Video-Konzept\n\nHook: \(c.hook)\n\nScript:\n\(c.script)\n\nCaption: \(c.caption)\n\nHashtags: \(c.hashtags.joined(separator:" "))"
    }
}

private struct VideoConceptSection: View {
    let title: String; let content: String
    var body: some View {
        AVENCard {
            VStack(alignment:.leading, spacing:8) {
                Text(title).font(AVENFont.body(14,weight:.semibold)).foregroundColor(AVENColor.textPrimary)
                Text(content).font(AVENFont.body(13)).foregroundColor(AVENColor.textSecondary).lineSpacing(4).fixedSize(horizontal:false,vertical:true)
            }
        }
    }
}

// ─── Share sheet ──────────────────────────────────────────────────────────────

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// ─── ViewModel ────────────────────────────────────────────────────────────────

enum AIVideoStep: Int, Comparable {
    case platform = 0, topic = 1, settings = 2, generating = 3, result = 4, rendering = 5, videoResult = 6
    static func < (l: AIVideoStep, r: AIVideoStep) -> Bool { l.rawValue < r.rawValue }
}

@MainActor
final class AIVideoCreatorViewModel: ObservableObject {
    @Published var step:              AIVideoStep  = .platform
    @Published var platform:          VideoPlatform = .tiktok
    @Published var topic:             String        = ""
    @Published var fromInsights:      Bool          = false
    @Published var style:             VideoStyle    = .viral
    @Published var duration:          VideoDuration = .medium
    @Published var customDurationText: String       = "30"
    @Published var concept:           AIVideoConcept?
    @Published var videoStatus:       VideoRenderStatus?
    @Published var videoJobId:        String?
    var customDurationSeconds: Int {
        let raw = Int(customDurationText.filter(\.isNumber)) ?? 30
        return min(90, max(1, raw))
    }

    private let service:      AIVideoServiceProtocol = LiveAIVideoService()
    private let renderService: AVENVideoRenderServiceProtocol = BackendVideoRenderService()

    func generate() async {
        withAnimation { step = .generating }
        let req = AIVideoRequest(platform: platform, topic: topic, style: style, duration: duration, fromInsights: fromInsights, customSeconds: customDurationSeconds)
        do {
            concept = try await service.generateConcept(request: req)
            withAnimation { step = .result }
        } catch {
            withAnimation { step = .settings }
        }
    }
    func regenerate() async { concept = nil; await generate() }

    func startVideoRender() async {
        guard let concept else { return }

        withAnimation { step = .rendering }
        videoStatus = .queued

        // Real video generation requires the AVEN backend with RUNWAY_API_KEY set
        guard let backendURL = AVENBackendConfig.backendURL else {
            videoStatus = .failed(
                "Video-Generierung benötigt das AVEN-Backend.\n\n" +
                "Setze AVEN_API_URL in den Xcode-Umgebungsvariablen und " +
                "RUNWAY_API_KEY im Backend, um echte KI-Videos zu generieren.\n\n" +
                "Mehr Infos: ios/AVEN/VIDEO_SETUP.md"
            )
            withAnimation { step = .videoResult }
            return
        }

        // Check if video endpoint is configured on the backend
        if let statusURL = URL(string: "\(backendURL)/video/render/status") {
            if let (data, _) = try? await URLSession.shared.data(from: statusURL),
               let json = try? JSONDecoder().decode([String: Bool].self, from: data),
               json["configured"] == false {
                videoStatus = .failed(
                    "Video-Generierung ist nicht konfiguriert.\n\n" +
                    "Setze RUNWAY_API_KEY als Umgebungsvariable im AVEN-Backend.\n\n" +
                    "Registriere dich auf https://app.runwayml.com und kopiere deinen API-Key."
                )
                withAnimation { step = .videoResult }
                return
            }
        }

        do {
            let jobId = try await renderService.submitRenderJob(
                concept: concept,
                backendBaseURL: backendURL,
                authToken: "dev-token"  // MARK: replace with real session token
            )
            videoJobId = jobId
            await pollRenderJob(jobId: jobId, backendURL: backendURL)
        } catch {
            videoStatus = .failed("Fehler beim Starten der Video-Generierung:\n\(error.localizedDescription)")
            withAnimation { step = .videoResult }
        }
    }

    private func pollRenderJob(jobId: String, backendURL: String) async {
        // Poll every 3 seconds, max 5 minutes
        let maxAttempts = 100
        for _ in 0..<maxAttempts {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            do {
                let status = try await renderService.pollJobStatus(
                    jobId: jobId, backendBaseURL: backendURL, authToken: "dev-token"
                )
                videoStatus = status
                if case .completed = status {
                    withAnimation { step = .videoResult }
                    return
                }
                if case .failed = status {
                    withAnimation { step = .videoResult }
                    return
                }
            } catch {
                videoStatus = .failed(error.localizedDescription)
                withAnimation { step = .videoResult }
                return
            }
        }
        videoStatus = .failed("Zeitlimit überschritten. Bitte erneut versuchen.")
        withAnimation { step = .videoResult }
    }
}

// ─── Shared local helpers ─────────────────────────────────────────────────────

private struct VideoDragHandle: View {
    var body: some View {
        Capsule().fill(AVENColor.borderSubtle).frame(width:36,height:4).padding(.top,AVENSpacing.sm)
    }
}

private struct BackButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text("Zurück").font(AVENFont.body(15)).foregroundColor(AVENColor.textSecondary)
                .frame(maxWidth:.infinity).padding(.vertical,16)
                .background(AVENColor.backgroundCard)
                .clipShape(RoundedRectangle(cornerRadius:AVENRadius.md))
        }
        .buttonStyle(PressButtonStyle())
    }
}

// ─── Video Rendering Step ─────────────────────────────────────────────────────

private struct VideoRenderingStep: View {
    @ObservedObject var vm: AIVideoCreatorViewModel
    @State private var rotation: Double = 0
    @State private var pulse = false

    var progressValue: Double {
        if case .processing(let p) = vm.videoStatus { return p / 100.0 }
        if case .queued = vm.videoStatus { return 0.05 }
        return 0
    }

    var statusLabel: String {
        switch vm.videoStatus {
        case .queued:           return "In Warteschlange…"
        case .processing:       return "Video wird generiert…"
        case .completed:        return "Fertig!"
        case .failed:           return "Fehler"
        case .none:             return "Starte…"
        }
    }

    var body: some View {
        VStack(spacing: AVENSpacing.xl) {
            Spacer()
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle().stroke(AVENColor.accentPurple.opacity(0.06 + Double(2-i)*0.05), lineWidth: 1)
                        .frame(width: CGFloat(80+i*28), height: CGFloat(80+i*28))
                        .scaleEffect(pulse ? 1.04 : 1.0)
                        .animation(.easeInOut(duration:1.5).repeatForever().delay(Double(i)*0.2), value: pulse)
                }
                Circle().fill(LinearGradient(colors:[AVENColor.accentPurple.opacity(0.2),AVENColor.accentBlue.opacity(0.1)],startPoint:.topLeading,endPoint:.bottomTrailing)).frame(width:80,height:80)
                Image(systemName:"film.fill").font(.system(size:34))
                    .foregroundStyle(LinearGradient(colors:[AVENColor.accentPurple,AVENColor.accentBlue],startPoint:.topLeading,endPoint:.bottomTrailing))
                    .rotationEffect(.degrees(rotation))
                    .animation(.linear(duration:4).repeatForever(autoreverses:false), value: rotation)
            }
            VStack(spacing: AVENSpacing.sm) {
                Text("Video wird generiert").font(AVENFont.display(22)).foregroundColor(AVENColor.textPrimary)
                Text(statusLabel).font(AVENFont.body(15)).foregroundColor(AVENColor.textSecondary)
            }
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(AVENColor.borderSubtle)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors:[AVENColor.accentPurple,AVENColor.accentBlue],startPoint:.leading,endPoint:.trailing))
                        .frame(width: geo.size.width * progressValue)
                        .animation(.easeInOut(duration:0.5), value: progressValue)
                }
            }
            .frame(height: 6).padding(.horizontal, AVENSpacing.xl)
            AVENCard {
                HStack(spacing: 8) {
                    Image(systemName:"info.circle.fill").foregroundColor(AVENColor.accentBlue).font(.system(size:13))
                    Text("Dieses Feature benötigt einen konfigurierten Video-API-Provider im AVEN-Backend.").font(AVENFont.body(12)).foregroundColor(AVENColor.textSecondary).lineSpacing(3)
                }
            }
            .padding(.horizontal, AVENSpacing.md)
            Spacer()
        }
        .onAppear { pulse = true; rotation = 360 }
    }
}

// ─── Video Result Step ────────────────────────────────────────────────────────

private struct VideoResultStep: View {
    let videoURL: URL
    @ObservedObject var vm: AIVideoCreatorViewModel
    let dismiss: () -> Void
    @State private var showShareSheet = false
    @State private var player: AVPlayer?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AVENSpacing.lg) {
                VideoDragHandle()
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(AVENColor.textPositive)
                        Text("Video fertig").font(AVENFont.body(14,weight:.semibold)).foregroundColor(AVENColor.textPositive)
                    }
                    Text("Dein generiertes Video").font(AVENFont.display(22)).foregroundColor(AVENColor.textPrimary)
                }
                .padding(.top, AVENSpacing.sm)

                // Real AVPlayer — plays the generated demo/backend video inline
                AVENCard(accentBorder: true) {
                    VStack(spacing: AVENSpacing.sm) {
                        if let player {
                            VideoPlayer(player: player)
                                .frame(height: 320)
                                .clipShape(RoundedRectangle(cornerRadius: AVENRadius.md))
                                .onDisappear { player.pause() }
                        } else {
                            // Shown for a split second while player initialises
                            RoundedRectangle(cornerRadius: AVENRadius.md)
                                .fill(AVENColor.backgroundElevated)
                                .frame(height: 320)
                                .overlay(
                                    ProgressView().tint(AVENColor.accentPurple)
                                )
                        }
                        Text(videoURL.lastPathComponent)
                            .font(AVENFont.mono(11)).foregroundColor(AVENColor.textMuted).lineLimit(1)
                    }
                }
                .onAppear {
                    let p = AVPlayer(url: videoURL)
                    p.play()
                    player = p
                }

                VStack(spacing: AVENSpacing.sm) {
                    AVENPrimaryButton(title: "Video speichern", icon: "square.and.arrow.down") {
                        saveVideoToPhotoLibrary(url: videoURL)
                    }
                    HStack(spacing: AVENSpacing.sm) {
                        Button { showShareSheet = true } label: {
                            Label("Teilen", systemImage:"square.and.arrow.up")
                                .font(AVENFont.body(14,weight:.semibold)).foregroundColor(AVENColor.textSecondary)
                                .frame(maxWidth:.infinity).padding(.vertical,14)
                                .background(AVENColor.backgroundCard)
                                .clipShape(RoundedRectangle(cornerRadius:AVENRadius.md))
                                .overlay(RoundedRectangle(cornerRadius:AVENRadius.md).strokeBorder(AVENColor.borderSubtle,lineWidth:1))
                        }
                        .buttonStyle(PressButtonStyle())
                        Button { Task { await vm.startVideoRender() } } label: {
                            Label("Neu", systemImage:"arrow.clockwise")
                                .font(AVENFont.body(14,weight:.semibold)).foregroundColor(AVENColor.accentPurple)
                                .frame(maxWidth:.infinity).padding(.vertical,14)
                                .background(AVENColor.accentPurple.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius:AVENRadius.md))
                        }
                        .buttonStyle(PressButtonStyle())
                    }
                    Button { dismiss() } label: {
                        Text("Fertig").font(AVENFont.body(15)).foregroundColor(AVENColor.textSecondary)
                            .frame(maxWidth:.infinity).padding(.vertical,14)
                    }
                    .buttonStyle(PressButtonStyle())
                }
                .padding(.bottom, AVENSpacing.xl)
            }
            .padding(.horizontal, AVENSpacing.md)
        }
        .sheet(isPresented: $showShareSheet) { ShareSheet(items: [videoURL]) }
    }

    private func saveVideoToPhotoLibrary(url: URL) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            } completionHandler: { success, _ in
                if success { AVENHaptic.success() }
            }
        }
    }
}

// ─── Video render failed view ─────────────────────────────────────────────────

private struct VideoRenderFailedView: View {
    let message: String
    @ObservedObject var vm: AIVideoCreatorViewModel
    let dismiss: () -> Void

    private var isSetupIssue: Bool {
        message.contains("RUNWAY_API_KEY") || message.contains("AVEN_API_URL") || message.contains("konfiguriert")
    }

    var body: some View {
        VStack(spacing: AVENSpacing.xl) {
            VideoDragHandle()
            Spacer()
            Image(systemName: isSetupIssue ? "wrench.and.screwdriver.fill" : "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(isSetupIssue
                    ? LinearGradient(colors: [AVENColor.accentPurple, AVENColor.accentBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [AVENColor.textNegative], startPoint: .leading, endPoint: .trailing))

            Text(isSetupIssue ? "Video-Generierung einrichten" : "Video konnte nicht generiert werden")
                .font(AVENFont.display(20)).foregroundColor(AVENColor.textPrimary).multilineTextAlignment(.center)

            AVENCard(accentBorder: isSetupIssue) {
                Text(message).font(AVENFont.body(13)).foregroundColor(AVENColor.textSecondary).lineSpacing(5)
            }

            Spacer()
            VStack(spacing: AVENSpacing.sm) {
                Button { withAnimation { vm.step = .result } } label: {
                    Text("Zurück zum Konzept")
                        .font(AVENFont.body(15)).foregroundColor(AVENColor.accentPurple)
                        .frame(maxWidth:.infinity).padding(.vertical,14)
                        .background(AVENColor.accentPurple.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius:AVENRadius.md))
                }
                .buttonStyle(PressButtonStyle())
                Button { dismiss() } label: {
                    Text("Schließen").font(AVENFont.body(15)).foregroundColor(AVENColor.textSecondary)
                        .frame(maxWidth:.infinity).padding(.vertical,14)
                }
                .buttonStyle(PressButtonStyle())
            }
            .padding(.horizontal, AVENSpacing.md).padding(.bottom, AVENSpacing.lg)
        }
        .padding(.horizontal, AVENSpacing.md)
    }
}

// ─── Video limit sheet ────────────────────────────────────────────────────────

private struct VideoLimitSheet: View {
    @ObservedObject var credits: VideoCreditsService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AVENColor.backgroundPrimary.ignoresSafeArea()
            VStack(spacing: AVENSpacing.xl) {
                Capsule().fill(AVENColor.borderSubtle).frame(width: 36, height: 4).padding(.top, AVENSpacing.sm)
                Spacer()
                VStack(spacing: AVENSpacing.md) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [AVENColor.accentPurple.opacity(0.2), AVENColor.accentBlue.opacity(0.1)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 80, height: 80)
                        Image(systemName: "film.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(LinearGradient(
                                colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                    Text("Video-Limit erreicht")
                        .font(AVENFont.display(22)).foregroundColor(AVENColor.textPrimary)
                    Text("Video-Blueprint-Erstellung ist in \(credits.currentPlan.displayName) verfügbar. Upgrade für Zugriff auf alle AVEN Premium-Funktionen.")
                        .font(AVENFont.body(15)).foregroundColor(AVENColor.textSecondary)
                        .multilineTextAlignment(.center).lineSpacing(4)
                        .padding(.horizontal, AVENSpacing.lg)
                    AVENCard {
                        VStack(spacing: 8) {
                            LimitRow(plan: "PRO",  limit: "Video-Blueprint")
                            Divider().background(AVENColor.borderSubtle)
                            LimitRow(plan: "PRO+", limit: "Unbegrenzte Blueprints")
                        }
                    }
                    .padding(.horizontal, AVENSpacing.md)
                }
                Spacer()
                VStack(spacing: AVENSpacing.sm) {
                    AVENPrimaryButton(title: "Plan upgraden", icon: "star.fill") { dismiss() }
                    Button { dismiss() } label: {
                        Text("Schließen").font(AVENFont.body(15)).foregroundColor(AVENColor.textSecondary)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                    }
                    .buttonStyle(PressButtonStyle())
                }
                .padding(.horizontal, AVENSpacing.md).padding(.bottom, AVENSpacing.lg)
            }
        }
        .presentationDetents([.large]).presentationCornerRadius(28)
    }
}

private struct LimitRow: View {
    let plan:  String
    let limit: String
    var body: some View {
        HStack {
            Text(plan).font(AVENFont.body(14, weight: .semibold)).foregroundColor(AVENColor.textPrimary)
            Spacer()
            Text(limit).font(AVENFont.body(13)).foregroundColor(AVENColor.accentPurpleLight)
        }
    }
}

#Preview { AIVideoCreatorView() }
