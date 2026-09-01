import SwiftUI

// AVEN Premium Onboarding
// Six polished steps with page-specific motion, interactive goal setup and
// appearance selection. Motion respects Reduce Motion.

struct AVENOnboardingView: View {
    let onComplete: () -> Void

    @State private var page = 0
    @State private var selectedGoal: OBGoal = .followers
    @State private var target = ""
    @State private var deadline = "3 Monate"
    @FocusState private var targetFocused: Bool
    @AppStorage("aven.appearance") private var appearanceRaw = AVENAppearance.light.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var pageVisible = false
    @State private var ambientPulse = false
    @State private var analysisProgress: CGFloat = 0
    @State private var planProgress: CGFloat = 0
    @State private var completionVisible = false

    private let pageCount = 6

    var body: some View {
        ZStack {
            AVENColor.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                TabView(selection: $page) {
                    welcomePage.tag(0)
                    analysisPage.tag(1)
                    actionPlanPage.tag(2)
                    goalPage.tag(3)
                    toolsPage.tag(4)
                    appearancePage.tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                bottomControls
            }
        }
        .onTapGesture { targetFocused = false }
        .onAppear {
            startAmbientMotion()
            preparePage(page)
        }
        .onChange(of: page) { _, newPage in
            targetFocused = false
            preparePage(newPage)
        }
    }

    private var topBar: some View {
        HStack {
            if page > 0 {
                Button {
                    move(to: page - 1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AVENColor.textSecondary)
                        .frame(width: 38, height: 38)
                        .background(AVENColor.backgroundCard)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(AVENColor.borderSubtle, lineWidth: 0.7))
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            } else {
                Color.clear.frame(width: 38, height: 38)
            }

            Spacer()

            if page > 0 {
                OBWordmark(compact: true)
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
            } else {
                Color.clear.frame(width: 110, height: 38)
            }

            Spacer()

            Text("\(page + 1)/\(pageCount)")
                .font(AVENFont.body(12, weight: .semibold))
                .foregroundColor(AVENColor.textMuted)
                .frame(width: 38, height: 38)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .animation(reduceMotion ? .none : .spring(response: 0.38, dampingFraction: 0.82), value: page)
    }

    private var bottomControls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                ForEach(0..<pageCount, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? AVENColor.accentPurple : AVENColor.borderSubtle)
                        .frame(width: index == page ? 26 : 7, height: 7)
                        .scaleEffect(index == page && ambientPulse && !reduceMotion ? 1.04 : 1)
                        .animation(reduceMotion ? .none : .spring(response: 0.4, dampingFraction: 0.76), value: page)
                }
            }

            Button {
                targetFocused = false
                if page == pageCount - 1 {
                    persistGoal()
                    onComplete()
                } else {
                    move(to: page + 1)
                }
            } label: {
                HStack {
                    Spacer()
                    Text(page == pageCount - 1 ? "AVEN starten" : "Weiter")
                        .font(AVENFont.body(16, weight: .semibold))
                        .contentTransition(.opacity)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .offset(x: ambientPulse && !reduceMotion ? 2 : 0)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .shadow(color: AVENColor.accentPurple.opacity(ambientPulse && !reduceMotion ? 0.25 : 0.14), radius: ambientPulse && !reduceMotion ? 16 : 10, y: 6)
            }
            .buttonStyle(PressButtonStyle())
            .disabled(page == 3 && target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(page == 3 && target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
            .animation(reduceMotion ? .none : .easeInOut(duration: 0.22), value: page)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 16)
    }

    private func move(to newPage: Int) {
        targetFocused = false
        if reduceMotion {
            page = newPage
        } else {
            withAnimation(.spring(response: 0.52, dampingFraction: 0.88)) {
                page = newPage
            }
        }
    }

    private func startAmbientMotion() {
        guard !reduceMotion else {
            ambientPulse = false
            return
        }
        ambientPulse = false
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            ambientPulse = true
        }
    }

    private func preparePage(_ newPage: Int) {
        pageVisible = reduceMotion
        completionVisible = false
        if newPage == 1 { analysisProgress = 0 }
        if newPage == 2 { planProgress = 0 }

        guard !reduceMotion else {
            pageVisible = true
            if newPage == 1 { analysisProgress = 0.72 }
            if newPage == 2 { planProgress = 0.58 }
            if newPage == 5 { completionVisible = true }
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            withAnimation(.spring(response: 0.62, dampingFraction: 0.82)) {
                pageVisible = true
            }
        }

        if newPage == 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
                withAnimation(.easeInOut(duration: 1.0)) {
                    analysisProgress = 0.72
                }
            }
        }

        if newPage == 2 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
                withAnimation(.easeOut(duration: 0.95)) {
                    planProgress = 0.58
                }
            }
        }

        if newPage == 5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.46) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) {
                    completionVisible = true
                }
            }
        }
    }

    // MARK: 1 - Welcome

    private var welcomePage: some View {
        OBPageScroll {
            VStack(spacing: 18) {
                Spacer(minLength: 8)

                OBWordmark(compact: false)
                    .scaleEffect(pageVisible ? 1 : 0.72)
                    .opacity(pageVisible ? 1 : 0)
                    .shadow(color: AVENColor.accentPurple.opacity(ambientPulse && !reduceMotion ? 0.20 : 0.08), radius: 22)
                    .animation(reduceMotion ? .none : .spring(response: 0.72, dampingFraction: 0.72), value: pageVisible)

                VStack(spacing: 8) {
                    Text("Grow smarter on TikTok.")
                        .font(.system(size: 31, weight: .bold, design: .rounded))
                        .foregroundColor(AVENColor.textPrimary)
                        .multilineTextAlignment(.center)
                        .obReveal(pageVisible, delay: 0.10, reduceMotion: reduceMotion)

                    Text("Verstehe. Optimiere. Wachse.")
                        .font(AVENFont.body(14))
                        .foregroundColor(AVENColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 12)
                        .obReveal(pageVisible, delay: 0.17, reduceMotion: reduceMotion)
                }

                OBWelcomeHero(active: pageVisible, pulse: ambientPulse, reduceMotion: reduceMotion)
                    .frame(height: 280)
                    .obReveal(pageVisible, delay: 0.23, reduceMotion: reduceMotion, offset: 22)

                Text("Analyze. Optimize. Grow.")
                    .font(AVENFont.body(14, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .obReveal(pageVisible, delay: 0.42, reduceMotion: reduceMotion)
            }
        }
    }

    // MARK: 2 - Analysis

    private var analysisPage: some View {
        OBPageScroll {
            VStack(spacing: 18) {
                OBHeadline(
                    title: "Verstehe deinen Account",
                    subtitle: "Ein Scan. Klare Insights."
                )
                .obReveal(pageVisible, delay: 0.02, reduceMotion: reduceMotion)

                OBPreviewCard {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Analyse")
                                    .font(AVENFont.display(20))
                                    .foregroundColor(AVENColor.textPrimary)
                                Text("Scan → Score → Plan")
                                    .font(AVENFont.body(10, weight: .semibold))
                                    .foregroundColor(AVENColor.accentPurple)
                            }
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(AVENColor.accentPurple.opacity(0.10))
                                    .frame(width: 34, height: 34)
                                Image(systemName: "sparkles")
                                    .foregroundColor(AVENColor.accentPurple)
                                    .rotationEffect(.degrees(ambientPulse && !reduceMotion ? 10 : -8))
                            }
                        }
                        .obReveal(pageVisible, delay: 0.09, reduceMotion: reduceMotion)

                        HStack(spacing: 7) {
                            OBTabPill("\u{00DC}bersicht", selected: true)
                            OBTabPill("Profil")
                            OBTabPill("Content")
                            OBTabPill("Engagement")
                        }
                        .obReveal(pageVisible, delay: 0.15, reduceMotion: reduceMotion)

                        HStack(spacing: 9) {
                            OBMetricPreview(icon: "person.crop.circle", label: "Profil", active: pageVisible, delay: 0.20, reduceMotion: reduceMotion)
                            OBMetricPreview(icon: "play.rectangle", label: "Content", active: pageVisible, delay: 0.27, reduceMotion: reduceMotion)
                            OBMetricPreview(icon: "heart", label: "Engagement", active: pageVisible, delay: 0.34, reduceMotion: reduceMotion)
                        }

                        HStack(spacing: 15) {
                            ZStack {
                                Circle()
                                    .stroke(AVENColor.backgroundSecondary, lineWidth: 9)
                                Circle()
                                    .trim(from: 0, to: analysisProgress)
                                    .stroke(
                                        LinearGradient(colors: [AVENColor.accentPurple, AVENColor.accentBlue], startPoint: .topLeading, endPoint: .bottomTrailing),
                                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                                    )
                                    .rotationEffect(.degrees(-90))
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .foregroundColor(AVENColor.accentPurple)
                                    .scaleEffect(pageVisible ? 1 : 0.72)
                            }
                            .frame(width: 90, height: 90)

                            VStack(alignment: .leading, spacing: 5) {
                                Text("AVEN Score")
                                    .font(AVENFont.body(13, weight: .semibold))
                                    .foregroundColor(AVENColor.textPrimary)
                                Text("Dein Score entsteht aus echten Findings.")
                                    .font(AVENFont.body(12))
                                    .foregroundColor(AVENColor.textSecondary)
                                    .lineSpacing(3)
                            }
                        }
                        .obReveal(pageVisible, delay: 0.40, reduceMotion: reduceMotion)
                    }
                    .overlay(alignment: .top) {
                        OBScanSheen(active: page == 1 && !reduceMotion)
                            .allowsHitTesting(false)
                    }
                }
                .obReveal(pageVisible, delay: 0.07, reduceMotion: reduceMotion, offset: 20)

                OBInfoLine(icon: "checkmark.seal.fill", text: "Nur echte Daten. Keine Demo-Stats.")
                    .obReveal(pageVisible, delay: 0.48, reduceMotion: reduceMotion)
            }
        }
    }

    // MARK: 3 - Action plan

    private var actionPlanPage: some View {
        OBPageScroll {
            VStack(spacing: 18) {
                OBHeadline(
                    title: "Dein n\u{00E4}chster Schritt.",
                    subtitle: "AVEN priorisiert. Du setzt um."
                )
                .obReveal(pageVisible, delay: 0.02, reduceMotion: reduceMotion)

                OBPreviewCard {
                    VStack(spacing: 15) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Diese Woche")
                                    .font(AVENFont.body(15, weight: .semibold))
                                    .foregroundColor(AVENColor.textPrimary)
                                Text("Dein Plan")
                                    .font(AVENFont.body(11))
                                    .foregroundColor(AVENColor.textMuted)
                            }
                            Spacer()
                            HStack(spacing: 5) {
                                Image(systemName: "sparkles")
                                Text("Growth Plan")
                            }
                            .font(AVENFont.body(10, weight: .semibold))
                            .foregroundColor(AVENColor.accentPurple)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(AVENColor.accentPurple.opacity(0.08))
                            .clipShape(Capsule())
                        }
                        .obReveal(pageVisible, delay: 0.09, reduceMotion: reduceMotion)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(AVENColor.backgroundSecondary)
                                Capsule()
                                    .fill(LinearGradient(colors: [AVENColor.accentPurple, AVENColor.accentBlue], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geo.size.width * planProgress)
                                    .shadow(color: AVENColor.accentPurple.opacity(0.18), radius: 5)
                            }
                        }
                        .frame(height: 7)

                        HStack {
                            Text("Priorisierte n\u{00E4}chste Schritte")
                                .font(AVENFont.body(10, weight: .semibold))
                                .foregroundColor(AVENColor.textMuted)
                            Spacer()
                            Text("Fortschritt")
                                .font(AVENFont.body(10, weight: .semibold))
                                .foregroundColor(AVENColor.accentPurple)
                        }
                        .obReveal(pageVisible, delay: 0.17, reduceMotion: reduceMotion)

                        OBTaskRow(icon: "text.alignleft", title: "Bio klarer positionieren", priority: "HOCH")
                            .obReveal(pageVisible, delay: 0.23, reduceMotion: reduceMotion, offset: 14)
                        OBTaskRow(icon: "play.fill", title: "Hook gezielt testen", priority: "MITTEL")
                            .obReveal(pageVisible, delay: 0.31, reduceMotion: reduceMotion, offset: 14)
                        OBTaskRow(icon: "arrow.up.right", title: "CTA verbessern", priority: "NIEDRIG")
                            .obReveal(pageVisible, delay: 0.39, reduceMotion: reduceMotion, offset: 14)
                    }
                }
                .obReveal(pageVisible, delay: 0.06, reduceMotion: reduceMotion, offset: 20)

                HStack(spacing: 8) {
                    OBMiniPromise(icon: "arrow.up", text: "Priorit\u{00E4}ten")
                    OBMiniPromise(icon: "star.fill", text: "XP & Level")
                    OBMiniPromise(icon: "checkmark.circle.fill", text: "Fortschritt")
                }
                .obReveal(pageVisible, delay: 0.47, reduceMotion: reduceMotion)
            }
        }
    }

    // MARK: 4 - Goal

    private var goalPage: some View {
        OBPageScroll {
            VStack(spacing: 16) {
                OBHeadline(
                    title: "Setze dein Ziel.",
                    subtitle: "Ein Ziel. Ein klarer Plan."
                )
                .obReveal(pageVisible, delay: 0.02, reduceMotion: reduceMotion)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(Array(OBGoal.allCases.enumerated()), id: \.element.id) { index, goal in
                        Button {
                            if reduceMotion {
                                selectedGoal = goal
                                target = ""
                            } else {
                                withAnimation(.spring(response: 0.44, dampingFraction: 0.72)) {
                                    selectedGoal = goal
                                    target = ""
                                }
                            }
                        } label: {
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(AVENColor.accentPurple.opacity(selectedGoal == goal ? 0.16 : 0.09))
                                        .frame(width: 38, height: 38)
                                        .scaleEffect(selectedGoal == goal && ambientPulse && !reduceMotion ? 1.08 : 1)
                                    Image(systemName: goal.icon)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(AVENColor.accentPurple)
                                }
                                Text(goal.title)
                                    .font(AVENFont.body(13, weight: .semibold))
                                    .foregroundColor(AVENColor.textPrimary)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                                if selectedGoal == goal {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(AVENColor.accentPurple)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, minHeight: 68)
                            .background(selectedGoal == goal ? AVENColor.accentPurple.opacity(0.07) : AVENColor.backgroundCard)
                            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .strokeBorder(selectedGoal == goal ? AVENColor.accentPurple.opacity(0.65) : AVENColor.borderSubtle, lineWidth: selectedGoal == goal ? 1.2 : 0.8)
                            )
                            .shadow(color: selectedGoal == goal ? AVENColor.accentPurple.opacity(0.09) : .clear, radius: 10, y: 4)
                        }
                        .buttonStyle(PressButtonStyle())
                        .obReveal(pageVisible, delay: 0.08 + Double(index) * 0.055, reduceMotion: reduceMotion, offset: 14)
                    }
                }

                OBPreviewCard {
                    VStack(alignment: .leading, spacing: 13) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Ausgew\u{00E4}hltes Ziel")
                                    .font(AVENFont.body(10, weight: .semibold))
                                    .foregroundColor(AVENColor.accentPurple)
                                Text(selectedGoal.title)
                                    .font(AVENFont.display(18))
                                    .foregroundColor(AVENColor.textPrimary)
                                    .contentTransition(.opacity)
                            }
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(AVENColor.accentPurple.opacity(0.10))
                                    .frame(width: 44, height: 44)
                                Image(systemName: selectedGoal.icon)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(AVENColor.accentPurple)
                                    .contentTransition(.symbolEffect(.replace))
                            }
                        }

                        Divider().background(AVENColor.borderSubtle)

                        Text(selectedGoal.targetLabel)
                            .font(AVENFont.body(11, weight: .semibold))
                            .foregroundColor(AVENColor.textMuted)

                        TextField(selectedGoal.placeholder, text: $target)
                            .keyboardType(.numberPad)
                            .focused($targetFocused)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(AVENColor.textPrimary)
                            .padding(.horizontal, 13)
                            .frame(height: 48)
                            .background(AVENColor.backgroundElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(targetFocused ? AVENColor.accentPurple.opacity(0.55) : AVENColor.borderSubtle, lineWidth: 1)
                            )
                            .shadow(color: targetFocused ? AVENColor.accentPurple.opacity(0.10) : .clear, radius: 9)

                        Text("Zeitraum")
                            .font(AVENFont.body(11, weight: .semibold))
                            .foregroundColor(AVENColor.textMuted)

                        HStack(spacing: 6) {
                            ForEach(["30 Tage", "3 Monate", "6 Monate", "1 Jahr"], id: \.self) { item in
                                Button {
                                    if reduceMotion {
                                        deadline = item
                                    } else {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                                            deadline = item
                                        }
                                    }
                                } label: {
                                    Text(item)
                                        .font(AVENFont.body(10, weight: deadline == item ? .semibold : .regular))
                                        .foregroundColor(deadline == item ? .white : AVENColor.textSecondary)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 34)
                                        .background(deadline == item ? AVENColor.accentPurple : AVENColor.backgroundElevated)
                                        .clipShape(Capsule())
                                        .scaleEffect(deadline == item ? 1.02 : 1)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .obReveal(pageVisible, delay: 0.38, reduceMotion: reduceMotion, offset: 18)
            }
        }
    }

    // MARK: 5 - Tools

    private var toolsPage: some View {
        OBPageScroll {
            VStack(spacing: 18) {
                OBHeadline(
                    title: "Alles \u{00FC}ber den + Button.",
                    subtitle: "Analysieren. Planen. Testen."
                )
                .obReveal(pageVisible, delay: 0.02, reduceMotion: reduceMotion)

                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    AVENColor.accentPurple.opacity(0.13),
                                    AVENColor.backgroundCard,
                                    AVENColor.accentBlue.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\u{2726}  Empfohlen")
                                .font(AVENFont.body(10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(AVENColor.accentPurple)
                                .clipShape(Capsule())
                                .scaleEffect(ambientPulse && !reduceMotion ? 1.03 : 1)
                            Text("Growth Experiment")
                                .font(AVENFont.display(19))
                                .foregroundColor(AVENColor.textPrimary)
                            Text("Teste, was wirklich funktioniert.")
                                .font(AVENFont.body(11))
                                .foregroundColor(AVENColor.textSecondary)
                                .lineSpacing(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        AVENFlaskView(animated: true)
                            .frame(width: 132, height: 126)
                            .scaleEffect(pageVisible ? (ambientPulse && !reduceMotion ? 1.04 : 1) : 0.78)
                            .rotationEffect(.degrees(pageVisible ? 0 : 4))
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 5)
                }
                .frame(height: 150)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(AVENColor.accentPurple.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: AVENColor.accentPurple.opacity(ambientPulse && !reduceMotion ? 0.12 : 0.06), radius: 16, y: 7)
                .obReveal(pageVisible, delay: 0.08, reduceMotion: reduceMotion, offset: 18)

                ZStack {
                    Circle()
                        .stroke(AVENColor.accentPurple.opacity(0.15), lineWidth: 1)
                        .frame(width: 58, height: 58)
                        .scaleEffect(ambientPulse && !reduceMotion ? 1.22 : 0.92)
                        .opacity(ambientPulse && !reduceMotion ? 0.15 : 0.45)
                    Circle()
                        .fill(LinearGradient(colors: [AVENColor.accentPurple, AVENColor.accentBlue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 46, height: 46)
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                .obReveal(pageVisible, delay: 0.18, reduceMotion: reduceMotion, offset: 8)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(Array(OBToolInfo.all.enumerated()), id: \.offset) { index, tool in
                        OBToolCard(icon: tool.icon, title: tool.title)
                            .obReveal(pageVisible, delay: 0.22 + Double(index) * 0.055, reduceMotion: reduceMotion, offset: 16)
                    }
                }
            }
        }
    }

    // MARK: 6 - Appearance

    private var appearancePage: some View {
        OBPageScroll {
            VStack(spacing: 18) {
                OBHeadline(
                    title: "Dein Look. Dein Start.",
                    subtitle: "Hell, Dunkel oder System."
                )
                .obReveal(pageVisible, delay: 0.02, reduceMotion: reduceMotion)

                OBPreviewCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Darstellung")
                            .font(AVENFont.body(14, weight: .semibold))
                            .foregroundColor(AVENColor.textPrimary)

                        HStack(spacing: 7) {
                            ForEach(AVENAppearance.allCases) { option in
                                OBAppearanceButton(option: option, selected: appearanceRaw == option.rawValue) {
                                    if reduceMotion {
                                        appearanceRaw = option.rawValue
                                    } else {
                                        withAnimation(.spring(response: 0.38, dampingFraction: 0.76)) {
                                            appearanceRaw = option.rawValue
                                        }
                                    }
                                }
                            }
                        }

                        OBAppearancePreview(selectedRaw: appearanceRaw, pulse: ambientPulse, reduceMotion: reduceMotion)
                            .frame(height: 136)
                    }
                }
                .obReveal(pageVisible, delay: 0.08, reduceMotion: reduceMotion, offset: 18)

                OBPreviewCard {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AVENColor.accentPurple.opacity(0.10))
                                .frame(width: 48, height: 48)
                                .scaleEffect(completionVisible && !reduceMotion ? 1.04 : 1)
                            Image(systemName: selectedGoal.icon)
                                .foregroundColor(AVENColor.accentPurple)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Dein Ziel")
                                .font(AVENFont.body(10, weight: .semibold))
                                .foregroundColor(AVENColor.textMuted)
                            Text(selectedGoal.title)
                                .font(AVENFont.body(15, weight: .semibold))
                                .foregroundColor(AVENColor.textPrimary)
                            Text(target.isEmpty ? deadline : "\(target) \u{00B7} \(deadline)")
                                .font(AVENFont.body(12))
                                .foregroundColor(AVENColor.textSecondary)
                        }
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(AVENColor.textPositive.opacity(0.10))
                                .frame(width: 42, height: 42)
                                .scaleEffect(completionVisible ? 1 : 0.5)
                            Image(systemName: "checkmark")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(AVENColor.textPositive)
                                .scaleEffect(completionVisible ? 1 : 0.25)
                        }
                        .opacity(completionVisible ? 1 : 0)
                    }
                }
                .obReveal(pageVisible, delay: 0.22, reduceMotion: reduceMotion, offset: 15)

                OBInfoLine(icon: "checkmark.seal.fill", text: "Bereit f\u{00FC}r deine erste Analyse.")
                    .obReveal(pageVisible, delay: 0.44, reduceMotion: reduceMotion)
            }
        }
    }

    private func persistGoal() {
        let cleanedTarget = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTarget.isEmpty else { return }

        AVENUserGoalStore.save(
            type: selectedGoal.storageType,
            current: "",
            target: cleanedTarget,
            deadline: deadline
        )
    }
}

// MARK: - Models

private enum OBGoal: String, CaseIterable, Identifiable {
    case followers
    case views
    case engagement
    case posting
    case professional

    var id: String { rawValue }

    var title: String {
        switch self {
        case .followers: return "Mehr Follower"
        case .views: return "Mehr Views"
        case .engagement: return "Mehr Engagement"
        case .posting: return "Regelm\u{00E4}\u{00DF}iger posten"
        case .professional: return "Account professioneller"
        }
    }

    var icon: String {
        switch self {
        case .followers: return "person.2.fill"
        case .views: return "eye.fill"
        case .engagement: return "heart.fill"
        case .posting: return "calendar.badge.plus"
        case .professional: return "sparkles"
        }
    }

    var targetLabel: String {
        switch self {
        case .followers: return "Follower-Ziel"
        case .views: return "View-Ziel"
        case .engagement: return "Engagement-Ziel in %"
        case .posting: return "Posts pro Woche"
        case .professional: return "Gew\u{00FC}nschter AVEN Score"
        }
    }

    var placeholder: String {
        switch self {
        case .followers: return "z. B. 5.000"
        case .views: return "z. B. 100.000"
        case .engagement: return "z. B. 8"
        case .posting: return "z. B. 4"
        case .professional: return "z. B. 90"
        }
    }

    var storageType: String {
        switch self {
        case .followers: return "Follower"
        case .views: return "Views"
        case .engagement: return "Engagement"
        case .posting: return "Posts/Woche"
        case .professional: return "AVEN Score"
        }
    }
}

private struct OBToolInfo {
    let icon: String
    let title: String

    static let all: [OBToolInfo] = [
        .init(icon: "person.crop.rectangle", title: "Profilanalyse"),
        .init(icon: "play.rectangle", title: "Videoanalyse"),
        .init(icon: "ellipsis.message", title: "AI Coach"),
        .init(icon: "lightbulb", title: "Content-Ideen"),
        .init(icon: "clock", title: "Posting-Zeit"),
        .init(icon: "target", title: "Ziele")
    ]
}

// MARK: - Motion helpers

private extension View {
    func obReveal(_ active: Bool, delay: Double, reduceMotion: Bool, offset: CGFloat = 12) -> some View {
        self
            .opacity(active ? 1 : 0)
            .offset(y: active ? 0 : (reduceMotion ? 0 : offset))
            .scaleEffect(active ? 1 : (reduceMotion ? 1 : 0.985))
            .animation(reduceMotion ? .none : .spring(response: 0.58, dampingFraction: 0.84).delay(delay), value: active)
    }
}

private struct OBScanSheen: View {
    let active: Bool
    @State private var travel = false

    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [.clear, AVENColor.accentPurple.opacity(0.16), AVENColor.accentBlue.opacity(0.10), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 72)
            .rotationEffect(.degrees(12))
            .offset(x: travel ? geo.size.width + 60 : -100)
            .opacity(active ? 1 : 0)
        }
        .clipped()
        .onAppear {
            guard active else { return }
            withAnimation(.linear(duration: 1.65).repeatForever(autoreverses: false)) {
                travel = true
            }
        }
        .onChange(of: active) { _, value in
            if value {
                travel = false
                withAnimation(.linear(duration: 1.65).repeatForever(autoreverses: false)) {
                    travel = true
                }
            } else {
                travel = false
            }
        }
    }
}

// MARK: - Shared onboarding components

private struct OBPageScroll<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            content
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)
        }
    }
}

private struct OBWordmark: View {
    let compact: Bool

    var body: some View {
        HStack(spacing: compact ? 6 : 10) {
            Image("AVENMark")
                .resizable()
                .scaledToFit()
                .frame(width: compact ? 31 : 76, height: compact ? 29 : 70)
            Text("AVEN")
                .font(.system(size: compact ? 16 : 27, weight: .medium))
                .tracking(compact ? 5.5 : 8)
                .foregroundColor(AVENColor.textPrimary)
                .offset(x: compact ? 2 : 4)
        }
    }
}

private struct OBHeadline: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(AVENColor.textPrimary)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(AVENFont.body(14))
                .foregroundColor(AVENColor.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 4)
        }
    }
}

private struct OBPreviewCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(AVENColor.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(AVENColor.borderSubtle, lineWidth: 0.8)
            )
            .shadow(color: AVENColor.cardShadow, radius: 10, y: 4)
    }
}

private struct OBWelcomeHero: View {
    let active: Bool
    let pulse: Bool
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AVENColor.accentPurple.opacity(0.12), AVENColor.backgroundCard, AVENColor.accentBlue.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(AVENColor.accentPurple.opacity(0.13), lineWidth: 1)
                )

            Circle()
                .fill(AVENColor.accentPurple.opacity(0.07))
                .frame(width: 190, height: 190)
                .blur(radius: 4)
                .scaleEffect(pulse && !reduceMotion ? 1.08 : 0.94)

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .stroke(AVENColor.accentPurple.opacity(0.12), lineWidth: 1)
                        .frame(width: 128, height: 128)
                        .scaleEffect(pulse && !reduceMotion ? 1.06 : 0.96)
                    Circle()
                        .stroke(AVENColor.accentBlue.opacity(0.10), lineWidth: 1)
                        .frame(width: 98, height: 98)
                        .scaleEffect(pulse && !reduceMotion ? 0.94 : 1.04)

                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(Array([36, 54, 78, 102].enumerated()), id: \.offset) { index, height in
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [AVENColor.accentPurple.opacity(0.5), AVENColor.accentBlue],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                )
                                .frame(width: 15, height: active ? CGFloat(height) : 8)
                                .animation(reduceMotion ? .none : .spring(response: 0.7, dampingFraction: 0.72).delay(0.18 + Double(index) * 0.08), value: active)
                        }
                    }
                    .offset(y: 8)

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: [AVENColor.accentPurple, AVENColor.accentBlue], startPoint: .bottomLeading, endPoint: .topTrailing))
                        .offset(x: 56, y: -54)
                        .scaleEffect(active ? 1 : 0.4)
                        .opacity(active ? 1 : 0)
                        .animation(reduceMotion ? .none : .spring(response: 0.55, dampingFraction: 0.7).delay(0.52), value: active)
                }

                HStack(spacing: 8) {
                    OBFeaturePill(icon: "chart.bar.fill", text: "Analysieren")
                    OBFeaturePill(icon: "wand.and.stars", text: "Optimieren")
                    OBFeaturePill(icon: "arrow.up.right", text: "Wachsen")
                }
            }
            .padding(.horizontal, 14)
        }
        .shadow(color: AVENColor.accentPurple.opacity(pulse && !reduceMotion ? 0.12 : 0.05), radius: 22, y: 8)
    }
}

private struct OBMiniPromise: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AVENColor.accentPurple)
            Text(text)
                .font(AVENFont.body(10, weight: .semibold))
                .foregroundColor(AVENColor.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .frame(height: 38)
        .background(AVENColor.backgroundCard)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(AVENColor.borderSubtle, lineWidth: 0.7))
    }
}

private struct OBFeaturePill: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AVENColor.accentPurple)
            Text(text)
                .font(AVENFont.body(10, weight: .semibold))
                .foregroundColor(AVENColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 62)
        .background(AVENColor.backgroundCard.opacity(0.84))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(AVENColor.borderSubtle.opacity(0.7), lineWidth: 0.6))
    }
}

private struct OBTabPill: View {
    let title: String
    let selected: Bool

    init(_ title: String, selected: Bool = false) {
        self.title = title
        self.selected = selected
    }

    var body: some View {
        Text(title)
            .font(AVENFont.body(10, weight: selected ? .semibold : .regular))
            .foregroundColor(selected ? AVENColor.accentPurple : AVENColor.textMuted)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(selected ? AVENColor.accentPurple.opacity(0.10) : Color.clear)
            .clipShape(Capsule())
    }
}

private struct OBMetricPreview: View {
    let icon: String
    let label: String
    let active: Bool
    let delay: Double
    let reduceMotion: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AVENColor.accentPurple)
            Text(label)
                .font(AVENFont.body(10, weight: .semibold))
                .foregroundColor(AVENColor.textPrimary)
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<5, id: \.self) { i in
                    Capsule()
                        .fill(AVENColor.accentPurple.opacity(0.22 + Double(i) * 0.1))
                        .frame(width: 4, height: active ? CGFloat(6 + i * 3) : 3)
                        .animation(reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.75).delay(delay + Double(i) * 0.035), value: active)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        .background(AVENColor.backgroundElevated)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .obReveal(active, delay: delay, reduceMotion: reduceMotion, offset: 10)
    }
}

private struct OBTaskRow: View {
    let icon: String
    let title: String
    let priority: String

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AVENColor.accentPurple.opacity(0.09))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AVENColor.accentPurple)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(priority)
                    .font(AVENFont.body(9, weight: .bold))
                    .foregroundColor(AVENColor.accentPurple)
                Text(title)
                    .font(AVENFont.body(12, weight: .semibold))
                    .foregroundColor(AVENColor.textPrimary)
            }
            Spacer()
            ZStack {
                Circle()
                    .fill(AVENColor.accentPurple.opacity(0.08))
                    .frame(width: 30, height: 30)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AVENColor.accentPurple)
            }
        }
        .padding(11)
        .background(AVENColor.backgroundElevated)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

private struct OBToolCard: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AVENColor.accentPurple.opacity(0.09))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AVENColor.accentPurple)
            }
            Text(title)
                .font(AVENFont.body(12, weight: .semibold))
                .foregroundColor(AVENColor.textPrimary)
            Spacer(minLength: 0)
            Image(systemName: "arrow.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(AVENColor.accentPurple)
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 62)
        .background(AVENColor.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(AVENColor.borderSubtle, lineWidth: 0.8))
    }
}

private struct OBAppearanceButton: View {
    let option: AVENAppearance
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: option.icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(option.title)
                    .font(AVENFont.body(10, weight: .semibold))
            }
            .foregroundColor(selected ? .white : AVENColor.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Group {
                    if selected {
                        LinearGradient(colors: [AVENColor.accentPurple, AVENColor.accentBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    } else {
                        LinearGradient(colors: [AVENColor.backgroundElevated, AVENColor.backgroundElevated], startPoint: .leading, endPoint: .trailing)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(selected ? AVENColor.accentPurple.opacity(0.35) : AVENColor.borderSubtle, lineWidth: 0.8)
            )
            .scaleEffect(selected ? 1.02 : 1)
        }
        .buttonStyle(.plain)
    }
}

private struct OBAppearancePreview: View {
    let selectedRaw: String
    let pulse: Bool
    let reduceMotion: Bool

    private var isDark: Bool { selectedRaw == AVENAppearance.dark.rawValue }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isDark ? Color.black : AVENColor.backgroundElevated)
                .animation(reduceMotion ? .none : .easeInOut(duration: 0.35), value: isDark)

            Circle()
                .fill(AVENColor.accentPurple.opacity(isDark ? 0.20 : 0.08))
                .frame(width: 110, height: 110)
                .blur(radius: 20)
                .offset(x: 110, y: -25)
                .scaleEffect(pulse && !reduceMotion ? 1.08 : 0.94)

            VStack(spacing: 12) {
                HStack {
                    Image("AVENMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 40)
                    Text("AVEN")
                        .font(.system(size: 16, weight: .medium))
                        .tracking(6)
                        .foregroundColor(isDark ? .white : AVENColor.textPrimary)
                    Spacer()
                    Circle()
                        .fill(AVENColor.accentPurple)
                        .frame(width: 7, height: 7)
                }

                HStack(spacing: 8) {
                    ForEach(["Analyse", "Plan", "Wachstum"], id: \.self) { item in
                        Text(item)
                            .font(AVENFont.body(10, weight: .semibold))
                            .foregroundColor(AVENColor.accentPurple)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(isDark ? Color.white.opacity(0.06) : AVENColor.backgroundCard)
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                }
            }
            .padding(15)
        }
    }
}

private struct OBInfoLine: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AVENColor.accentPurple)
                .padding(.top, 2)
            Text(text)
                .font(AVENFont.body(11))
                .foregroundColor(AVENColor.textSecondary)
                .lineSpacing(3)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }
}
