import SwiftUI

// ─── PaywallView ─────────────────────────────────────────────────────────────

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = PaywallViewModel()

    var body: some View {
        ZStack {
            AVENColor.backgroundPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: AVENSpacing.lg) {
                    // Close button
                    HStack {
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(AVENColor.textMuted)
                        }
                        .buttonStyle(PressButtonStyle())
                    }
                    .padding(.top, AVENSpacing.sm)
                    VStack(spacing: AVENSpacing.sm) {
                        Text("AVEN")
                            .font(AVENFont.display(28))
                            .foregroundStyle(LinearGradient(
                                colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                                startPoint: .leading, endPoint: .trailing))
                        Text("Wähle deinen Plan")
                            .font(AVENFont.body(16))
                            .foregroundColor(AVENColor.textSecondary)
                    }
                    .padding(.top, AVENSpacing.xl)

                    // Plan cards
                    ForEach(AVENPlan.allCases, id: \.self) { plan in
                        PlanCard(
                            plan:       plan,
                            isSelected: vm.selectedPlan == plan,
                            isCurrentPlan: plan == .free
                        ) { AVENHaptic.selection(); vm.selectedPlan = plan }
                        .transition(.scale.combined(with: .opacity))
                    }

                    // CTA
                    if vm.selectedPlan != .free {
                        VStack(spacing: AVENSpacing.sm) {
                            AVENPrimaryButton(title: vm.ctaTitle, icon: "star.fill") {
                                vm.purchase()
                            }
                            // MARK: - StoreKit Integration Point
                            // Replace vm.purchase() with StoreKit 2 Product.purchase()
                            Text("Jederzeit kündbar. Keine versteckten Kosten.")
                                .font(AVENFont.body(12))
                                .foregroundColor(AVENColor.textMuted)
                                .multilineTextAlignment(.center)
                        }
                    } else {
                        Button { dismiss() } label: {
                            Text("Mit FREE weitermachen")
                                .font(AVENFont.body(15))
                                .foregroundColor(AVENColor.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(PressButtonStyle())
                    }

                    // Legal
                    HStack(spacing: AVENSpacing.lg) {
                        Button("Datenschutz") { }
                            .font(AVENFont.body(12))
                            .foregroundColor(AVENColor.textMuted)
                        Button("AGB") { }
                            .font(AVENFont.body(12))
                            .foregroundColor(AVENColor.textMuted)
                        Button("Käufe wiederherstellen") { vm.restorePurchases() }
                            .font(AVENFont.body(12))
                            .foregroundColor(AVENColor.textMuted)
                    }
                    .padding(.bottom, AVENSpacing.xl)
                }
                .padding(.horizontal, AVENSpacing.md)
            }
        }
        .alert("Noch nicht verfügbar", isPresented: $vm.showStoreKitAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("In-App-Käufe werden in einer zukünftigen Version aktiviert.")
        }
    }
}

// ─── Plan card ────────────────────────────────────────────────────────────────

private struct PlanCard: View {
    let plan:          AVENPlan
    let isSelected:    Bool
    let isCurrentPlan: Bool
    let onSelect:      () -> Void

    @State private var appeared = false

    private var isHighlighted: Bool { plan == .pro }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: AVENSpacing.md) {
                // Plan header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: AVENSpacing.sm) {
                            Text(plan.displayName)
                                .font(AVENFont.display(20))
                                .foregroundColor(AVENColor.textPrimary)
                            if isHighlighted {
                                Text("BELIEBT")
                                    .font(AVENFont.body(10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(AVENColor.accentPurple)
                                    .clipShape(Capsule())
                            }
                            if isCurrentPlan {
                                Text("Aktuell")
                                    .font(AVENFont.body(10, weight: .semibold))
                                    .foregroundColor(AVENColor.textSecondary)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(AVENColor.backgroundElevated)
                                    .clipShape(Capsule())
                            }
                        }
                        Text(plan.monthlyPrice)
                            .font(AVENFont.body(14))
                            .foregroundColor(AVENColor.textSecondary)
                    }
                    Spacer()
                    // Selection indicator
                    ZStack {
                        Circle()
                            .strokeBorder(isSelected ? AVENColor.accentPurple : AVENColor.borderSubtle, lineWidth: 2)
                            .frame(width: 24, height: 24)
                        if isSelected {
                            Circle().fill(AVENColor.accentPurple).frame(width: 14, height: 14)
                        }
                    }
                    .animation(.spring(response: 0.3), value: isSelected)
                }

                Divider().background(AVENColor.borderSubtle)

                // Feature list
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(plan.features) { feature in
                        HStack(spacing: 8) {
                            Image(systemName: feature.included ? "checkmark.circle.fill" : "xmark.circle")
                                .font(.system(size: 14))
                                .foregroundColor(feature.included ? AVENColor.textPositive : AVENColor.textMuted)
                            Text(feature.title)
                                .font(AVENFont.body(13))
                                .foregroundColor(feature.included ? AVENColor.textPrimary : AVENColor.textMuted)
                        }
                    }
                }
            }
            .padding(AVENSpacing.md)
            .background(
                isSelected
                    ? AVENColor.backgroundElevated
                    : AVENColor.backgroundCard
            )
            .clipShape(RoundedRectangle(cornerRadius: AVENRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AVENRadius.lg)
                    .strokeBorder(
                        isSelected ? AVENColor.accentPurple : (isHighlighted ? AVENColor.borderAccent : AVENColor.borderSubtle),
                        lineWidth: isSelected ? 2 : 1
                    )
                    .animation(AVENMotion.spring, value: isSelected)
            )
            .planCardStyle(selected: isSelected)
            .avGlow(color: AVENColor.accentPurple, radius: isSelected ? 12 : 0)
            .animation(AVENMotion.spring, value: isSelected)
            .scaleEffect(appeared ? 1.0 : 0.96)
            .opacity(appeared ? 1.0 : 0)
            .animation(
                AVENMotion.springGentle.delay(Double(AVENPlan.allCases.firstIndex(of: plan) ?? 0) * 0.09),
                value: appeared
            )
        }
        .buttonStyle(PressButtonStyle())
        .onAppear { withAnimation { appeared = true } }
    }
}

// ─── ViewModel ────────────────────────────────────────────────────────────────

@MainActor
final class PaywallViewModel: ObservableObject {
    @Published var selectedPlan: AVENPlan = .pro
    @Published var showStoreKitAlert = false

    var ctaTitle: String {
        switch selectedPlan {
        case .free:    return "Mit FREE weitermachen"
        case .pro:     return "PRO starten – \(AVENPlan.pro.monthlyPrice)"
        case .proPlus: return "PRO+ starten – \(AVENPlan.proPlus.monthlyPrice)"
        }
    }

    func purchase() {
        // MARK: - StoreKit 2 Integration Point
        // let product = try await Product.products(for: [selectedPlan.storeKitProductID]).first
        // let result  = try await product?.purchase()
        showStoreKitAlert = true
    }

    func restorePurchases() {
        // MARK: - StoreKit 2 Integration Point
        // try await AppStore.sync()
        showStoreKitAlert = true
    }
}

#Preview {
    PaywallView()
}
