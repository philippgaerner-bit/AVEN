import SwiftUI
import PhotosUI
import CoreTransferable
import UniformTypeIdentifiers

// ─── AVEN + Menu ──────────────────────────────────────────────────────────────
// The approved reference is treated as the visual source of truth: one compact
// screen, premium hero, 2x2 analysis grid, four small growth tools and PRO+ CTA.

struct CreationMenuSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var container: AppContainer
    @Binding var showNewScan: Bool
    @Binding var showAIVideo: Bool

    @State private var showCoach       = false
    @State private var showVideoSheet  = false
    @State private var showGoalSetter  = false
    @State private var showGrowthExp   = false
    @State private var showPaywall     = false
    @State private var showContentIdeas = false
    @State private var showPostingTime = false
    @State private var showAccountPerformance = false
    @State private var showComing      = false
    @State private var comingTitle     = ""

    var body: some View {
        ZStack {
            AVENColor.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                ViewThatFits(in: .vertical) {
                    compactContent
                    ScrollView(showsIndicators: false) { compactContent }
                }
                CMBottomBar(selectedTab: $container.selectedTab) { dismiss() }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .sheet(isPresented: $showCoach) {
            if container.videoCredits.hasCoachAccess { AICoachView() }
            else { CoachProPlusGate() }
        }
        .sheet(isPresented: $showVideoSheet) { VideoAnalysisSheet() }
        .sheet(isPresented: $showContentIdeas) { ContentIdeasSheet() }
        .sheet(isPresented: $showPostingTime) { PostingTimeSheet() }
        .sheet(isPresented: $showAccountPerformance) { AccountPerformanceSheet() }
        .sheet(isPresented: $showGoalSetter) { GoalSetterSheet() }
        .sheet(isPresented: $showGrowthExp)  { GrowthExperimentSheet() }
        .sheet(isPresented: $showPaywall)    { PaywallView() }
        .sheet(isPresented: $showComing)     { CMComingSoon(title: comingTitle) }
    }

    private var compactContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            CMLabel("Für dich empfohlen")
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 7)

            Button { showGrowthExp = true } label: { HeroCard() }
                .buttonStyle(PressButtonStyle())
                .padding(.horizontal, 20)

            CMLabel("Analysieren & Verstehen")
                .padding(.horizontal, 20)
                .padding(.top, 13)
                .padding(.bottom, 7)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)],
                spacing: 9
            ) {
                CMAnalCard(
                    icon: "person.crop.rectangle", title: "Neue Profilanalyse",
                    desc: "Profil neu analysieren und deinen AVEN Score aktualisieren.", badge: nil
                ) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showNewScan = true }
                }

                CMAnalCard(
                    icon: "play.rectangle", title: "Video analysieren",
                    desc: "Video hochladen und Hook, Inhalt, CTA, Tempo u. v. m. analysieren.", badge: nil
                ) { showVideoSheet = true }

                CMAnalCard(
                    icon: "ellipsis.message", title: "AI Coach",
                    desc: "Persönliche Fragen zu deinem Account stellen und individuelle Empfehlungen erhalten.", badge: "PRO+"
                ) { showCoach = true }

                CMAnalCard(
                    icon: "chart.bar.xaxis", title: "Account Performance analysieren",
                    desc: "Aktuelle TikTok-Daten und deine Entwicklung auswerten.", badge: nil
                ) { showAccountPerformance = true }
            }
            .padding(.horizontal, 20)

            CMLabel("Wachstum & Tools")
                .padding(.horizontal, 20)
                .padding(.top, 13)
                .padding(.bottom, 7)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)
                ],
                spacing: 8
            ) {
                CMToolCard(icon: "lightbulb", title: "Content-Idee\ngenerieren",
                           desc: "Kreative Ideen für viralen Content.") {
                    showContentIdeas = true
                }
                CMToolCard(icon: "clock", title: "Beste\nPosting-Zeit",
                           desc: "Finde heraus, wann deine Community am aktivsten ist.") {
                    showPostingTime = true
                }
                CMToolCard(icon: "target", title: "Ziel setzen",
                           desc: "Setze klare Ziele und wir erstellen den passenden Plan.") {
                    showGoalSetter = true
                }
                CMToolCard(icon: "flask", title: "Growth\nExperiment",
                           desc: "Teste Hooks, Formate und Strategien gezielt.") {
                    showGrowthExp = true
                }
            }
            .padding(.horizontal, 20)

            Button { showPaywall = true } label: { proBanner }
                .buttonStyle(PressButtonStyle())
                .padding(.horizontal, 20)
                .padding(.top, 11)
                .padding(.bottom, 8)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(AVENColor.textPrimary)
                            .frame(width: 38, height: 38)
                    }
                    .buttonStyle(PressButtonStyle())
                    Spacer()
                }

                CMWordmark()
            }
            .padding(.horizontal, 17)
            .padding(.top, 8)
            .padding(.bottom, 12)

            Text("Was möchtest du tun?")
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .foregroundColor(AVENColor.textPrimary)
                .padding(.horizontal, 20)

            Text("Wähle eine Option, um dein Wachstum gezielt voranzutreiben.")
                .font(.system(size: 12.2, weight: .regular))
                .foregroundColor(AVENColor.textSecondary)
                .padding(.horizontal, 20)
                .padding(.top, 4)
        }
    }

    private var proBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AVENColor.accentPurple)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 3) {
                    Text("Noch mehr Power mit")
                        .foregroundColor(AVENColor.textPrimary)
                    Text("PRO+")
                        .foregroundColor(AVENColor.accentPurple)
                }
                .font(.system(size: 10.5, weight: .semibold))

                Text("Schalte den AI Coach und weitere Premium-Features frei.")
                    .font(.system(size: 8.6))
                    .foregroundColor(AVENColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 3)

            Text("PRO+ entdecken")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    LinearGradient(
                        colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .padding(.horizontal, 11)
        .frame(height: 43)
        .background(AVENColor.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(AVENColor.accentPurple.opacity(0.22), style: StrokeStyle(lineWidth: 0.8, dash: [4, 3]))
        )
    }
}

// ─── AVEN wordmark ────────────────────────────────────────────────────────────

private struct CMWordmark: View {
    var body: some View {
        HStack(spacing: 8) {
            Image("AVENMark")
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 34)
                .shadow(color: AVENColor.accentPurple.opacity(0.10), radius: 5, y: 2)

            Text("AVEN")
                .font(.system(size: 18, weight: .medium, design: .default))
                .tracking(6.4)
                .foregroundColor(AVENColor.textPrimary)
                .offset(x: 2)
        }
    }
}

private struct CMLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 13.2, weight: .bold, design: .rounded))
            .foregroundColor(AVENColor.textPrimary)
    }
}

// ─── Premium Growth Experiment hero ───────────────────────────────────────────

private struct HeroCard: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AVENColor.accentPurple.opacity(0.13),
                    AVENColor.backgroundCard,
                    AVENColor.accentBlue.opacity(0.09)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [AVENColor.accentPurple.opacity(0.14), .clear],
                center: .trailing,
                startRadius: 5,
                endRadius: 145
            )

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("✦  Empfohlen")
                        .font(.system(size: 9.4, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#8D43FF"), Color(hex: "#6153F4")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())

                    Text("Growth Experiment")
                        .font(.system(size: 18.5, weight: .bold, design: .rounded))
                        .foregroundColor(AVENColor.textPrimary)
                        .padding(.top, 10)

                    Text("Teste gezielt, was bei deinem\nAccount wirklich funktioniert.")
                        .font(.system(size: 11.2, weight: .regular))
                        .foregroundColor(AVENColor.textSecondary)
                        .lineSpacing(2)
                        .padding(.top, 5)

                    HStack(spacing: 6) {
                        Text("Jetzt starten")
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9.5, weight: .semibold))
                    }
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(AVENColor.accentPurple)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(AVENColor.backgroundCard.opacity(0.92))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: AVENColor.accentPurple.opacity(0.08), radius: 4, y: 1)
                    .padding(.top, 9)
                }
                .padding(.leading, 17)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)

                ZStack {
                    Image(systemName: "sparkle")
                        .font(.system(size: 13))
                        .foregroundColor(AVENColor.accentPurple.opacity(0.50))
                        .offset(x: -52, y: -30)
                    Image(systemName: "sparkle")
                        .font(.system(size: 10))
                        .foregroundColor(AVENColor.accentBlue.opacity(0.40))
                        .offset(x: 45, y: -22)

                    AVENFlaskView(animated: true)
                        .frame(width: 138, height: 119)
                        .offset(x: 2, y: 2)
                }
                .frame(width: 148, height: 124)
            }
        }
        .frame(height: 124)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(AVENColor.accentPurple.opacity(0.18), lineWidth: 0.8)
        )
        .shadow(color: AVENColor.accentPurple.opacity(0.07), radius: 8, y: 3)
    }
}

private struct CMAnalCard: View {
    let icon: String
    let title: String
    let desc: String
    let badge: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .top) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(AVENColor.accentPurple.opacity(0.10))
                            .frame(width: 34, height: 34)
                        Image(systemName: icon)
                            .font(.system(size: 14.5, weight: .medium))
                            .foregroundColor(AVENColor.accentPurple)
                    }
                    Spacer()
                    if let badge {
                        Text(badge)
                            .font(.system(size: 7.7, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2.5)
                            .background(AVENColor.accentPurple)
                            .clipShape(Capsule())
                    }
                }

                Text(title)
                    .font(.system(size: 11.4, weight: .bold, design: .rounded))
                    .foregroundColor(AVENColor.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(desc)
                    .font(.system(size: 8.85))
                    .foregroundColor(AVENColor.textSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                HStack {
                    Spacer()
                    ZStack {
                        Circle().fill(AVENColor.accentPurple.opacity(0.08)).frame(width: 25, height: 25)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundColor(AVENColor.accentPurple)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 106, maxHeight: 106, alignment: .topLeading)
             .background(AVENColor.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(AVENColor.borderSubtle, lineWidth: 0.5)
            )
            .shadow(color: AVENColor.cardShadow, radius: 5, y: 2)
        }
        .buttonStyle(PressButtonStyle())
    }
}

private struct CMToolCard: View {
    let icon: String
    let title: String
    let desc: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(AVENColor.accentPurple.opacity(0.10))
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 12.5))
                        .foregroundColor(AVENColor.accentPurple)
                }

                Text(title)
                    .font(.system(size: 9.3, weight: .bold, design: .rounded))
                    .foregroundColor(AVENColor.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(desc)
                    .font(.system(size: 7.55))
                    .foregroundColor(AVENColor.textSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                HStack {
                    Spacer()
                    ZStack {
                        Circle().fill(AVENColor.accentPurple.opacity(0.08)).frame(width: 22, height: 22)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 8.5, weight: .semibold))
                            .foregroundColor(AVENColor.accentPurple)
                    }
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, minHeight: 94, maxHeight: 94, alignment: .topLeading)
             .background(AVENColor.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(AVENColor.borderSubtle, lineWidth: 0.5)
            )
            .shadow(color: AVENColor.cardShadow, radius: 4, y: 1)
        }
        .buttonStyle(PressButtonStyle())
    }
}

// ─── Bottom tab bar ───────────────────────────────────────────────────────────

private struct CMBottomBar: View {
    @Binding var selectedTab: AppTab
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            CMTab(icon: "house", label: "Home") {
                onDismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { selectedTab = .home }
            }
            CMTab(icon: "chart.bar", label: "Analyse") {
                onDismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { selectedTab = .analytics }
            }

            ZStack {
                Circle()
                     .fill(AVENColor.backgroundCard)
                    .frame(width: 49, height: 49)
                Circle()
                    .stroke(AVENColor.accentPurple.opacity(0.72), lineWidth: 1.5)
                    .frame(width: 49, height: 49)
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(AVENColor.accentPurple)
            }
            .frame(maxWidth: .infinity)
            .offset(y: -7)

            CMTab(icon: "checklist", label: "Plan") {
                onDismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { selectedTab = .actionPlan }
            }
            CMTab(icon: "person", label: "Profil") {
                onDismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { selectedTab = .profile }
            }
        }
        .padding(.top, 7)
        .padding(.bottom, 25)
        .background(
            AVENColor.backgroundCard
                .overlay(
                    Rectangle().frame(height: 0.5).foregroundColor(AVENColor.borderSubtle),
                    alignment: .top
                )
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

private struct CMTab: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 17.5))
                Text(label).font(.system(size: 9.5))
            }
            .foregroundColor(AVENColor.textMuted)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
private struct CMComingSoon: View {
    let title: String
    @Environment(\.dismiss) private var dismiss

    private var details: (icon: String, color: Color, points: [String]) {
        switch title {
        case _ where title.contains("Content"):
            return ("lightbulb.fill", AVENColor.accentBlue, [
                "KI-generierte Ideen basierend auf deiner Nische",
                "Trending Hooks & Formate für TikTok",
                "Passende Hashtag-Vorschläge"])
        case _ where title.contains("Posting"):
            return ("clock.fill", Color(hex: "#16A34A"), [
                "Analyse deiner Follower-Aktivität",
                "Beste Posting-Zeit pro Wochentag",
                "Vergleich mit ähnlichen Accounts"])
        default:
            return ("chart.xyaxis.line", AVENColor.accentPurple, [
                "Follower-Wachstum im Zeitverlauf",
                "View- und Engagement-Trends",
                "Konkrete Verbesserungs-Empfehlungen"])
        }
    }

    var body: some View {
        ZStack {
            AVENColor.backgroundPrimary.ignoresSafeArea()
            VStack(spacing: 0) {
                Capsule().fill(AVENColor.borderSubtle).frame(width: 36, height: 4).padding(.top, 10)
                HStack {
                    Text(title).font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(AVENColor.textPrimary)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 22))
                            .foregroundColor(AVENColor.textMuted)
                    }.buttonStyle(PressButtonStyle())
                }.padding(.horizontal, 16).padding(.vertical, 12)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10).fill(details.color.opacity(0.10))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: details.icon).font(.system(size: 16))
                                        .foregroundColor(details.color)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(title).font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(AVENColor.textPrimary)
                                    Text("Kommt bald").font(.system(size: 11))
                                        .foregroundColor(AVENColor.textMuted)
                                }
                            }
                            Divider().background(AVENColor.borderSubtle)
                            ForEach(details.points, id: \.self) { pt in
                                HStack(spacing: 8) {
                                    Circle().fill(details.color).frame(width: 5, height: 5)
                                    Text(pt).font(.system(size: 13))
                                        .foregroundColor(AVENColor.textSecondary)
                                }
                            }
                        }
                        .padding(14) .background(AVENColor.backgroundCard)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(AVENColor.borderSubtle, lineWidth: 0.5))

                        HStack(spacing: 10) {
                            Image(systemName: "bolt.circle.fill").font(.system(size: 20))
                                .foregroundColor(AVENColor.accentPurple)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("In Entwicklung").font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AVENColor.textPrimary)
                                Text("Wird mit dem AVEN-Backend freigeschaltet.")
                                    .font(.system(size: 11)).foregroundColor(AVENColor.textSecondary)
                            }
                        }
                        .padding(13).background(AVENColor.accentPurple.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(AVENColor.accentPurple.opacity(0.18), lineWidth: 1))
                    }.padding(16)
                }
                Button { dismiss() } label: {
                    Text("Schließen").font(.system(size: 15)).foregroundColor(AVENColor.textSecondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                }.buttonStyle(PressButtonStyle()).padding(.horizontal, 16).padding(.bottom, 28)
            }
        }
        .presentationDetents([.medium, .large]).presentationCornerRadius(28)
    }
}

private struct AISheetHeader: View {
    let title: String
    let dismiss: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(AVENColor.borderSubtle).frame(width: 36, height: 4).padding(.top, 10)
            HStack {
                Text(title).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(AVENColor.textPrimary)
                Spacer()
                Button(action: dismiss) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 22)).foregroundColor(AVENColor.textMuted)
                }.buttonStyle(PressButtonStyle())
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
    }
}

private struct AIErrorCard: View {
    let message: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
            Text(message).font(.system(size: 12)).foregroundColor(AVENColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12).background(Color.orange.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}


private struct AVENPickedVideoFile: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { SentTransferredFile($0.url) } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let destination = FileManager.default.temporaryDirectory.appendingPathComponent("aven-video-\(UUID().uuidString).\(ext)")
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(at: received.file, to: destination)
            return AVENPickedVideoFile(url: destination)
        }
    }
}

private struct VideoAnalysisSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var container: AppContainer
    @State private var photoItem: PhotosPickerItem?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var result: AVENVideoAnalysis?

    var body: some View {
        ZStack {
            AVENColor.backgroundPrimary.ignoresSafeArea()
            VStack(spacing: 0) {
                AISheetHeader(title: "Video analysieren") { dismiss() }
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        if let result { resultView(result) } else { pickerView }
                        if let errorMessage { AIErrorCard(message: errorMessage) }
                    }.padding(16)
                }
            }
        }
        .presentationDetents([.large]).presentationCornerRadius(28)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await analyze(item) }
        }
    }

    private var pickerView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(AVENColor.accentBlue.opacity(0.10)).frame(width: 74, height: 74)
                Image(systemName: "video.fill").font(.system(size: 29)).foregroundColor(AVENColor.accentBlue)
            }
            VStack(spacing: 5) {
                Text("Echte KI-Videoanalyse").font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(AVENColor.textPrimary)
                Text("AVEN extrahiert lokal repräsentative Frames und analysiert Hook, Inhalt, CTA, Tempo und Klarheit über deinen AVEN AI-Backend.")
                    .font(.system(size: 12)).foregroundColor(AVENColor.textSecondary).multilineTextAlignment(.center).lineSpacing(3)
            }
            if isLoading {
                VStack(spacing: 9) {
                    ProgressView().tint(AVENColor.accentPurple)
                    Text("Video wird vorbereitet und analysiert …").font(.system(size: 12, weight: .medium)).foregroundColor(AVENColor.textSecondary)
                }.padding(.vertical, 12)
            } else {
                PhotosPicker(selection: $photoItem, matching: .videos, photoLibrary: .shared()) {
                    HStack(spacing: 8) { Image(systemName: "video.badge.plus"); Text("Video auswählen") }
                        .font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(LinearGradient(colors: [AVENColor.accentPurple, AVENColor.accentBlue], startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }.buttonStyle(.plain)
            }
        }
        .padding(18).background(AVENColor.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(AVENColor.borderSubtle, lineWidth: 0.6))
    }

    private struct VideoMetric {
        let title: String
        let icon: String
        let category: AVENVideoCategory
    }

    private func metrics(_ r: AVENVideoAnalysis) -> [VideoMetric] {
        [
            VideoMetric(title: "Hook", icon: "bolt.fill", category: r.hook),
            VideoMetric(title: "Inhalt", icon: "play.rectangle.fill", category: r.content),
            VideoMetric(title: "CTA", icon: "hand.tap.fill", category: r.cta),
            VideoMetric(title: "Tempo", icon: "speedometer", category: r.pacing),
            VideoMetric(title: "Klarheit", icon: "eye.fill", category: r.clarity)
        ]
    }

    @ViewBuilder private func resultView(_ r: AVENVideoAnalysis) -> some View {
        let all = metrics(r)
        let strongest = all.max { $0.category.score < $1.category.score }
        let weakest = all.min { $0.category.score < $1.category.score }

        VStack(spacing: 14) {
            // Premium score hero
            VStack(spacing: 13) {
                HStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .stroke(AVENColor.accentPurple.opacity(0.12), lineWidth: 9)
                            .frame(width: 112, height: 112)
                        Circle()
                            .trim(from: 0, to: CGFloat(max(0, min(r.overallScore, 100))) / 100)
                            .stroke(
                                LinearGradient(colors: [AVENColor.accentPurple, AVENColor.accentBlue], startPoint: .topLeading, endPoint: .bottomTrailing),
                                style: StrokeStyle(lineWidth: 9, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 112, height: 112)
                        VStack(spacing: 0) {
                            Text("\(r.overallScore)")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundColor(AVENColor.textPrimary)
                            Text("/100").font(.system(size: 10, weight: .medium)).foregroundColor(AVENColor.textMuted)
                        }
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        Text("AVEN Video Score")
                            .font(.system(size: 11, weight: .semibold)).foregroundColor(AVENColor.textMuted)
                        Text(videoScoreLabel(r.overallScore))
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                            .foregroundStyle(LinearGradient(colors: [AVENColor.accentPurple, AVENColor.accentBlue], startPoint: .leading, endPoint: .trailing))
                        Text(videoScoreSubtitle(r.overallScore))
                            .font(.system(size: 11.5)).foregroundColor(AVENColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    if let strongest {
                        videoHighlight(icon: "sparkles", label: "Stärkster Bereich", value: strongest.title, score: strongest.category.score)
                    }
                    if let weakest {
                        videoHighlight(icon: "arrow.up.right", label: "Größtes Potenzial", value: weakest.title, score: weakest.category.score)
                    }
                }
            }
            .padding(16)
            .background(
                LinearGradient(colors: [AVENColor.accentPurple.opacity(0.085), AVENColor.accentBlue.opacity(0.025), AVENColor.backgroundCard], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(AVENColor.accentPurple.opacity(0.13), lineWidth: 0.7))

            // Compact visual overview
            VStack(alignment: .leading, spacing: 12) {
                Text("Auf einen Blick")
                    .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(AVENColor.textPrimary)
                ForEach(Array(all.enumerated()), id: \.offset) { _, metric in
                    HStack(spacing: 9) {
                        Image(systemName: metric.icon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(scoreColor(metric.category.score))
                            .frame(width: 22)
                        Text(metric.title)
                            .font(.system(size: 11.5, weight: .semibold)).foregroundColor(AVENColor.textPrimary)
                            .frame(width: 54, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(AVENColor.backgroundSecondary)
                                Capsule().fill(scoreColor(metric.category.score))
                                    .frame(width: geo.size.width * CGFloat(metric.category.score) / 100)
                            }
                        }.frame(height: 6)
                        Text("\(metric.category.score)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(scoreColor(metric.category.score))
                            .frame(width: 28, alignment: .trailing)
                    }
                }
            }
            .padding(15).background(AVENColor.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                Text("Detailanalyse")
                    .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(AVENColor.textPrimary)
                ForEach(Array(all.enumerated()), id: \.offset) { _, metric in
                    videoDetailCard(metric)
                }
            }

            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    Text("Deine nächsten Verbesserungen")
                        .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(AVENColor.textPrimary)
                    Spacer()
                    Image(systemName: "wand.and.stars").foregroundColor(AVENColor.accentPurple)
                }
                ForEach(Array(r.improvements.enumerated()), id: \.offset) { i, tip in
                    HStack(alignment: .top, spacing: 10) {
                        ZStack {
                            Circle().fill(AVENColor.accentPurple.opacity(0.11)).frame(width: 29, height: 29)
                            Text("\(i + 1)").font(.system(size: 11, weight: .bold)).foregroundColor(AVENColor.accentPurple)
                        }
                        Text(tip).font(.system(size: 11.5)).foregroundColor(AVENColor.textSecondary).lineSpacing(2)
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .background(AVENColor.backgroundPrimary.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(15)
            .background(LinearGradient(colors: [AVENColor.backgroundCard, AVENColor.accentPurple.opacity(0.035)], startPoint: .top, endPoint: .bottom))
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))

            Button { result = nil; photoItem = nil } label: {
                HStack(spacing: 7) {
                    Image(systemName: "arrow.clockwise")
                    Text("Anderes Video analysieren")
                }
                .font(.system(size: 13, weight: .semibold)).foregroundColor(AVENColor.accentPurple)
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(AVENColor.accentPurple.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }.buttonStyle(PressButtonStyle())
        }
    }

    private func videoHighlight(icon: String, label: String, value: String, score: Int) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 10, weight: .semibold)).foregroundColor(scoreColor(score))
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.system(size: 8.5, weight: .medium)).foregroundColor(AVENColor.textMuted)
                Text("\(value) · \(score)").font(.system(size: 10.5, weight: .bold)).foregroundColor(AVENColor.textPrimary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9).padding(.vertical, 8)
        .background(AVENColor.backgroundCard.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private func videoDetailCard(_ metric: VideoMetric) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(scoreColor(metric.category.score).opacity(0.10)).frame(width: 34, height: 34)
                    Image(systemName: metric.icon).font(.system(size: 13, weight: .semibold)).foregroundColor(scoreColor(metric.category.score))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(metric.title).font(.system(size: 13, weight: .bold)).foregroundColor(AVENColor.textPrimary)
                    Text(categoryLabel(metric.category.score)).font(.system(size: 9.5, weight: .semibold)).foregroundColor(scoreColor(metric.category.score))
                }
                Spacer()
                Text("\(metric.category.score)")
                    .font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(scoreColor(metric.category.score))
            }
            Text(metric.category.feedback)
                .font(.system(size: 11.3)).foregroundColor(AVENColor.textSecondary).lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13).background(AVENColor.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(scoreColor(metric.category.score).opacity(0.10), lineWidth: 0.6))
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 75 { return AVENColor.textPositive }
        if score >= 50 { return AVENColor.accentPurple }
        return AVENColor.textNegative
    }

    private func categoryLabel(_ score: Int) -> String {
        if score >= 80 { return "Sehr stark" }
        if score >= 65 { return "Solide" }
        if score >= 45 { return "Ausbaufähig" }
        return "Priorität" 
    }

    private func videoScoreLabel(_ score: Int) -> String {
        if score >= 85 { return "Sehr stark" }
        if score >= 70 { return "Stark" }
        if score >= 55 { return "Gute Basis" }
        if score >= 40 { return "Viel Potenzial" }
        return "Neu aufbauen"
    }

    private func videoScoreSubtitle(_ score: Int) -> String {
        if score >= 75 { return "Das Video hat eine starke Basis. Optimiere jetzt gezielt die schwächsten Bereiche." }
        if score >= 50 { return "Einige Elemente funktionieren bereits. Die größten Hebel siehst du direkt unten." }
        return "AVEN hat klare Hebel gefunden, mit denen du das nächste Video deutlich stärker aufbauen kannst." 
    }

    @MainActor private func analyze(_ item: PhotosPickerItem) async {
        isLoading = true; errorMessage = nil; result = nil
        do {
            guard let file = try await item.loadTransferable(type: AVENPickedVideoFile.self) else { throw AVENBackendError.noData }
            defer { try? FileManager.default.removeItem(at: file.url) }
            let context = AVENAIContextBuilder.make(account: container.connectedTikTokAccount, analysis: AVENAnalysisStore.load())
            result = try await AVENBackend.analyzeVideo(url: file.url, avenContext: context)
            AVENHaptic.success()
        } catch { errorMessage = error.localizedDescription }
        isLoading = false
    }
}

private struct AICoachMessage: Identifiable {
    let id = UUID(); let role: String; let content: String
}

private struct AICoachView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var container: AppContainer
    @State private var messages: [AICoachMessage] = []
    @State private var input = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var inputFocused: Bool

    var body: some View {
        ZStack {
            AVENColor.backgroundPrimary.ignoresSafeArea()
            VStack(spacing: 0) {
                AISheetHeader(title: "AI Coach") { dismiss() }
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            if messages.isEmpty { coachIntro }
                            ForEach(messages) { message in chatBubble(message).id(message.id) }
                            if isLoading { HStack { ProgressView().tint(AVENColor.accentPurple); Text("AVEN denkt …").font(.system(size: 11)).foregroundColor(AVENColor.textMuted); Spacer() }.padding(.horizontal, 2) }
                            if let errorMessage { AIErrorCard(message: errorMessage) }
                        }.padding(16)
                    }
                    .onChange(of: messages.count) { _, _ in if let id = messages.last?.id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } } }
                }
                HStack(spacing: 8) {
                    TextField("Frag AVEN etwas …", text: $input, axis: .vertical).lineLimit(1...4)
                        .font(.system(size: 13)).foregroundColor(AVENColor.textPrimary).focused($inputFocused)
                        .padding(.horizontal, 12).padding(.vertical, 10).background(AVENColor.backgroundCard)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    Button { Task { await send() } } label: {
                        Image(systemName: "arrow.up").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                            .frame(width: 40, height: 40).background(AVENColor.accentPurple).clipShape(Circle())
                    }.buttonStyle(PressButtonStyle()).disabled(isLoading || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 26)
            }
        }.presentationDetents([.large]).presentationCornerRadius(28)
    }

    private var coachIntro: some View {
        VStack(spacing: 10) {
            ZStack { Circle().fill(AVENColor.accentPurple.opacity(0.10)).frame(width: 58, height: 58); Image(systemName: "sparkles").font(.system(size: 24)).foregroundColor(AVENColor.accentPurple) }
            Text("Dein persönlicher Growth Coach").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(AVENColor.textPrimary)
            Text("AVEN nutzt nur deine tatsächlich verfügbaren Account- und Analyse-Daten als Kontext. Frag nach Strategie, Content oder deinen nächsten Schritten.")
                .font(.system(size: 11.5)).foregroundColor(AVENColor.textSecondary).multilineTextAlignment(.center).lineSpacing(3)
        }.padding(18).background(AVENColor.backgroundCard).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func chatBubble(_ message: AICoachMessage) -> some View {
        HStack {
            if message.role == "user" { Spacer(minLength: 44) }
            Text(message.content).font(.system(size: 12.5)).foregroundColor(message.role == "user" ? .white : AVENColor.textPrimary)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background {
                    if message.role == "user" {
                        LinearGradient(colors: [AVENColor.accentPurple, AVENColor.accentBlue], startPoint: .leading, endPoint: .trailing)
                    } else {
                        AVENColor.backgroundCard
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            if message.role != "user" { Spacer(minLength: 44) }
        }
    }

    @MainActor private func send() async {
        let question = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isLoading else { return }
        let prior = messages.map { ["role": $0.role, "content": $0.content] }
        messages.append(AICoachMessage(role: "user", content: question)); input = ""; isLoading = true; errorMessage = nil
        do {
            let context = AVENAIContextBuilder.make(account: container.connectedTikTokAccount, analysis: AVENAnalysisStore.load())
            let reply = try await AVENBackend.askCoach(question: question, history: prior, avenContext: context)
            messages.append(AICoachMessage(role: "assistant", content: reply))
            _ = container.videoCredits.consumeCoachQuestion()
        } catch {
            if let last = messages.last, last.role == "user", last.content == question { messages.removeLast() }
            input = question; errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct CoachProPlusGate: View {
    var body: some View {
        ZStack {
            AVENColor.backgroundPrimary.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "lock.fill").font(.system(size: 30)).foregroundColor(AVENColor.accentPurple)
                Text("AI Coach").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(AVENColor.textPrimary)
                Text("Der AI Coach ist in deinem aktuellen Plan nicht verfügbar.").font(.system(size: 13)).foregroundColor(AVENColor.textSecondary).multilineTextAlignment(.center)
            }.padding(30)
        }.presentationDetents([.medium]).presentationCornerRadius(28)
    }
}

private struct ContentIdeasSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var container: AppContainer
    @State private var topic = ""
    @State private var ideas: [AVENContentIdea] = []
    @State private var loading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            AVENColor.backgroundPrimary.ignoresSafeArea()
            VStack(spacing: 0) {
                AISheetHeader(title: "Content-Ideen") { dismiss() }
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Worum soll es gehen?").font(.system(size: 12, weight: .semibold)).foregroundColor(AVENColor.textMuted)
                            TextField("z. B. Fitness, Golf, Fashion …", text: $topic).font(.system(size: 13)).foregroundColor(AVENColor.textPrimary)
                                .padding(12).background(AVENColor.backgroundCard).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            AVENPrimaryButton(title: loading ? "Generiere …" : "Ideen generieren", icon: "sparkles") { Task { await generate() } }
                                .disabled(loading || topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).opacity(topic.isEmpty ? 0.55 : 1)
                        }
                        if loading { ProgressView().tint(AVENColor.accentPurple).padding() }
                        if let errorMessage { AIErrorCard(message: errorMessage) }
                        ForEach(ideas) { idea in
                            VStack(alignment: .leading, spacing: 7) {
                                HStack { Text(idea.format.uppercased()).font(.system(size: 9, weight: .bold)).foregroundColor(AVENColor.accentPurple); Spacer() }
                                Text(idea.hook).font(.system(size: 14, weight: .bold)).foregroundColor(AVENColor.textPrimary)
                                if !idea.angle.isEmpty { Text(idea.angle).font(.system(size: 11.5)).foregroundColor(AVENColor.textSecondary) }
                            }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(AVENColor.backgroundCard).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }.padding(16)
                }
            }
        }.presentationDetents([.large]).presentationCornerRadius(28)
    }

    @MainActor private func generate() async {
        loading = true; errorMessage = nil; ideas = []
        do {
            let context = AVENAIContextBuilder.make(account: container.connectedTikTokAccount, analysis: AVENAnalysisStore.load())
            ideas = try await AVENBackend.contentIdeas(topic: topic.trimmingCharacters(in: .whitespacesAndNewlines), count: 5, avenContext: context)
        } catch { errorMessage = error.localizedDescription }
        loading = false
    }
}

private struct AccountPerformanceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var container: AppContainer
    @State private var result: AVENAccountPerformance?
    @State private var loading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            AVENColor.backgroundPrimary.ignoresSafeArea()
            VStack(spacing: 0) {
                AISheetHeader(title: "Account Performance") { dismiss() }
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        if let account = container.connectedTikTokAccount {
                            HStack { VStack(alignment: .leading, spacing: 3) { Text(account.username).font(.system(size: 15, weight: .bold)); Text("\(account.followers) Follower · \(account.likes) Likes · \(account.videoCount) Videos").font(.system(size: 11)).foregroundColor(AVENColor.textMuted) }; Spacer() }
                                .foregroundColor(AVENColor.textPrimary).padding(14).background(AVENColor.backgroundCard).clipShape(RoundedRectangle(cornerRadius: 14))
                            if account.followers <= 0 {
                                AIErrorCard(message: "Der Account ist verbunden, aber AVEN hat noch keine echten Follower-Daten. Sobald die TikTok-Daten verfügbar sind, kann die KI die Performance auswerten.")
                            } else if result == nil && !loading {
                                AVENPrimaryButton(title: "Mit KI analysieren", icon: "chart.line.uptrend.xyaxis") { Task { await analyze(account) } }
                            }
                        } else {
                            AIErrorCard(message: "Verbinde zuerst deinen TikTok-Account. AVEN erfindet keine Performance-Daten.")
                        }
                        if loading { ProgressView().tint(AVENColor.accentPurple).padding() }
                        if let errorMessage { AIErrorCard(message: errorMessage) }
                        if let result { performanceResult(result) }
                    }.padding(16)
                }
            }
        }.presentationDetents([.large]).presentationCornerRadius(28)
    }

    @ViewBuilder private func performanceResult(_ r: AVENAccountPerformance) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("KI-Einschätzung").font(.system(size: 14, weight: .bold)).foregroundColor(AVENColor.textPrimary)
            Text(r.assessment).font(.system(size: 12)).foregroundColor(AVENColor.textSecondary).lineSpacing(3)
        }.padding(14).background(AVENColor.backgroundCard).clipShape(RoundedRectangle(cornerRadius: 14))
        listCard("Stärken", "checkmark.circle.fill", r.strengths)
        listCard("Potenziale", "arrow.up.right.circle.fill", r.weaknesses)
        listCard("Nächste Schritte", "sparkles", r.recommendations)
    }

    private func listCard(_ title: String, _ icon: String, _ items: [String]) -> some View {
        Group {
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label(title, systemImage: icon).font(.system(size: 13, weight: .bold)).foregroundColor(AVENColor.accentPurple)
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in Text("• \(item)").font(.system(size: 11.5)).foregroundColor(AVENColor.textSecondary).fixedSize(horizontal: false, vertical: true) }
                }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(AVENColor.backgroundCard).clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    @MainActor private func analyze(_ account: ConnectedTikTokAccount) async {
        loading = true; errorMessage = nil
        do { result = try await AVENBackend.accountPerformance(account: account) } catch { errorMessage = error.localizedDescription }
        loading = false
    }
}

private struct PostingTimeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var container: AppContainer
    @State private var result: AVENPostingTimeResult?
    @State private var loading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            AVENColor.backgroundPrimary.ignoresSafeArea()
            VStack(spacing: 0) {
                AISheetHeader(title: "Beste Posting-Zeit") { dismiss() }
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        if let account = container.connectedTikTokAccount {
                            Text("AVEN verwendet nur echte verfügbare Daten von \(account.username). Wenn die Daten für eine persönliche Empfehlung nicht reichen, wird keine Uhrzeit erfunden.")
                                .font(.system(size: 11.5)).foregroundColor(AVENColor.textSecondary).lineSpacing(3).padding(14).background(AVENColor.backgroundCard).clipShape(RoundedRectangle(cornerRadius: 14))
                            if account.followers <= 0 || account.videoCount <= 0 {
                                AIErrorCard(message: "Für eine persönliche Posting-Zeit fehlen noch echte Aktivitäts- bzw. Performance-Daten deines TikTok-Accounts.")
                            } else if result == nil && !loading {
                                AVENPrimaryButton(title: "Posting-Zeit analysieren", icon: "clock") { Task { await analyze(account) } }
                            }
                        } else { AIErrorCard(message: "Verbinde zuerst deinen TikTok-Account, damit AVEN eine datenbasierte Empfehlung prüfen kann.") }
                        if loading { ProgressView().tint(AVENColor.accentPurple).padding() }
                        if let errorMessage { AIErrorCard(message: errorMessage) }
                        if let result {
                            ForEach(result.suggestions) { slot in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "clock.fill").foregroundColor(AVENColor.accentPurple).frame(width: 26)
                                    VStack(alignment: .leading, spacing: 3) { Text("\(slot.day) · \(slot.time)").font(.system(size: 13, weight: .bold)).foregroundColor(AVENColor.textPrimary); if !slot.reason.isEmpty { Text(slot.reason).font(.system(size: 11)).foregroundColor(AVENColor.textSecondary) } }
                                    Spacer(minLength: 0)
                                }.padding(14).background(AVENColor.backgroundCard).clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            if !result.note.isEmpty { Text(result.note).font(.system(size: 10.5)).foregroundColor(AVENColor.textMuted).multilineTextAlignment(.center).padding(.horizontal, 8) }
                        }
                    }.padding(16)
                }
            }
        }.presentationDetents([.large]).presentationCornerRadius(28)
    }

    @MainActor private func analyze(_ account: ConnectedTikTokAccount) async {
        loading = true; errorMessage = nil
        do { result = try await AVENBackend.postingTime(account: account) } catch { errorMessage = error.localizedDescription }
        loading = false
    }
}

// ─── Goal Setter Sheet ────────────────────────────────────────────────────────

private struct GoalSetterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var step:     GStep     = .pick
    @State private var goalType: GType     = .follower
    @State private var current   = ""
    @State private var target    = ""
    @State private var deadline  = "30 Tage"
    @State private var saved     = false
    @FocusState private var focused: Bool

    enum GStep { case pick, configure, done }
    enum GType: String, CaseIterable, Identifiable {
        case follower = "Follower"; case likes = "Likes"
        case views    = "Views";    case posts  = "Posts/Woche"
        var id: String { rawValue }
        var icon: String { switch self { case .follower: "person.2.fill"; case .likes: "heart.fill"; case .views: "eye.fill"; case .posts: "calendar.badge.plus" } }
        var color: Color { switch self { case .follower: AVENColor.accentPurple; case .likes: Color(hex:"#E11D48"); case .views: AVENColor.accentBlue; case .posts: Color(hex:"#16A34A") } }
    }

    var body: some View {
        ZStack {
            AVENColor.backgroundPrimary.ignoresSafeArea()
            VStack(spacing: 0) {
                Capsule().fill(AVENColor.borderSubtle).frame(width: 36, height: 4).padding(.top, 10)
                HStack {
                    Text("Ziel setzen").font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(AVENColor.textPrimary)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 22))
                            .foregroundColor(AVENColor.textMuted)
                    }.buttonStyle(PressButtonStyle())
                }.padding(.horizontal, 16).padding(.vertical, 12)

                switch step {
                case .pick:      pickStep
                case .configure: configStep
                case .done:      doneStep
                }
            }
        }
        .presentationDetents([.large]).presentationCornerRadius(28)
        .onTapGesture { focused = false }
    }

    private var pickStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                Text("Was möchtest du erreichen?").font(.system(size: 13))
                    .foregroundColor(AVENColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(GType.allCases) { t in
                        Button { goalType = t; withAnimation { step = .configure } } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10).fill(t.color.opacity(0.12)).frame(width: 38, height: 38)
                                    Image(systemName: t.icon).font(.system(size: 17)).foregroundColor(t.color)
                                }
                                Text(t.rawValue).font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(AVENColor.textPrimary)
                                Spacer(minLength: 0)
                                HStack { Spacer(); Image(systemName: "arrow.right").font(.system(size: 11, weight: .semibold)).foregroundColor(t.color) }
                            }
                            .padding(13).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                             .background(AVENColor.backgroundCard)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(AVENColor.borderSubtle, lineWidth: 0.5))
                        }.buttonStyle(PressButtonStyle())
                    }
                }.padding(.horizontal, 16)
            }.padding(.top, 6).padding(.bottom, 32)
        }
    }

    private var configStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Button { withAnimation { step = .pick } } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                        Text("Zurück").font(.system(size: 13))
                    }.foregroundColor(AVENColor.accentPurple)
                }.buttonStyle(PressButtonStyle())

                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11).fill(goalType.color.opacity(0.12)).frame(width: 46, height: 46)
                        Image(systemName: goalType.icon).font(.system(size: 20)).foregroundColor(goalType.color)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(goalType.rawValue + "-Ziel").font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(AVENColor.textPrimary)
                        Text("Trage aktuellen Wert und Ziel ein.").font(.system(size: 12))
                            .foregroundColor(AVENColor.textSecondary)
                    }
                }

                GoalField("Aktueller Wert", "z. B. 1.200", $current, $focused, goalType.color)
                GoalField("Zielwert (\(goalType.rawValue))", "z. B. 5.000", $target, $focused, goalType.color)

                if let c = Double(current.filter(\.isNumber)), let t = Double(target.filter(\.isNumber)), t > 0 {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Fortschritt").font(.system(size: 12, weight: .semibold)).foregroundColor(AVENColor.textMuted)
                            Spacer()
                            Text("\(Int(c)) / \(Int(t)) \(goalType.rawValue)")
                                .font(.system(size: 12, weight: .semibold)).foregroundColor(goalType.color)
                        }
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(AVENColor.borderSubtle).frame(height: 8)
                                Capsule().fill(goalType.color).frame(width: g.size.width * min(c/t, 1), height: 8)
                            }
                        }.frame(height: 8)
                    }
                    .padding(13) .background(AVENColor.backgroundCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(goalType.color.opacity(0.20), lineWidth: 1))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Zeitraum").font(.system(size: 12, weight: .semibold)).foregroundColor(AVENColor.textMuted)
                    HStack(spacing: 7) {
                        ForEach(["30 Tage", "3 Monate", "6 Monate", "1 Jahr"], id: \.self) { d in
                            Button { deadline = d } label: {
                                Text(d).font(.system(size: 11, weight: deadline==d ? .semibold : .regular))
                                    .foregroundColor(deadline==d ? .white : AVENColor.textSecondary)
                                    .padding(.horizontal, 9).padding(.vertical, 6)
                                    .background(deadline==d ? goalType.color : AVENColor.backgroundCard)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().strokeBorder(deadline==d ? Color.clear : AVENColor.borderSubtle, lineWidth: 0.5))
                            }.buttonStyle(PressButtonStyle())
                        }
                    }
                }

                AVENPrimaryButton(title: "Ziel speichern", icon: "checkmark") {
                    guard !target.isEmpty else { return }
                    AVENUserGoalStore.save(
                        type: goalType.rawValue,
                        current: current,
                        target: target,
                        deadline: deadline
                    )
                    AVENHaptic.success()
                    withAnimation { step = .done }
                }
                .opacity(target.isEmpty ? 0.5 : 1)
            }.padding(16).padding(.bottom, 32)
        }
    }

    private var doneStep: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(goalType.color.opacity(0.12)).frame(width: 72, height: 72)
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 40)).foregroundColor(goalType.color)
                }
                VStack(spacing: 6) {
                    Text("Ziel gespeichert!").font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundColor(AVENColor.textPrimary)
                    Text("\(goalType.rawValue)-Ziel: \(target) in \(deadline)")
                        .font(.system(size: 14)).foregroundColor(AVENColor.textSecondary)
                }
                if let c = Double(current.filter(\.isNumber)), let t = Double(target.filter(\.isNumber)), t > 0 {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("\(Int(c)) / \(Int(t)) \(goalType.rawValue)")
                                .font(.system(size: 13, weight: .semibold)).foregroundColor(goalType.color)
                            Spacer()
                            Text("\(Int(min(c/t,1)*100)) %").font(.system(size: 12)).foregroundColor(AVENColor.textMuted)
                        }
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(AVENColor.borderSubtle).frame(height: 10)
                                Capsule().fill(goalType.color).frame(width: g.size.width * max(min(c/t,1), 0.04), height: 10)
                            }
                        }.frame(height: 10)
                    }.padding(14) .background(AVENColor.backgroundCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(goalType.color.opacity(0.20), lineWidth: 1))
                    .padding(.horizontal, 4)
                }
            }.padding(.horizontal, 20)
            Spacer()
            Button { dismiss() } label: {
                Text("AVEN starten").font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(LinearGradient(colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                                               startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }.buttonStyle(PressButtonStyle()).padding(.horizontal, 16).padding(.bottom, 32)
        }
    }
}

private struct GoalField: View {
    let label: String; let ph: String
    @Binding var val: String
    var focus: FocusState<Bool>.Binding; let color: Color
    init(_ l: String, _ p: String, _ v: Binding<String>, _ f: FocusState<Bool>.Binding, _ c: Color) {
        label=l; ph=p; _val=v; focus=f; color=c
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.system(size: 12, weight: .semibold)).foregroundColor(AVENColor.textMuted)
            TextField(ph, text: $val).font(.system(size: 16, weight: .medium))
                .foregroundColor(AVENColor.textPrimary).keyboardType(.numberPad).focused(focus)
                .padding(.horizontal, 13).padding(.vertical, 11) .background(AVENColor.backgroundCard)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(focus.wrappedValue ? color.opacity(0.5) : AVENColor.borderSubtle,
                                  lineWidth: focus.wrappedValue ? 1.5 : 1))
        }
    }
}

// ─── Growth Experiment Sheet ──────────────────────────────────────────────────

private struct GrowthExperimentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var container: AppContainer

    private enum TestPreset: String, CaseIterable, Identifiable {
        case hook = "Stärkerer Einstieg"
        case posting = "Andere Posting-Zeit"
        case length = "Kürzere Videos"
        case cta = "Klarer CTA"
        case custom = "Eigene Idee"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .hook: return "bolt.fill"
            case .posting: return "clock.fill"
            case .length: return "scissors"
            case .cta: return "hand.tap.fill"
            case .custom: return "sparkles"
            }
        }
    }

    @State private var preset: TestPreset = .hook
    @State private var metric = "Views"
    @State private var customIdea = ""
    @State private var baseline = ""
    @State private var duration = "7"
    @State private var saved = false
    @State private var latestActive: [String: String]?
    @State private var endValue = ""
    @State private var evaluation: AVENExperimentEvaluation?
    @State private var evaluating = false
    @State private var evaluationError: String?
    @FocusState private var focus: GEFocusField?
    enum GEFocusField: Hashable { case title, hypo, metric, baseline }

    private var resolvedTitle: String {
        switch preset {
        case .hook: return "Stärkeren Einstieg testen"
        case .posting: return "Andere Posting-Zeit testen"
        case .length: return "Kürzere Videos testen"
        case .cta: return "Klareren CTA testen"
        case .custom: return customIdea.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private var resolvedHypothesis: String {
        switch preset {
        case .hook: return "Ich starte meine Videos mit einem klaren Hook in den ersten 2 Sekunden und prüfe, ob meine \(metric) steigen."
        case .posting: return "Ich poste bewusst zu einer anderen Uhrzeit und prüfe, ob meine \(metric) steigen."
        case .length: return "Ich teste kürzere, direktere Videos und prüfe, ob meine \(metric) steigen."
        case .cta: return "Ich nutze am Ende einen klaren Call-to-Action und prüfe, ob meine \(metric) steigen."
        case .custom: return "Ich teste \(resolvedTitle) und prüfe, ob meine \(metric) steigen."
        }
    }

    private var valid: Bool {
        !resolvedTitle.isEmpty && Double(baseline.replacingOccurrences(of: ",", with: ".")) != nil
    }

    var body: some View {
        ZStack {
            AVENColor.backgroundPrimary.ignoresSafeArea()
            VStack(spacing: 0) {
                AISheetHeader(title: "Growth Experiment") { dismiss() }
                if saved { successView } else { formView }
            }
        }
        .presentationDetents([.large]).presentationCornerRadius(28)
        .onTapGesture { focus = nil }
        .onAppear { loadLatestActive() }
    }

    private var formView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                if let exp = latestActive { activeExperimentCard(exp) }

                VStack(alignment: .leading, spacing: 9) {
                    Text("Finde heraus, was wirklich funktioniert")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(AVENColor.textPrimary)
                    Text("Ändere nur eine Sache für ein paar Tage. Danach vergleichst du deinen Wert vorher und nachher – AVEN AI erklärt dir das Ergebnis.")
                        .font(.system(size: 12.5)).foregroundColor(AVENColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 7) {
                        simpleStep("1", "Test wählen")
                        simpleStep("2", "Wert merken")
                        simpleStep("3", "Ergebnis prüfen")
                    }
                }
                .padding(14)
                .background(LinearGradient(colors: [AVENColor.accentPurple.opacity(0.09), AVENColor.accentBlue.opacity(0.035)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text("Was möchtest du ausprobieren?")
                    .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(AVENColor.textPrimary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(TestPreset.allCases) { item in
                        Button {
                            withAnimation(.spring(response: 0.3)) { preset = item }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(preset == item ? .white : AVENColor.accentPurple)
                                Text(item.rawValue)
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundColor(preset == item ? .white : AVENColor.textPrimary)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 11).padding(.vertical, 11)
                            .background(preset == item ? AVENColor.accentPurple : AVENColor.backgroundCard)
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(preset == item ? Color.clear : AVENColor.borderSubtle, lineWidth: 0.6))
                        }
                        .buttonStyle(PressButtonStyle())
                    }
                }

                if preset == .custom {
                    GrowthExperimentInputField("Was willst du testen?", "z. B. Untertitel in jedem Video", $customIdea, $focus, .title)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("Welcher Wert soll besser werden?")
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(AVENColor.textMuted)
                    HStack(spacing: 7) {
                        ForEach(["Views", "Follower", "Likes", "Kommentare"], id: \.self) { value in
                            Button { metric = value } label: {
                                Text(value)
                                    .font(.system(size: 10.5, weight: metric == value ? .semibold : .regular))
                                    .foregroundColor(metric == value ? .white : AVENColor.textSecondary)
                                    .padding(.horizontal, 10).padding(.vertical, 7)
                                    .background(metric == value ? AVENColor.accentPurple : AVENColor.backgroundCard)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().strokeBorder(metric == value ? Color.clear : AVENColor.borderSubtle, lineWidth: 0.5))
                            }.buttonStyle(PressButtonStyle())
                        }
                    }
                }

                GrowthExperimentInputField("Wie hoch ist der Wert heute?", "z. B. 500", $baseline, $focus, .baseline, kbd: .decimalPad)

                VStack(alignment: .leading, spacing: 7) {
                    Text("Wie lange willst du testen?").font(.system(size: 12, weight: .semibold)).foregroundColor(AVENColor.textMuted)
                    HStack(spacing: 7) {
                        ForEach(["3","7","14","30"], id: \.self) { d in
                            Button { duration = d } label: {
                                Text("\(d) Tage").font(.system(size: 11.5, weight: duration == d ? .semibold : .regular))
                                    .foregroundColor(duration == d ? .white : AVENColor.textSecondary)
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(duration == d ? AVENColor.accentPurple : AVENColor.backgroundCard)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().strokeBorder(duration == d ? Color.clear : AVENColor.borderSubtle, lineWidth: 0.5))
                            }.buttonStyle(PressButtonStyle())
                        }
                    }
                }

                AVENPrimaryButton(title: "Test starten", icon: "play.fill") { saveExperiment() }
                    .opacity(valid ? 1 : 0.5).disabled(!valid)
                Color.clear.frame(height: 16)
            }.padding(16)
        }
    }

    private func simpleStep(_ number: String, _ text: String) -> some View {
        HStack(spacing: 5) {
            Text(number).font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                .frame(width: 18, height: 18).background(AVENColor.accentPurple).clipShape(Circle())
            Text(text).font(.system(size: 9.5, weight: .semibold)).foregroundColor(AVENColor.textSecondary)
        }
    }

    private func activeExperimentCard(_ exp: [String: String]) -> some View {
        let days = Int(exp["duration"] ?? "7") ?? 7
        let elapsed = elapsedDays(exp)
        let ready = elapsed >= days
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DEIN TEST LÄUFT").font(.system(size: 9, weight: .bold)).foregroundColor(AVENColor.accentPurple)
                    Text(exp["title"] ?? "Growth Test").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(AVENColor.textPrimary)
                }
                Spacer()
                Text(ready ? "Auswerten" : "Tag \(min(elapsed + 1, days))/\(days)")
                    .font(.system(size: 10, weight: .semibold)).foregroundColor(ready ? AVENColor.textPositive : AVENColor.textMuted)
            }

            HStack(spacing: 7) {
                Image(systemName: "chart.line.uptrend.xyaxis").foregroundColor(AVENColor.accentPurple)
                Text("Du beobachtest \(exp["metric"] ?? "deinen Wert"). Start: \(exp["baseline"] ?? "–")")
                    .font(.system(size: 11)).foregroundColor(AVENColor.textSecondary)
            }

            if ready {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Wie hoch ist der Wert jetzt?").font(.system(size: 11, weight: .semibold)).foregroundColor(AVENColor.textMuted)
                    TextField("Neuen Wert eingeben", text: $endValue).keyboardType(.decimalPad).font(.system(size: 13)).foregroundColor(AVENColor.textPrimary)
                        .padding(11).background(AVENColor.backgroundPrimary).clipShape(RoundedRectangle(cornerRadius: 10))
                }
                Button { Task { await evaluate(exp) } } label: {
                    HStack { if evaluating { ProgressView().tint(.white) }; Text(evaluating ? "AVEN prüft …" : "Ergebnis mit AVEN AI prüfen"); Image(systemName: "sparkles") }
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 11)
                        .background(LinearGradient(colors: [AVENColor.accentPurple, AVENColor.accentBlue], startPoint: .leading, endPoint: .trailing)).clipShape(RoundedRectangle(cornerRadius: 11))
                }.buttonStyle(PressButtonStyle()).disabled(evaluating || Double(endValue.replacingOccurrences(of: ",", with: ".")) == nil)
            } else {
                Text("Noch \(max(0, days - elapsed)) Tag(e). Danach trägst du den neuen Wert ein und AVEN vergleicht beides.")
                    .font(.system(size: 10.5)).foregroundColor(AVENColor.textMuted)
            }

            if let evaluationError { AIErrorCard(message: evaluationError) }
            if let evaluation {
                VStack(alignment: .leading, spacing: 7) {
                    Text(statusLabel(evaluation.suggestedStatus)).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(AVENColor.accentPurple)
                    Text(evaluation.explanation).font(.system(size: 11.5)).foregroundColor(AVENColor.textSecondary)
                    Divider().opacity(0.4)
                    Text("Was AVEN erkannt hat").font(.system(size: 11, weight: .semibold)).foregroundColor(AVENColor.textPrimary)
                    Text(evaluation.reasoning).font(.system(size: 10.5)).foregroundColor(AVENColor.textSecondary)
                    Text("Teste als Nächstes: \(evaluation.nextAction)").font(.system(size: 10.5, weight: .semibold)).foregroundColor(AVENColor.textPrimary)
                }.padding(11).background(AVENColor.accentPurple.opacity(0.055)).clipShape(RoundedRectangle(cornerRadius: 11))
            }
        }
        .padding(14).background(AVENColor.backgroundCard).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(AVENColor.accentPurple.opacity(0.14), lineWidth: 0.7))
    }

    private var successView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(AVENColor.accentPurple.opacity(0.10)).frame(width: 72, height: 72)
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 34)).foregroundColor(AVENColor.accentPurple)
                }
                VStack(spacing: 7) {
                    Text("Test gestartet").font(.system(size: 21, weight: .bold, design: .rounded)).foregroundColor(AVENColor.textPrimary)
                    Text(resolvedTitle).font(.system(size: 15, weight: .semibold)).foregroundColor(AVENColor.accentPurple)
                    Text("Merke dir nichts extra: AVEN speichert deinen Startwert. In \(duration) Tagen trägst du nur den neuen \(metric)-Wert ein.")
                        .font(.system(size: 13)).foregroundColor(AVENColor.textSecondary).multilineTextAlignment(.center).padding(.horizontal, 24)
                }
            }
            Spacer()
            Button { dismiss() } label: {
                Text("Fertig").font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(LinearGradient(colors: [AVENColor.accentPurple, AVENColor.accentBlue], startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }.buttonStyle(PressButtonStyle()).padding(.horizontal, 16).padding(.bottom, 32)
        }
    }

    private func saveExperiment() {
        guard valid else { return }
        let exp = ["id": UUID().uuidString, "title": resolvedTitle, "hypothesis": resolvedHypothesis,
                   "metric": metric, "baseline": baseline, "duration": duration,
                   "startDate": ISO8601DateFormatter().string(from: Date()), "status": "active"]
        var all = (UserDefaults.standard.array(forKey: "aven.growthExperiments") as? [[String: String]]) ?? []
        all.append(exp); UserDefaults.standard.set(all, forKey: "aven.growthExperiments")
        latestActive = exp; AVENHaptic.success(); withAnimation { saved = true }
    }

    private func loadLatestActive() {
        let all = (UserDefaults.standard.array(forKey: "aven.growthExperiments") as? [[String: String]]) ?? []
        latestActive = all.last(where: { $0["status"] == "active" })
    }

    private func elapsedDays(_ exp: [String: String]) -> Int {
        guard let raw = exp["startDate"], let date = ISO8601DateFormatter().date(from: raw) else { return 0 }
        return max(0, Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0)
    }

    private func statusLabel(_ status: String) -> String {
        switch status {
        case "works": return "Das hat funktioniert"
        case "doesntWork": return "Hat diesmal nicht geholfen"
        default: return "Noch nicht eindeutig"
        }
    }

    @MainActor private func evaluate(_ exp: [String: String]) async {
        guard let before = Double((exp["baseline"] ?? "").replacingOccurrences(of: ",", with: ".")),
              let after = Double(endValue.replacingOccurrences(of: ",", with: ".")) else { return }
        evaluating = true; evaluationError = nil; evaluation = nil
        do {
            let ctx = AVENAIContextBuilder.make(account: container.connectedTikTokAccount, analysis: AVENAnalysisStore.load())
            evaluation = try await AVENBackend.evaluateExperiment(
                hypothesis: exp["hypothesis"] ?? "", metric: exp["metric"] ?? "Wert",
                before: before, after: after, durationDays: Int(exp["duration"] ?? "7") ?? 7,
                tiktokContext: ctx.isEmpty ? nil : ctx
            )
        } catch { evaluationError = error.localizedDescription }
        evaluating = false
    }
}

private struct GrowthExperimentInputField: View {
    let label: String; let ph: String
    @Binding var text: String
    var focus: FocusState<GrowthExperimentSheet.GEFocusField?>.Binding
    let tag: GrowthExperimentSheet.GEFocusField
    var kbd: UIKeyboardType = .default
    init(_ l: String, _ p: String, _ t: Binding<String>,
         _ f: FocusState<GrowthExperimentSheet.GEFocusField?>.Binding,
         _ tag: GrowthExperimentSheet.GEFocusField, kbd: UIKeyboardType = .default) {
        label=l; ph=p; _text=t; focus=f; self.tag=tag; self.kbd=kbd
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.system(size: 12, weight: .semibold)).foregroundColor(AVENColor.textMuted)
            TextField(ph, text: $text, axis: .vertical).font(.system(size: 13))
                .foregroundColor(AVENColor.textPrimary).keyboardType(kbd).focused(focus, equals: tag)
                .padding(10) .background(AVENColor.backgroundCard)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(focus.wrappedValue == tag ? AVENColor.accentPurple.opacity(0.45) : AVENColor.borderSubtle,
                                  lineWidth: focus.wrappedValue == tag ? 1.5 : 1))
        }
    }
}

#Preview {
    CreationMenuSheet(showNewScan: .constant(false), showAIVideo: .constant(false))
        .environmentObject(AppContainer.preview)
}
