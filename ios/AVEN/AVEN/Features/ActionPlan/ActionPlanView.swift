import SwiftUI
import PhotosUI

// ─── ActionPlanView ───────────────────────────────────────────────────────────

struct ActionPlanView: View {
    @StateObject private var vm = ActionPlanViewModel()
    @EnvironmentObject private var container: AppContainer
    @State private var showProUpsell   = false
    @State private var showCelebration = false

    private let celebrationKey = "aven.celebration.shown.v1"

    var body: some View {
        ZStack {
            AVENColor.backgroundPrimary.ignoresSafeArea()

            // ── 100/100 Perfect Profile success state ──────────────────────
            if AVENAnalysisStore.hasCompletedAnalysis && vm.actions.isEmpty && AVENAnalysisStore.currentScore >= 100 {
                VStack(spacing: AVENSpacing.xl) {
                    Spacer()
                    Text("🎉").font(.system(size: 64))
                    VStack(spacing: 10) {
                        Text("Glückwunsch!")
                            .font(AVENFont.display(26))
                            .foregroundStyle(LinearGradient(
                                colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                                startPoint: .leading, endPoint: .trailing))
                        Text("Du hast dein Profil vollständig optimiert.")
                            .font(AVENFont.body(16, weight: .semibold))
                            .foregroundColor(AVENColor.textPrimary)
                            .multilineTextAlignment(.center)
                        Text("Dein Profil entspricht dem AVEN Perfect Profile Standard.")
                            .font(AVENFont.body(14))
                            .foregroundColor(AVENColor.textSecondary)
                            .multilineTextAlignment(.center)
                        Text("Keine weiteren Aufgaben nötig.")
                            .font(AVENFont.body(13))
                            .foregroundColor(AVENColor.textMuted)
                            .multilineTextAlignment(.center)
                        Text("100% abgeschlossen ✓")
                            .font(AVENFont.body(13, weight: .semibold))
                            .foregroundColor(AVENColor.textPositive)
                    }
                    .padding(.horizontal, AVENSpacing.lg)
                    Spacer()
                }
                .onAppear { triggerCelebrationIfNeeded() }

                // Confetti overlay — only when celebrating
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

            // ── No completed analysis yet ──────────────────────────────────
            } else if !AVENAnalysisStore.hasCompletedAnalysis {
                VStack(spacing: AVENSpacing.xl) {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [AVENColor.accentPurple.opacity(0.2),
                                                          AVENColor.accentBlue.opacity(0.1)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 88, height: 88)
                        Image(systemName: "list.clipboard")
                            .font(.system(size: 36))
                            .foregroundStyle(LinearGradient(colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                                                            startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                    VStack(spacing: 10) {
                        Text("Dein persönlicher Aktionsplan")
                            .font(AVENFont.display(22))
                            .foregroundColor(AVENColor.textPrimary)
                            .multilineTextAlignment(.center)
                        Text("Starte deine erste Analyse für einen personalisierten Aktionsplan, um deinen AVEN Score zu verbessern.")
                            .font(AVENFont.body(14))
                            .foregroundColor(AVENColor.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, AVENSpacing.xl)
                    }
                    AVENPrimaryButton(title: "Analyse starten", icon: "camera.viewfinder") {
                        container.showNewScan = true
                    }
                    .padding(.horizontal, AVENSpacing.lg)
                    Spacer()
                }
                .padding(.top, AVENSpacing.xxl)

            } else {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AVENSpacing.lg) {

                    // ── Header ───────────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Aktionsplan")
                            .font(AVENFont.display(24))
                            .foregroundColor(AVENColor.textPrimary)
                        if vm.isProUser {
                            Text("\(vm.openCount) offene Aufgaben")
                                .font(AVENFont.body(14))
                                .foregroundColor(AVENColor.textSecondary)
                        } else {
                            Text("\(vm.openCount) von \(vm.actions.count) Maßnahmen freigeschaltet")
                                .font(AVENFont.body(14))
                                .foregroundColor(AVENColor.textSecondary)
                        }
                    }
                    .padding(.top, AVENSpacing.sm)
                    .cardAppear(delay: 0)

                    // ── Progress card ─────────────────────────────────────────
                    AVENCard(accentBorder: true) {
                        VStack(spacing: AVENSpacing.md) {
                            HStack(spacing: 0) {
                                StatPill(value: "\(vm.completedCount)", label: "Erledigt",  color: AVENColor.textPositive)
                                StatPill(value: "\(vm.openCount)",      label: "Offen",     color: AVENColor.accentPurple)
                                StatPill(value: "\(vm.proLockedCount)", label: "Gesperrt",  color: AVENColor.textMuted)
                                if vm.progress > 0 {
                                    StatPill(value: "\(Int(vm.progress * 100))%", label: "Erledigt", color: AVENColor.accentBlue)
                                }
                            }
                            .frame(maxWidth: .infinity)

                            // Progress bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4).fill(AVENColor.borderSubtle)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(LinearGradient(
                                            colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                                            startPoint: .leading, endPoint: .trailing))
                                        .frame(width: geo.size.width * vm.progress)
                                        .animation(.spring(response: 0.8), value: vm.progress)
                                }
                            }
                            .frame(height: 6)

                            // Free teaser
                            if !vm.isProUser && vm.proLockedCount > 0 {
                                Button { showProUpsell = true } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 12))
                                        Text("\(vm.proLockedCount) weitere Maßnahmen · +\(vm.lockedImpactTotal) mögliche AVEN Points")
                                            .font(AVENFont.body(13, weight: .medium))
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 11))
                                    }
                                    .foregroundColor(AVENColor.accentPurple)
                                    .padding(.horizontal, AVENSpacing.sm)
                                    .padding(.vertical, 10)
                                    .background(AVENColor.accentPurple.opacity(0.10))
                                    .clipShape(RoundedRectangle(cornerRadius: AVENRadius.md))
                                    .overlay(RoundedRectangle(cornerRadius: AVENRadius.md)
                                        .strokeBorder(AVENColor.accentPurple.opacity(0.3), lineWidth: 1))
                                }
                                .buttonStyle(PressButtonStyle())
                            }
                        }
                    }
                    .cardAppear(delay: 0.06)

                    // ── Task list ─────────────────────────────────────────────
                    VStack(spacing: AVENSpacing.sm) {
                        ForEach(Array(vm.actions.enumerated()), id: \.element.id) { idx, action in
                            ActionCard(action: action, index: idx + 1) { updated in
                                vm.update(updated)
                            } onTapLocked: {
                                showProUpsell = true
                            }
                            .staggerAppear(index: idx, baseDelay: 0.05)
                        }
                    }

                    Color.clear.frame(height: AVENSpacing.xxl)
                }
                .padding(.horizontal, AVENSpacing.md)
            }
            }  // end else (has tasks)
        }
        .sheet(isPresented: $showProUpsell) {
            ProUpsellSheet(lockedCount: vm.proLockedCount, lockedPoints: vm.lockedImpactTotal)
        }
        .onAppear { vm.reload() }
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

// ─── Action card ──────────────────────────────────────────────────────────────

private struct ActionCard: View {
    let action:       GrowthActionItem
    let index:        Int
    let onUpdate:     (GrowthActionItem) -> Void
    let onTapLocked:  () -> Void

    @State private var expanded        = false
    @State private var proofItem:      PhotosPickerItem?
    @State private var proofPicked     = false
    @State private var verifying       = false
    @State private var verifyFailed:   String? = nil   // nil = no error

    private var severityColor: Color {
        switch action.severity {
        case .foundation: return AVENColor.textNegative
        case .lever:      return AVENColor.accentBlue
        case .polish:     return AVENColor.textSecondary
        }
    }

    private var isLocked: Bool { action.isProLocked || action.isBlocked }

    var body: some View {
        AVENCard {
            VStack(spacing: 0) {
                // Row
                Button {
                    if isLocked {
                        onTapLocked()
                    } else {
                        withAnimation(.spring(response: 0.4)) { expanded.toggle() }
                    }
                } label: {
                    HStack(spacing: AVENSpacing.sm) {

                        // Checkbox / number
                        checkCircle

                        // Title + severity
                        VStack(alignment: .leading, spacing: 2) {
                            Text(action.severity.label)
                                .font(AVENFont.body(11, weight: .semibold))
                                .foregroundColor(isLocked || action.isCompleted ? AVENColor.textMuted : severityColor)
                            Text(action.title)
                                .font(AVENFont.body(14, weight: .medium))
                                .foregroundColor(isLocked || action.isCompleted ? AVENColor.textMuted : AVENColor.textPrimary)
                                .strikethrough(action.isCompleted, color: AVENColor.textMuted)
                                .lineLimit(2)
                        }

                        Spacer()

                        // Impact + chevron/lock
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(action.impactLabel)
                                .font(AVENFont.mono(12))
                                .foregroundColor(isLocked || action.isCompleted ? AVENColor.textMuted : AVENColor.accentPurpleLight)
                            Image(systemName: isLocked ? "lock.fill" : (expanded ? "chevron.up" : "chevron.down"))
                                .font(.system(size: 11))
                                .foregroundColor(isLocked ? AVENColor.accentPurple.opacity(0.5) : AVENColor.textMuted)
                        }
                    }
                }
                .buttonStyle(.plain)

                // Expanded detail (only for unlocked tasks)
                if expanded && !isLocked {
                    Divider().background(AVENColor.borderSubtle).padding(.top, AVENSpacing.sm)
                    VStack(alignment: .leading, spacing: AVENSpacing.sm) {
                        Text(action.detail.isEmpty ? defaultDetail(action) : action.detail)
                            .font(AVENFont.body(13))
                            .foregroundColor(AVENColor.textSecondary)
                            .lineSpacing(4)

                        if action.requiresProof {
                            proofSection
                        } else {
                            // Tasks that don't need proof can be marked directly
                            HStack {
                                Spacer()
                                Button {
                                    var updated = action
                                    updated.isCompleted = true
                                    AVENHaptic.success()
                                    withAnimation(AVENMotion.spring) { onUpdate(updated) }
                                    withAnimation(AVENMotion.spring) { expanded = false }
                                } label: {
                                    Label("Als erledigt markieren", systemImage: "checkmark.circle.fill")
                                        .font(AVENFont.body(13, weight: .semibold))
                                        .foregroundColor(AVENColor.textPositive)
                                }
                                .buttonStyle(PressButtonStyle())
                            }
                        }
                    }
                    .padding(.top, AVENSpacing.sm)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Locked preview hint
                if action.isProLocked && !action.isBlocked {
                    Button { onTapLocked() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11))
                            Text("Mit AVEN Pro freischalten")
                                .font(AVENFont.body(12, weight: .semibold))
                        }
                        .foregroundColor(AVENColor.accentPurple)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(AVENColor.accentPurple.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: AVENRadius.sm))
                        .padding(.top, AVENSpacing.sm)
                    }
                    .buttonStyle(PressButtonStyle())
                }
            }
        }
        .opacity(action.isCompleted ? 0.55 : (action.isBlocked ? 0.40 : (action.isProLocked ? 0.70 : 1.0)))
    }

    // ── Proof section ─────────────────────────────────────────────────────────

    @ViewBuilder
    private var proofSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundColor(AVENColor.accentBlue)
                Text("Nachweis erforderlich: Lade einen Screenshot hoch, der zeigt, dass du diese Aufgabe umgesetzt hast.")
                    .font(AVENFont.body(12))
                    .foregroundColor(AVENColor.textSecondary)
                    .lineSpacing(3)
            }

            if verifying {
                HStack(spacing: 8) {
                    ProgressView().tint(AVENColor.accentPurple).scaleEffect(0.85)
                    Text("Screenshot wird geprüft …")
                        .font(AVENFont.body(13))
                        .foregroundColor(AVENColor.textSecondary)
                }
                .padding(.vertical, 6)
            } else if proofPicked {
                // Verification passed
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AVENColor.textPositive)
                    Text("Nachweis bestätigt")
                        .font(AVENFont.body(13, weight: .semibold))
                        .foregroundColor(AVENColor.textPositive)
                }
                Button {
                    var updated = action
                    updated.isCompleted = true
                    AVENHaptic.success()
                    withAnimation(AVENMotion.spring) { onUpdate(updated) }
                    withAnimation(AVENMotion.spring) { expanded = false }
                } label: {
                    Label("Aufgabe abschließen (+\(action.impact) Pts)", systemImage: "checkmark.circle.fill")
                        .font(AVENFont.body(13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(LinearGradient(
                            colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                            startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: AVENRadius.sm))
                }
                .buttonStyle(PressButtonStyle())
            } else {
                // Show error if last attempt failed
                if let err = verifyFailed {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AVENColor.textNegative)
                        Text(err)
                            .font(AVENFont.body(12))
                            .foregroundColor(AVENColor.textNegative)
                            .lineSpacing(3)
                    }
                }
                // Upload picker
                PhotosPicker(
                    selection: $proofItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 14))
                        Text(verifyFailed != nil ? "Erneut hochladen" : "Screenshot hochladen")
                            .font(AVENFont.body(13, weight: .semibold))
                    }
                    .foregroundColor(AVENColor.accentPurple)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AVENColor.accentPurple.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: AVENRadius.sm))
                    .overlay(RoundedRectangle(cornerRadius: AVENRadius.sm)
                        .strokeBorder(AVENColor.accentPurple.opacity(0.3), lineWidth: 1))
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
        guard let data  = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            verifying = false
            verifyFailed = "Bild konnte nicht geladen werden. Bitte erneut versuchen."
            return
        }
        let analyzer = ProfileImageAnalyzer()
        let (passed, message) = await analyzer.verifyProof(
            image:     image,
            category:  action.category,
            taskTitle: action.title
        )
        verifying = false
        if passed {
            proofPicked = true
        } else {
            verifyFailed = message
            proofItem    = nil   // reset so user can pick again
        }
    }

    // ── Checkbox ──────────────────────────────────────────────────────────────

    private var checkCircle: some View {
        Button {
            guard !isLocked else { onTapLocked(); return }
            // Tasks requiring proof can't be tapped directly to complete
            if action.requiresProof && !action.isCompleted {
                withAnimation(.spring(response: 0.4)) {
                    expanded = true   // open detail so user sees proof section
                }
                return
            }
            var updated = action
            updated.isCompleted.toggle()
            if updated.isCompleted { AVENHaptic.success() }
            withAnimation(AVENMotion.spring) { onUpdate(updated) }
        } label: {
            ZStack {
                Circle()
                    .fill(action.isCompleted ? AVENColor.textPositive : AVENColor.backgroundElevated)
                    .frame(width: 32, height: 32)
                    .overlay(Circle().strokeBorder(
                        action.isCompleted ? AVENColor.textPositive : AVENColor.borderSubtle,
                        lineWidth: 1))
                if action.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                } else if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AVENColor.textMuted)
                } else if action.requiresProof {
                    Image(systemName: "camera")
                        .font(.system(size: 12))
                        .foregroundColor(severityColor)
                } else {
                    Text("\(index)")
                        .font(AVENFont.body(13, weight: .bold))
                        .foregroundColor(severityColor)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func defaultDetail(_ action: GrowthActionItem) -> String {
        switch action.severity {
        case .foundation: return "Diese Aufgabe ist essenziell für dein Profilwachstum. Löse sie zuerst, bevor du dich um andere Punkte kümmerst."
        case .lever:      return "Diese Aufgabe hat einen starken Hebel-Effekt auf deinen AVEN Score und deine Reichweite."
        case .polish:     return "Ein optionaler Verbesserungsschritt, der deinen Score weiter optimiert."
        }
    }
}

// ─── Pro upsell sheet ────────────────────────────────────────────────────────

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

                    Text("Schalte deinen kompletten personalisierten Aktionsplan mit \(lockedCount) weiteren Maßnahmen und +\(lockedPoints) möglichen AVEN Points frei.")
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
    var lockedImpactTotal: Int    { actions.filter(\.isProLocked).map(\.impact).reduce(0, +) }
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
    }

    func reload() {
        let goal   = AVENGoalStore.current
        let record = AVENAnalysisStore.load()

        let tasks: [GrowthActionItem]
        if let rec = record {
            // buildFromAnalysis handles completed-ID restoration internally
            tasks = Self.buildFromAnalysis(record: rec, goal: goal,
                                           isProUser: isProUser, freeLimit: freeUnlockLimit)
        } else {
            tasks = []   // no analysis → empty state shown in view
        }

        withAnimation(.spring(response: 0.4)) { actions = tasks }
    }

    func update(_ action: GrowthActionItem) {
        guard let idx = actions.firstIndex(where: { $0.id == action.id }) else { return }
        let wasCompleted = actions[idx].isCompleted
        withAnimation(.spring(response: 0.4)) { actions[idx] = action }
        // Credit points ONLY when transitioning from incomplete → complete.
        // Never double-credit: guard on !wasCompleted.
        if action.isCompleted && !wasCompleted && action.impact > 0 {
            AVENAnalysisStore.applyTaskDelta(action.impact)
            // Broadcast so Home/Analytics refresh immediately
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .analysisDidComplete, object: nil)
            }
        }
        // If uncompleted (edge case), reverse the points
        if !action.isCompleted && wasCompleted && action.impact > 0 {
            AVENAnalysisStore.applyTaskDelta(-action.impact)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .analysisDidComplete, object: nil)
            }
        }
        let completedIDs = actions.filter(\.isCompleted).map(\.id)
        UserDefaults.standard.set(completedIDs, forKey: persistenceKey)
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
