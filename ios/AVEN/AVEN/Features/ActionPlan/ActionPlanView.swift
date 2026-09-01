import SwiftUI
import PhotosUI

// ─── Action Plan ──────────────────────────────────────────────────────────────
// A coaching-first weekly plan built from the real analysis gaps. The existing
// task generation, proof verification and score-impact logic remain unchanged.

private enum ActionPlanFilter: String, CaseIterable, Identifiable {
    case all = "Alle"
    case high = "Hoch"
    case medium = "Mittel"
    case low = "Niedrig"

    var id: String { rawValue }

    func includes(_ action: GrowthActionItem) -> Bool {
        switch self {
        case .all: return true
        case .high: return action.severity == .foundation
        case .medium: return action.severity == .lever
        case .low: return action.severity == .polish
        }
    }
}

struct ActionPlanView: View {
    @StateObject private var vm = ActionPlanViewModel()
    @EnvironmentObject private var container: AppContainer

    @State private var showProUpsell = false
    @State private var showCelebration = false
    @State private var selectedFilter: ActionPlanFilter = .all
    @State private var showCompleted = false
    @State private var growthMission: AVENGrowthMission? = AVENGrowthMissionStore.current

    private let celebrationKey = "aven.celebration.shown.v1"

    private var filteredActions: [GrowthActionItem] {
        vm.actions.filter { selectedFilter.includes($0) }
    }

    private var openFiltered: [GrowthActionItem] {
        filteredActions.filter { !$0.isCompleted }
    }

    private var todayActions: [GrowthActionItem] {
        Array(openFiltered.prefix(1))
    }

    private var weekActions: [GrowthActionItem] {
        Array(openFiltered.dropFirst(todayActions.count))
    }

    private var completedFiltered: [GrowthActionItem] {
        filteredActions.filter(\.isCompleted)
    }

    private var availableCount: Int {
        vm.actions.filter { !$0.isProLocked && !$0.isBlocked }.count
    }

    private var possiblePoints: Int {
        vm.actions
            .filter { !$0.isCompleted && !$0.isProLocked && !$0.isBlocked }
            .map(\.xpReward)
            .reduce(0, +)
    }

    var body: some View {
        ZStack {
            AVENColor.backgroundPrimary.ignoresSafeArea()

            if AVENAnalysisStore.hasCompletedAnalysis && vm.actions.isEmpty && AVENAnalysisStore.currentScore >= 100 {
                perfectProfileState
            } else if !AVENAnalysisStore.hasCompletedAnalysis {
                noAnalysisState
            } else {
                planContent
            }

            if showCelebration {
                AVENConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                            withAnimation(.easeOut(duration: 0.5)) { showCelebration = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showProUpsell) {
            ProUpsellSheet(lockedCount: vm.proLockedCount, lockedPoints: vm.lockedImpactTotal)
        }
        .onAppear {
            vm.reload()
            growthMission = AVENGrowthMissionStore.sync(account: container.connectedTikTokAccount)
        }
        .onReceive(NotificationCenter.default.publisher(for: .growthMissionDidUpdate)) { _ in
            growthMission = AVENGrowthMissionStore.current
        }
    }

    private var planContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 15) {
                header
                weeklyProgressCard
                avenChallengeCard
                growthChallengeCard
                filterBar

                if openFiltered.isEmpty {
                    filteredEmptyState
                } else {
                    if !todayActions.isEmpty {
                        PlanSectionHeader(title: "Heute", subtitle: "Dein wichtigster nächster Schritt")
                        ForEach(Array(todayActions.enumerated()), id: \.element.id) { idx, action in
                            ActionCard(
                                action: action,
                                index: idx + 1,
                                featured: true,
                                onUpdate: { vm.update($0) },
                                onTapLocked: { showProUpsell = true }
                            )
                        }
                    }

                    if !weekActions.isEmpty {
                        PlanSectionHeader(title: "Diese Woche", subtitle: "Danach weiter optimieren")
                        VStack(spacing: 10) {
                            ForEach(Array(weekActions.enumerated()), id: \.element.id) { idx, action in
                                ActionCard(
                                    action: action,
                                    index: todayActions.count + idx + 1,
                                    featured: false,
                                    onUpdate: { vm.update($0) },
                                    onTapLocked: { showProUpsell = true }
                                )
                            }
                        }
                    }
                }

                if !completedFiltered.isEmpty {
                    completedSection
                }

                Color.clear.frame(height: 14)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Aktionsplan")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(AVENColor.textPrimary)
                    Text("Dein persönlicher Wachstumsplan")
                        .font(AVENFont.body(13))
                        .foregroundColor(AVENColor.textSecondary)
                }
                Spacer()

                ZStack {
                    Circle()
                        .fill(AVENColor.accentPurple.opacity(0.09))
                        .frame(width: 38, height: 38)
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AVENColor.accentPurple)
                }
            }
        }
    }

    private var weeklyProgressCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Diese Woche")
                        .font(AVENFont.body(15, weight: .semibold))
                        .foregroundColor(AVENColor.textPrimary)
                    Text("Schritt für Schritt zu deinem nächsten Level")
                        .font(AVENFont.body(10.5))
                        .foregroundColor(AVENColor.textMuted)
                }
                Spacer()
                Text("\(vm.completedCount)/\(max(availableCount, vm.completedCount)) erledigt")
                    .font(AVENFont.body(10.5, weight: .semibold))
                    .foregroundColor(AVENColor.accentPurple)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(AVENColor.accentPurple.opacity(0.08))
                    .clipShape(Capsule())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(AVENColor.backgroundSecondary)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * vm.progress)
                        .animation(.spring(response: 0.7), value: vm.progress)
                }
            }
            .frame(height: 7)

            HStack(spacing: 8) {
                PlanMetric(value: "\(vm.completedCount)", label: "Erledigt", icon: "checkmark", color: AVENColor.textPositive)
                PlanMetric(value: "\(vm.openCount)", label: "Offen", icon: "bolt.fill", color: AVENColor.accentPurple)
                PlanMetric(value: "+\(possiblePoints)", label: "XP", icon: "arrow.up.right", color: AVENColor.accentBlue)
            }

            if !vm.isProUser && vm.proLockedCount > 0 {
                Button { showProUpsell = true } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "lock.fill")
                        Text("\(vm.proLockedCount) weitere Wachstumshebel mit AVEN Pro")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(AVENFont.body(10.5, weight: .semibold))
                    .foregroundColor(AVENColor.accentPurple)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(AVENColor.accentPurple.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(PressButtonStyle())
            }
        }
        .padding(15)
        .background(
            LinearGradient(
                colors: [AVENColor.backgroundCard, AVENColor.accentPurple.opacity(0.025)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(AVENColor.accentPurple.opacity(0.10), lineWidth: 0.7)
        )
        .shadow(color: AVENColor.cardShadow, radius: 8, y: 2)
    }


    private var avenChallengeCard: some View {
        let score = AVENAnalysisStore.currentScore
        let complete = score >= 100
        return VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill((complete ? AVENColor.textPositive : AVENColor.accentPurple).opacity(0.10))
                        .frame(width: 40, height: 40)
                    Image(systemName: complete ? "trophy.fill" : "target")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(complete ? AVENColor.textPositive : AVENColor.accentPurple)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(complete ? "AVEN Challenge bestanden" : "AVEN Challenge")
                        .font(AVENFont.body(14, weight: .semibold))
                        .foregroundColor(AVENColor.textPrimary)
                    Text(complete ? "Dein Profil erfüllt den AVEN Perfect Profile Standard." : "\(score)/100 · Noch \(max(0, 100 - score)) Punkte bis Perfect Profile")
                        .font(AVENFont.body(10.5))
                        .foregroundColor(AVENColor.textSecondary)
                }
                Spacer()
                Text("\(score)/100")
                    .font(AVENFont.body(13, weight: .bold))
                    .foregroundColor(complete ? AVENColor.textPositive : AVENColor.accentPurple)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(AVENColor.backgroundSecondary)
                    Capsule()
                        .fill(LinearGradient(colors: [AVENColor.accentPurple, AVENColor.accentBlue], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * min(1, CGFloat(score) / 100))
                }
            }
            .frame(height: 7)

            Text(complete
                 ? "100/100 wird nur vergeben, wenn alle geprüften Profilbereiche den perfekten AVEN Standard erfüllen."
                 : "Aufgaben geben dir XP, aber keine künstlichen AVEN-Score-Punkte. Verbessere dein Profil und analysiere danach erneut. 100/100 gibt es nur bei einem wirklich perfekten Profil.")
                .font(AVENFont.body(10.5))
                .foregroundColor(AVENColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(15)
        .background(AVENColor.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).strokeBorder((complete ? AVENColor.textPositive : AVENColor.accentPurple).opacity(0.13), lineWidth: 0.7))
    }

    @ViewBuilder
    private var growthChallengeCard: some View {
        if let mission = growthMission, let account = container.connectedTikTokAccount {
            let current = mission.currentValue(account: account)
            let progress = mission.progress(account: account)
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    HStack(spacing: 9) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(AVENColor.accentPurple.opacity(0.10))
                                .frame(width: 38, height: 38)
                            Image(systemName: mission.metric.icon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(AVENColor.accentPurple)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Growth Sprint · Stufe \(mission.stage)")
                                .font(AVENFont.body(10.5, weight: .semibold))
                                .foregroundColor(AVENColor.accentPurple)
                            Text(mission.title)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(AVENColor.textPrimary)
                        }
                    }
                    Spacer()
                    Text("+\(mission.rewardXP) XP")
                        .font(AVENFont.body(11, weight: .bold))
                        .foregroundColor(AVENColor.accentPurple)
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(AVENColor.accentPurple.opacity(0.08))
                        .clipShape(Capsule())
                }

                Text("Erreiche das echte TikTok-Ziel in \(mission.durationDays) Tagen. Sobald deine verbundenen Account-Daten den Zielwert erreichen, vergibt AVEN die XP automatisch und macht die nächste Challenge etwas größer.")
                    .font(AVENFont.body(10.5))
                    .foregroundColor(AVENColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(AVENColor.backgroundSecondary)
                        Capsule()
                            .fill(LinearGradient(colors: [AVENColor.accentPurple, AVENColor.accentBlue], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * progress)
                            .animation(.spring(response: 0.55), value: progress)
                    }
                }
                .frame(height: 7)

                HStack {
                    Text("\(current.formatted()) / \(mission.target.formatted()) \(mission.metric.title)")
                        .font(AVENFont.body(10.5, weight: .semibold))
                        .foregroundColor(AVENColor.textPrimary)
                    Spacer()
                    Text(mission.daysRemaining > 0 ? "noch \(mission.daysRemaining) Tage" : "Zeitraum erreicht")
                        .font(AVENFont.body(10))
                        .foregroundColor(AVENColor.textMuted)
                }
            }
            .padding(15)
            .background(
                LinearGradient(
                    colors: [AVENColor.accentPurple.opacity(0.085), AVENColor.accentBlue.opacity(0.035), AVENColor.backgroundCard],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(AVENColor.accentPurple.opacity(0.16), lineWidth: 0.8))
        } else {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AVENColor.accentPurple.opacity(0.08)).frame(width: 38, height: 38)
                    Image(systemName: "flag.checkered")
                        .foregroundColor(AVENColor.accentPurple)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Messbare Growth Sprints")
                        .font(AVENFont.body(13, weight: .semibold)).foregroundColor(AVENColor.textPrimary)
                    Text("Sobald echte Follower- oder Like-Daten verfügbar sind, setzt AVEN kurze Ziele mit XP und steigender Schwierigkeit.")
                        .font(AVENFont.body(10.5)).foregroundColor(AVENColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .background(AVENColor.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(AVENColor.borderSubtle, lineWidth: 0.6))
        }
    }

    private var filterBar: some View {
        HStack(spacing: 7) {
            ForEach(ActionPlanFilter.allCases) { filter in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { selectedFilter = filter }
                } label: {
                    Text(filter.rawValue)
                        .font(AVENFont.body(10.5, weight: selectedFilter == filter ? .semibold : .medium))
                        .foregroundColor(selectedFilter == filter ? .white : AVENColor.textSecondary)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                        .background(
                            Group {
                                if selectedFilter == filter {
                                    LinearGradient(
                                        colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                } else {
                                    LinearGradient(colors: [AVENColor.backgroundCard, AVENColor.backgroundCard], startPoint: .leading, endPoint: .trailing)
                                }
                            }
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().strokeBorder(
                                selectedFilter == filter ? Color.clear : AVENColor.borderSubtle,
                                lineWidth: 0.6
                            )
                        )
                }
                .buttonStyle(PressButtonStyle())
            }
            Spacer(minLength: 0)
        }
    }

    private var completedSection: some View {
        VStack(spacing: 9) {
            Button {
                withAnimation(.spring(response: 0.35)) { showCompleted.toggle() }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Erledigt")
                            .font(AVENFont.body(15, weight: .semibold))
                            .foregroundColor(AVENColor.textPrimary)
                        Text("\(completedFiltered.count) abgeschlossene Aufgaben")
                            .font(AVENFont.body(10.5))
                            .foregroundColor(AVENColor.textMuted)
                    }
                    Spacer()
                    Image(systemName: showCompleted ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AVENColor.textMuted)
                }
            }
            .buttonStyle(.plain)

            if showCompleted {
                VStack(spacing: 9) {
                    ForEach(Array(completedFiltered.enumerated()), id: \.element.id) { idx, action in
                        ActionCard(
                            action: action,
                            index: idx + 1,
                            featured: false,
                            onUpdate: { vm.update($0) },
                            onTapLocked: { showProUpsell = true }
                        )
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var filteredEmptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 28))
                .foregroundColor(AVENColor.accentPurple)
            Text("Keine offenen Aufgaben in diesem Filter")
                .font(AVENFont.body(13, weight: .semibold))
                .foregroundColor(AVENColor.textPrimary)
            Text("Wähle einen anderen Filter oder öffne deine erledigten Aufgaben.")
                .font(AVENFont.body(11))
                .foregroundColor(AVENColor.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(AVENColor.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var noAnalysisState: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AVENColor.accentPurple.opacity(0.16), AVENColor.accentBlue.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 86, height: 86)
                Image(systemName: "checklist")
                    .font(.system(size: 34))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("Dein persönlicher Aktionsplan")
                    .font(AVENFont.display(22))
                    .foregroundColor(AVENColor.textPrimary)
                Text("Starte deine erste Analyse. AVEN erkennt deine größten Wachstumshebel und erstellt daraus deinen persönlichen Plan.")
                    .font(AVENFont.body(13))
                    .foregroundColor(AVENColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 30)
            }

            AVENPrimaryButton(title: "Analyse starten", icon: "camera.viewfinder") {
                container.showNewScan = true
            }
            .padding(.horizontal, 28)
            Spacer()
        }
    }

    private var perfectProfileState: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("🎉").font(.system(size: 60))
            VStack(spacing: 8) {
                Text("AVEN Challenge bestanden")
                    .font(AVENFont.display(25))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("Dein Profil erfüllt in allen geprüften Bereichen den AVEN Perfect Profile Standard.")
                    .font(AVENFont.body(14))
                    .foregroundColor(AVENColor.textSecondary)
                    .multilineTextAlignment(.center)
                Text("100 / 100")
                    .font(AVENFont.body(13, weight: .semibold))
                    .foregroundColor(AVENColor.textPositive)
            }
            Spacer()
        }
        .onAppear { triggerCelebrationIfNeeded() }
    }

    private func triggerCelebrationIfNeeded() {
        let alreadyShown = UserDefaults.standard.bool(forKey: celebrationKey)
        guard !alreadyShown else { return }
        UserDefaults.standard.set(true, forKey: celebrationKey)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.5)) { showCelebration = true }
        }
    }
}

private struct PlanMetric: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 7) {
            ZStack {
                Circle().fill(color.opacity(0.09)).frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(AVENFont.body(13, weight: .bold))
                    .foregroundColor(AVENColor.textPrimary)
                Text(label)
                    .font(AVENFont.body(8.5))
                    .foregroundColor(AVENColor.textMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, minHeight: 43)
        .background(AVENColor.backgroundCard.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

private struct PlanSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(AVENFont.body(16, weight: .semibold))
                .foregroundColor(AVENColor.textPrimary)
            Spacer()
            Text(subtitle)
                .font(AVENFont.body(9.5))
                .foregroundColor(AVENColor.textMuted)
        }
    }
}

// ─── Coaching task card ───────────────────────────────────────────────────────

private struct ActionCard: View {
    let action: GrowthActionItem
    let index: Int
    let featured: Bool
    let onUpdate: (GrowthActionItem) -> Void
    let onTapLocked: () -> Void

    @State private var expanded = false
    @State private var proofItem: PhotosPickerItem?
    @State private var proofPicked = false
    @State private var verifying = false
    @State private var verifyFailed: String? = nil

    private var isLocked: Bool { action.isProLocked || action.isBlocked }

    private var priority: (label: String, color: Color) {
        switch action.severity {
        case .foundation: return ("HOCH", Color(hex: "#D84B4B"))
        case .lever: return ("MITTEL", AVENColor.accentBlue)
        case .polish: return ("NIEDRIG", AVENColor.textSecondary)
        }
    }

    private var categoryIcon: String {
        switch action.category.lowercased() {
        case "bio": return "text.alignleft"
        case "content": return "play.rectangle.fill"
        case "brand": return "person.crop.circle"
        default: return "sparkles"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                if isLocked {
                    onTapLocked()
                } else {
                    withAnimation(.spring(response: 0.35)) { expanded.toggle() }
                }
            } label: {
                HStack(spacing: 12) {
                    checkCircle

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text(priority.label)
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundColor(priority.color)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(priority.color.opacity(0.09))
                                .clipShape(Capsule())

                            if action.requiresProof && !action.isCompleted && !isLocked {
                                HStack(spacing: 3) {
                                    Image(systemName: "camera.fill")
                                    Text("Nachweis")
                                }
                                .font(.system(size: 8.2, weight: .medium))
                                .foregroundColor(AVENColor.textMuted)
                            }
                        }

                        Text(action.title)
                            .font(AVENFont.body(featured ? 14.5 : 13.5, weight: .semibold))
                            .foregroundColor(action.isCompleted || isLocked ? AVENColor.textMuted : AVENColor.textPrimary)
                            .strikethrough(action.isCompleted, color: AVENColor.textMuted)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 6)

                    VStack(alignment: .trailing, spacing: 7) {
                        if isLocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11))
                                .foregroundColor(AVENColor.accentPurple)
                        } else {
                            Text(action.impactLabel)
                                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                .foregroundColor(action.isCompleted ? AVENColor.textMuted : AVENColor.accentPurple)
                        }

                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(AVENColor.textMuted)
                    }
                }
                .padding(featured ? 15 : 13)
            }
            .buttonStyle(.plain)

            if expanded && !isLocked {
                Divider().opacity(0.5)
                    .padding(.horizontal, 13)

                VStack(alignment: .leading, spacing: 11) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AVENColor.accentPurple)
                        Text("Warum AVEN das empfiehlt")
                            .font(AVENFont.body(11, weight: .semibold))
                            .foregroundColor(AVENColor.textPrimary)
                    }

                    Text(action.detail.isEmpty ? defaultDetail(action) : action.detail)
                        .font(AVENFont.body(11.5))
                        .foregroundColor(AVENColor.textSecondary)
                        .lineSpacing(3)

                    if action.requiresProof && !action.isCompleted {
                        proofSection
                    } else if !action.isCompleted {
                        Button {
                            var updated = action
                            updated.isCompleted = true
                            AVENHaptic.success()
                            withAnimation(AVENMotion.spring) { onUpdate(updated) }
                            withAnimation(AVENMotion.spring) { expanded = false }
                        } label: {
                            Label("Als erledigt markieren", systemImage: "checkmark.circle.fill")
                                .font(AVENFont.body(11.5, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(
                                    LinearGradient(
                                        colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(PressButtonStyle())
                    }
                }
                .padding(.horizontal, 13)
                .padding(.top, 11)
                .padding(.bottom, 13)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if action.isProLocked && !action.isBlocked {
                Button { onTapLocked() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                        Text("Mit AVEN Pro freischalten")
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .font(AVENFont.body(10.5, weight: .semibold))
                    .foregroundColor(AVENColor.accentPurple)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AVENColor.accentPurple.opacity(0.06))
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            Group {
                if featured && !action.isCompleted {
                    LinearGradient(
                        colors: [AVENColor.backgroundCard, AVENColor.accentPurple.opacity(0.035)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    LinearGradient(
                        colors: [AVENColor.backgroundCard, AVENColor.backgroundCard],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .strokeBorder(featured ? AVENColor.accentPurple.opacity(0.11) : AVENColor.borderSubtle, lineWidth: 0.6)
        )
        .shadow(color: AVENColor.cardShadow, radius: 7, y: 2)
        .opacity(action.isCompleted ? 0.72 : (action.isBlocked ? 0.45 : (action.isProLocked ? 0.78 : 1.0)))
    }

    @ViewBuilder
    private var proofSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                    .foregroundColor(AVENColor.accentBlue)
                Text("Lade einen Screenshot hoch, damit AVEN die Umsetzung prüfen kann.")
                    .font(AVENFont.body(10.5))
                    .foregroundColor(AVENColor.textSecondary)
            }

            if verifying {
                HStack(spacing: 8) {
                    ProgressView().tint(AVENColor.accentPurple).scaleEffect(0.82)
                    Text("Screenshot wird geprüft …")
                        .font(AVENFont.body(11))
                        .foregroundColor(AVENColor.textSecondary)
                }
                .padding(.vertical, 5)
            } else if proofPicked {
                HStack(spacing: 7) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AVENColor.textPositive)
                    Text("Nachweis bestätigt")
                        .font(AVENFont.body(11, weight: .semibold))
                        .foregroundColor(AVENColor.textPositive)
                }

                Button {
                    var updated = action
                    updated.isCompleted = true
                    AVENHaptic.success()
                    withAnimation(AVENMotion.spring) { onUpdate(updated) }
                    withAnimation(AVENMotion.spring) { expanded = false }
                } label: {
                    Label("Aufgabe abschließen (+\(action.xpReward) XP)", systemImage: "checkmark.circle.fill")
                        .font(AVENFont.body(11.5, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            LinearGradient(
                                colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(PressButtonStyle())
            } else {
                if let err = verifyFailed {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(AVENColor.textNegative)
                        Text(err)
                            .font(AVENFont.body(10.5))
                            .foregroundColor(AVENColor.textNegative)
                    }
                }

                PhotosPicker(selection: $proofItem, matching: .images, photoLibrary: .shared()) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.badge.plus")
                        Text(verifyFailed != nil ? "Erneut hochladen" : "Screenshot hochladen")
                    }
                    .font(AVENFont.body(11, weight: .semibold))
                    .foregroundColor(AVENColor.accentPurple)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(AVENColor.accentPurple.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(AVENColor.accentPurple.opacity(0.20), lineWidth: 0.8)
                    )
                }
                .buttonStyle(.plain)
                .onChange(of: proofItem) { _, item in
                    guard let item else { return }
                    Task { await verifyProofItem(item) }
                }
            }
        }
    }

    private func verifyProofItem(_ item: PhotosPickerItem) async {
        verifying = true
        verifyFailed = nil

        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            verifying = false
            verifyFailed = "Bild konnte nicht geladen werden. Bitte erneut versuchen."
            return
        }

        let analyzer = ProfileImageAnalyzer()
        let (passed, message) = await analyzer.verifyProof(
            image: image,
            category: action.category,
            taskTitle: action.title
        )

        verifying = false
        if passed {
            proofPicked = true
        } else {
            verifyFailed = message
            proofItem = nil
        }
    }

    private var checkCircle: some View {
        Button {
            guard !isLocked else { onTapLocked(); return }

            if action.requiresProof && !action.isCompleted {
                withAnimation(.spring(response: 0.35)) { expanded = true }
                return
            }

            var updated = action
            updated.isCompleted.toggle()
            if updated.isCompleted { AVENHaptic.success() }
            withAnimation(AVENMotion.spring) { onUpdate(updated) }
        } label: {
            ZStack {
                Circle()
                    .fill(action.isCompleted ? AVENColor.textPositive : AVENColor.accentPurple.opacity(0.07))
                    .frame(width: featured ? 38 : 34, height: featured ? 38 : 34)
                    .overlay(
                        Circle().strokeBorder(
                            action.isCompleted ? AVENColor.textPositive : AVENColor.accentPurple.opacity(0.12),
                            lineWidth: 0.8
                        )
                    )

                if action.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                } else if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                        .foregroundColor(AVENColor.textMuted)
                } else {
                    Image(systemName: categoryIcon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(priority.color)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func defaultDetail(_ action: GrowthActionItem) -> String {
        switch action.severity {
        case .foundation:
            return "Diese Aufgabe behebt einen grundlegenden Schwachpunkt aus deiner Analyse und sollte zuerst umgesetzt werden."
        case .lever:
            return "Diese Aufgabe hat einen starken Hebel auf dein Profil und ist ein sinnvoller nächster Wachstumsschritt."
        case .polish:
            return "Diese Optimierung verbessert die Details deines Profils und bringt dich näher an den AVEN Standard."
        }
    }
}
private struct ProUpsellSheet: View {
    let lockedCount:  Int
    let lockedPoints: Int
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
                                colors: [AVENColor.accentPurple.opacity(0.25), AVENColor.accentBlue.opacity(0.15)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 80, height: 80)
                            .avGlow(color: AVENColor.accentPurple, radius: 14, breathes: true)
                        Image(systemName: "star.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(LinearGradient(
                                colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                    }

                    Text("AVEN Pro freischalten")
                        .font(AVENFont.display(24))
                        .foregroundColor(AVENColor.textPrimary)

                    Text("Schalte deinen kompletten personalisierten Aktionsplan mit \(lockedCount) weiteren Maßnahmen und +\(lockedPoints) möglichen XP frei.")
                        .font(AVENFont.body(15))
                        .foregroundColor(AVENColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, AVENSpacing.lg)

                    // Feature list
                    AVENCard {
                        VStack(alignment: .leading, spacing: 10) {
                            ProFeatureRow(icon: "checkmark.circle.fill", text: "Vollständiger personalisierter Aktionsplan")
                            ProFeatureRow(icon: "checkmark.circle.fill", text: "Alle Analysen & Findings")
                            ProFeatureRow(icon: "checkmark.circle.fill", text: "Unbegrenzte Analysen")
                            ProFeatureRow(icon: "checkmark.circle.fill", text: "KI-Video Credits")
                        }
                    }
                    .padding(.horizontal, AVENSpacing.md)
                }

                Spacer()

                VStack(spacing: AVENSpacing.sm) {
                    // MARK: - Integration Point: StoreKit purchase
                    AVENPrimaryButton(title: "AVEN Pro starten", icon: "star.fill") {
                        dismiss()
                    }
                    Button { dismiss() } label: {
                        Text("Nicht jetzt")
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
        .presentationDetents([.large])
        .presentationCornerRadius(28)
    }
}

private struct ProFeatureRow: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(AVENColor.textPositive)
                .font(.system(size: 14))
            Text(text)
                .font(AVENFont.body(14))
                .foregroundColor(AVENColor.textPrimary)
        }
    }
}

// ─── Stat pill ────────────────────────────────────────────────────────────────

private struct StatPill: View {
    let value: String
    let label: String
    let color: Color
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(AVENFont.display(22)).foregroundColor(color)
            Text(label).font(AVENFont.body(11)).foregroundColor(AVENColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// ─── ViewModel ────────────────────────────────────────────────────────────────

@MainActor
final class ActionPlanViewModel: ObservableObject {
    @Published var actions: [GrowthActionItem] = []

    // Pro status — DEBUG builds always get full access for testing.
    // Replace with real billing check (StoreKit / backend) for production.
    var isProUser: Bool {
        #if DEBUG
        return true   // Developer/test override: full Pro access in Simulator
        #else
        // Read persisted plan written by VideoCreditsService / StoreKit
        let plan = UserDefaults.standard.string(forKey: "aven.currentPlan") ?? "FREE"
        return plan == "PRO" || plan == "PRO+"
        #endif
    }
    private let freeUnlockLimit = 3
    private let persistenceKey  = "aven.actionplan.completed"

    // Delegate score read/write to AVENAnalysisStore
    var persistedScore: Int { AVENAnalysisStore.currentScore }

    var completedCount:   Int     { actions.filter(\.isCompleted).count }
    var openCount:        Int     { actions.filter { !$0.isCompleted && !$0.isProLocked && !$0.isBlocked }.count }
    var proLockedCount:   Int     { actions.filter(\.isProLocked).count }
    var lockedImpactTotal: Int    { actions.filter(\.isProLocked).map(\.xpReward).reduce(0, +) }
    var progress:         CGFloat {
        let available = actions.filter { !$0.isProLocked && !$0.isBlocked }
        guard !available.isEmpty else { return 0 }
        return CGFloat(available.filter(\.isCompleted).count) / CGFloat(available.count)
    }

    init() {
        reload()
        // Rebuild the plan whenever a new analysis completes
        NotificationCenter.default.addObserver(
            forName: .analysisDidComplete,
            object:  nil,
            queue:   .main
        ) { [weak self] _ in self?.reload() }
        NotificationCenter.default.addObserver(
            forName: .aiActionPlanDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.reload() }
        NotificationCenter.default.addObserver(
            forName: .goalDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.reload() }
    }

    func reload() {
        let goal   = AVENGoalStore.current
        let record = AVENAnalysisStore.load()

        let tasks: [GrowthActionItem]
        if let rec = record {
            if let aiTasks = AVENAIActionPlanStore.load(for: rec), !aiTasks.isEmpty {
                tasks = Self.buildFromAI(tasks: aiTasks, isProUser: isProUser, freeLimit: freeUnlockLimit)
            } else {
                // Deterministic plan from real findings remains a safe fallback if
                // the AI request fails. It never invents account metrics.
                tasks = Self.buildFromAnalysis(record: rec, goal: goal,
                                               isProUser: isProUser, freeLimit: freeUnlockLimit)
            }
        } else {
            tasks = []   // no analysis → empty state shown in view
        }

        withAnimation(.spring(response: 0.4)) { actions = tasks }
    }

    func update(_ action: GrowthActionItem) {
        guard let idx = actions.firstIndex(where: { $0.id == action.id }) else { return }
        let wasCompleted = actions[idx].isCompleted
        withAnimation(.spring(response: 0.4)) { actions[idx] = action }
        // XP is granted exactly once per stable task ID. Re-opening a completed
        // task never removes XP, which prevents farming by toggling completion.
        if action.isCompleted && !wasCompleted {
            _ = AVENXPStore.grantOnce(key: "action-plan.\(action.id)", amount: action.xpReward)
        }
        let completedIDs = actions.filter(\.isCompleted).map(\.id)
        UserDefaults.standard.set(completedIDs, forKey: persistenceKey)
    }

    static func buildFromAI(tasks: [AVENAIPlanTask], isProUser: Bool, freeLimit: Int) -> [GrowthActionItem] {
        let completedIDs = Set(UserDefaults.standard.stringArray(forKey: "aven.actionplan.completed") ?? [])
        var unlocked = 0
        return tasks.enumerated().map { index, task in
            let severity: GrowthActionItem.Severity
            let priorityValue: Int
            switch task.priority.lowercased() {
            case "high": severity = .foundation; priorityValue = 1
            case "low": severity = .polish; priorityValue = 3
            default: severity = .lever; priorityValue = 2
            }
            var item = GrowthActionItem(
                id: task.id,
                title: task.title,
                category: task.category,
                impact: task.xp,
                priority: priorityValue * 10 + index,
                severity: severity,
                isBlocked: false,
                requiresProof: task.requiresProof,
                detail: task.detail
            )
            item.isCompleted = completedIDs.contains(item.id)
            if !item.isCompleted {
                if !isProUser && unlocked >= freeLimit { item.isProLocked = true }
                else { unlocked += 1 }
            }
            return item
        }
    }

    // ── Gap-to-Standard task generation ──────────────────────────────────────
    // Compares the latest analysis against the AVEN Perfect Profile Standard.
    // Creates ONE concrete task per real gap. Never creates generic filler tasks.
    // If an area already meets the standard, NO task is created for it.

    static func buildFromAnalysis(record: AnalysisRecord, goal: AccountGoal,
                                   isProUser: Bool, freeLimit: Int) -> [GrowthActionItem] {
        var all: [GrowthActionItem] = []
        let weak = record.weaknesses.joined(separator: " ").lowercased()

        // Helper: dimension score by name substring (-1 = unmeasurable/absent)
        func dim(_ name: String) -> Int {
            record.dimensions
                .first { $0.name.lowercased().contains(name.lowercased()) }?
                .score ?? -1
        }

        // Helper: is a dimension already strong (score ≥ threshold or no negative signal)?
        func isStrong(_ name: String, threshold: Int = 70) -> Bool {
            let s = dim(name)
            return s >= threshold   // -1 = unmeasured → not a gap
        }

        // ── 1. Bio fehlt oder ist zu kurz ────────────────────────────────────
        let bioScore = dim("bio")
        let bioGap   = (bioScore >= 0 && bioScore < 68) ||
                       weak.contains("bio") || weak.contains("kurz") || weak.contains("leer")
        if bioGap {
            let detail: String
            switch goal {
            case .business:
                detail = "Schreibe eine Bio, die zeigt, wem du hilfst und was du anbietest.\nBeispiel: \"Ich helfe [Zielgruppe] dabei, [Ergebnis] zu erreichen | → Info unten\"\nNachweis: Screenshot deines aktualisierten Profils."
            case .creator:
                detail = "Erkläre in 2 Sätzen, welche Inhalte du erstellst und warum es sich lohnt zu folgen.\nNachweis: Screenshot deines aktualisierten Profils."
            case .personalBrand:
                detail = "Zeige in der Bio klar, wer du bist und was du teilst.\nNachweis: Screenshot deines aktualisierten Profils."
            case .improveProfile:
                detail = "Schreibe eine klare Bio, die erklärt, was Besucher auf deinem Profil erwartet.\nNachweis: Screenshot deines aktualisierten Profils."
            }
            all.append(GrowthActionItem(
                id: "bio_positioning", title: "Schreibe eine Bio, die sofort klar macht, worum es geht",
                category: "bio", impact: 8, priority: 1, severity: .foundation,
                isBlocked: false, requiresProof: true, detail: detail))
        }

        // ── 2. Handlungsaufforderung fehlt ────────────────────────────────────
        let ctaScore = dim("handlungsaufforderung")
        let ctaGap   = (ctaScore >= 0 && ctaScore < 60) ||
                       weak.contains("handlungsaufforderung") || weak.contains("cta") ||
                       weak.contains("link") || weak.contains("klare nächste")
        if ctaGap {
            let detail = "Zeige Besuchern, was sie als Nächstes tun sollen.\nBeispiel: \"↓ Mein kostenloses Angebot unten\", \"Schreib mir eine Nachricht\" oder \"→ Link in Bio\".\nNachweis: Screenshot deines Profils mit sichtbarer Handlungsaufforderung."
            all.append(GrowthActionItem(
                id: "bio_cta", title: "Füge eine klare nächste Handlung hinzu",
                category: "bio", impact: 7, priority: 2, severity: .foundation,
                isBlocked: false, requiresProof: true, detail: detail))
        }

        // ── 3. Thema nicht erkennbar ──────────────────────────────────────────
        let nicheScore = dim("content")
        let nicheGap   = (nicheScore >= 0 && nicheScore < 60) ||
                         weak.contains("thema") || weak.contains("keyword") ||
                         weak.contains("einordnen") || weak.contains("klar")
        if nicheGap && !bioGap {
            let detail = "Füge einen Begriff ein, der dein Thema direkt beschreibt.\nBeispiel: \"Fitness\", \"TikTok-Wachstum\", \"Kochen\", \"Business\".\nNachweis: Screenshot deiner aktualisierten Bio."
            all.append(GrowthActionItem(
                id: "niche_keyword", title: "Zeige klar, worum es auf deinem Profil geht",
                category: "bio", impact: 5, priority: 3, severity: .foundation,
                isBlocked: false, requiresProof: true, detail: detail))
        }

        // ── 4. Kein Grund zu folgen erkennbar ────────────────────────────────
        let reasonGap = weak.contains("warum") || weak.contains("folgen sollten") ||
                        weak.contains("nutzen") || weak.contains("versprechen") ||
                        weak.contains("mehrwert")
        if reasonGap && !bioGap {
            let detail = "Erkläre in der Bio, was Menschen bekommen, wenn sie dir folgen.\nBeispiel: \"Täglich neue Tipps zu [deinem Thema]\" oder \"Ich teile alles, was ich über [Thema] gelernt habe\".\nNachweis: Screenshot deiner aktualisierten Bio."
            all.append(GrowthActionItem(
                id: "value_prop", title: "Erkläre, warum Besucher dir folgen sollten",
                category: "bio", impact: 5, priority: 4, severity: .foundation,
                isBlocked: false, requiresProof: true, detail: detail))
        }

        // ── 5. Keine Emojis zur Struktur ─────────────────────────────────────
        let emojiGap = weak.contains("emoji") || weak.contains("struktur") ||
                       weak.contains("übersichtlich")
        if emojiGap {
            let detail = "Passende Emojis am Anfang jeder Zeile machen die Bio übersichtlicher.\nBeispiel: 🎯 Thema / ✨ Nutzen / 👇 Handlung.\nNachweis: Screenshot deiner aktualisierten Bio."
            all.append(GrowthActionItem(
                id: "bio_emojis", title: "Strukturiere deine Bio mit passenden Emojis",
                category: "bio", impact: 3, priority: 5, severity: .polish,
                isBlocked: false, requiresProof: true, detail: detail))
        }

        // ── 4. Visuelles Branding / Profilbild ───────────────────────────────
        let brandingGap = weak.contains("profilbild") || weak.contains("bild") ||
                          weak.contains("brand") || weak.contains("visual") ||
                          weak.contains("cover") ||
                          (dim("profilbild") >= 0 && dim("profilbild") < 60) ||
                          (dim("profilbild & branding") >= 0 && dim("profilbild & branding") < 60)
        if brandingGap {
            let detail = "Ein professionelles Profilbild und konsistentes visuelles Branding stärken den ersten Eindruck.\nNachweis: Screenshot deines aktualisierten TikTok-Profils mit neuem Profilbild oder einheitlichen Video-Thumbnails."
            all.append(GrowthActionItem(
                id: "visual_branding", title: "Verbessere deinen wiedererkennbaren Auftritt",
                category: "brand", impact: 5, priority: 4, severity: .polish,
                isBlocked: false, requiresProof: true, detail: detail))
        }

        // ── 5. Profilstruktur / angepinnte Videos ─────────────────────────────
        // Only suggest pinning videos when the weakness explicitly mentions videos/pinning,
        // NOT just because "Struktur" is weak (that could be bio structure).
        let pinnedGap = weak.contains("pinned") || weak.contains("angepinn") ||
                        weak.contains("pin ") || weak.contains("strategisch") ||
                        (dim("profilstruktur") >= 0 && dim("profilstruktur") < 60 &&
                         (weak.contains("video") || weak.contains("inhalt") || weak.contains("content")))
        if pinnedGap {
            let detail = "Pinne 3 Videos an, die deine Nische und deinen Mehrwert sofort zeigen.\nNachweis: Screenshot deines Profils mit 3 gepinnten Videos sichtbar."
            all.append(GrowthActionItem(
                id: "pinned_videos", title: "Pinne deine besten Videos an, damit sie zuerst sichtbar sind",
                category: "content", impact: 4, priority: 5, severity: .polish,
                isBlocked: false, requiresProof: true, detail: detail))
        }

        // ── 6. Username / Display Name ────────────────────────────────────────
        let nameGap = weak.contains("username") || weak.contains("name") ||
                      weak.contains("handle") || weak.contains("anzeigename")
        if nameGap {
            let detail = "Wähle einen klaren, einprägsamen Anzeigenamen, der dein Thema widerspiegelt.\nNachweis: Screenshot deines TikTok-Profils mit dem aktualisierten Namen."
            all.append(GrowthActionItem(
                id: "display_name", title: "Wähle einen klar verständlichen Profilnamen",
                category: "bio", impact: 3, priority: 6, severity: .polish,
                isBlocked: false, requiresProof: true, detail: detail))
        }

        // ── Perfect Profile Standard ──────────────────────────────────────────
        // Only show the completion state at exactly 100.
        // If score < 100, there are remaining points to earn — make that visible.
        if all.isEmpty {
            if record.analysisScore >= 100 {
                // True 100/100 — dedicated completion state (not a task card)
                // The view renders this as a special empty/success state
                // We signal this by returning an empty array; the view checks analysisScore
                return []
            } else {
                // Score < 100 but no specific categorical gap was detected.
                // This happens when dims are slightly below perfect (e.g. 80–95 each).
                // Show the most impactful remaining opportunity.
                let lowestDim = record.dimensions
                    .filter { $0.score >= 0 && $0.score < 100 }
                    .min { $0.score < $1.score }
                if let lowest = lowestDim {
                    let detail = "\(lowest.tip)\nNachweis: Screenshot des aktualisierten Profils."
                    all.append(GrowthActionItem(
                        id: "gap_\(lowest.name.prefix(12))",
                        title: "\(lowest.name) weiter stärken",
                        category: "bio", impact: 100 - record.analysisScore,
                        priority: 1, severity: .polish,
                        isBlocked: false, requiresProof: true, detail: detail))
                }
            }
        }

        // ── Sort, apply tier-locking ──────────────────────────────────────────
        all.sort { $0.priority < $1.priority }

        // Restore completion state only for tasks that exist in this plan
        let completedIDs = Set(UserDefaults.standard.stringArray(forKey: "aven.actionplan.completed") ?? [])
        for i in all.indices where completedIDs.contains(all[i].id) {
            all[i].isCompleted = true
        }

        // Pro-lock tasks beyond free tier
        // Free: up to freeLimit open tasks visible; rest show generic locked message
        var unlocked = 0
        for i in all.indices {
            guard !all[i].isCompleted, all[i].category != "info" else { continue }
            if !isProUser && unlocked >= freeLimit {
                var locked = GrowthActionItem(
                    id: all[i].id,
                    title: "Weitere personalisierte Wachstumshebel verfügbar.",
                    category: all[i].category, impact: all[i].impact,
                    priority: all[i].priority, severity: all[i].severity,
                    isBlocked: false)
                locked.isProLocked = true
                all[i] = locked
            } else {
                unlocked += 1
            }
        }

        // ── Cap total impact to remaining points (100 - score) ────────────────
        // Prevents tasks showing "+8 pts" when only +3 is actually possible.
        let maxPoints   = max(0, 100 - record.analysisScore)
        var pointsUsed  = 0
        for i in all.indices {
            guard !all[i].isProLocked && !all[i].isCompleted else { continue }
            let available = maxPoints - pointsUsed
            if available <= 0 {
                // No points left — show task with 0 impact rather than remove it
                var capped = all[i]; capped = GrowthActionItem(
                    id: all[i].id, title: all[i].title, category: all[i].category,
                    impact: 0, priority: all[i].priority, severity: all[i].severity,
                    isBlocked: all[i].isBlocked, requiresProof: all[i].requiresProof,
                    detail: all[i].detail)
                all[i] = capped
            } else if all[i].impact > available {
                var capped = all[i]; capped = GrowthActionItem(
                    id: all[i].id, title: all[i].title, category: all[i].category,
                    impact: available, priority: all[i].priority, severity: all[i].severity,
                    isBlocked: all[i].isBlocked, requiresProof: all[i].requiresProof,
                    detail: all[i].detail)
                all[i] = capped
                pointsUsed += available
            } else {
                pointsUsed += all[i].impact
            }
        }

        return all
    }
}


// ─── Confetti Celebration ─────────────────────────────────────────────────────
// Premium dark-mode confetti: purple, blue, cyan particles + subtle 🎉
// Plays once, stored in UserDefaults to prevent repeat on reopen.

private struct AVENConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    private let colors: [Color] = [
        Color(hex: "#9B5CFF"), Color(hex: "#4F8FFF"), Color(hex: "#00D4FF"),
        Color(hex: "#C03CFF"), Color(hex: "#38F4B0"), Color(hex: "#FF6BD6"),
    ]

    var body: some View {
        TimelineView(.animation) { _ in
            Canvas { ctx, size in
                for p in particles {
                    let rect = CGRect(x: p.x * size.width, y: p.y * size.height,
                                     width: p.size, height: p.size * (p.isEmoji ? 1 : 0.5))
                    ctx.opacity = p.opacity
                    if p.isEmoji {
                        ctx.draw(Text("🎉").font(.system(size: p.size)), at: CGPoint(x: p.x * size.width, y: p.y * size.height))
                    } else {
                        ctx.fill(Path(ellipseIn: rect), with: .color(p.color))
                    }
                }
            }
        }
        .onAppear { spawnParticles() }
    }

    private func spawnParticles() {
        particles = (0..<80).map { i in
            ConfettiParticle(
                x: Double.random(in: 0...1),
                y: Double.random(in: -0.2...0),
                vx: Double.random(in: -0.003...0.003),
                vy: Double.random(in: 0.004...0.012),
                size: CGFloat.random(in: 6...14),
                color: colors[i % colors.count],
                opacity: 1,
                isEmoji: i % 20 == 0
            )
        }
        animateParticles()
    }

    private func animateParticles() {
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
            var allDone = true
            for i in particles.indices {
                particles[i].y  += particles[i].vy
                particles[i].x  += particles[i].vx
                particles[i].vy += 0.0003  // gravity
                if particles[i].y < 1.3 { allDone = false }
                if particles[i].y > 0.8  { particles[i].opacity = max(0, particles[i].opacity - 0.02) }
            }
            if allDone { timer.invalidate() }
        }
    }
}

private struct ConfettiParticle {
    var x, y, vx, vy: Double
    var size: CGFloat
    var color: Color
    var opacity: Double
    var isEmoji: Bool
}

#Preview { ActionPlanView() }
