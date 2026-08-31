import SwiftUI

// ─── AVEN + Menu ──────────────────────────────────────────────────────────────

struct CreationMenuSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var container: AppContainer
    @Binding var showNewScan: Bool
    @Binding var showAIVideo: Bool

    @State private var showCoach      = false
    @State private var showVideoSheet = false
    @State private var showGoalSetter = false
    @State private var showGrowthExp  = false
    @State private var showPaywall    = false
    @State private var showComing     = false
    @State private var comingTitle    = ""

    var body: some View {
        ZStack {
            Color(hex: "#F3F3FB").ignoresSafeArea()

            VStack(spacing: 0) {
                header
                mainContent
                CMBottomBar(selectedTab: $container.selectedTab) { dismiss() }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .sheet(isPresented: $showCoach) {
            if container.videoCredits.hasCoachAccess { AICoachPlaceholderView() }
            else { CoachProPlusGate() }
        }
        .sheet(isPresented: $showVideoSheet)  { VideoAnalysisSheet() }
        .sheet(isPresented: $showGoalSetter)  { GoalSetterSheet() }
        .sheet(isPresented: $showGrowthExp)   { GrowthExperimentSheet() }
        .sheet(isPresented: $showPaywall)     { PaywallView() }
        .sheet(isPresented: $showComing)      { CMComingSoon(title: comingTitle) }
    }

    // ── Header ─────────────────────────────────────────────────────────────

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AVENColor.textSecondary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(PressButtonStyle())
                Spacer()
                Text("AVEN")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(LinearGradient(
                        colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                        startPoint: .leading, endPoint: .trailing))
                Spacer()
                Color.clear.frame(width: 32, height: 32)
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

            Text("Was möchtest du tun?")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(AVENColor.textPrimary)
                .padding(.horizontal, 16)
            Text("Wähle eine Option, um dein Wachstum voranzutreiben.")
                .font(.system(size: 13))
                .foregroundColor(AVENColor.textSecondary)
                .padding(.horizontal, 16).padding(.top, 2).padding(.bottom, 12)
        }
    }

    // ── Main scrollable content ─────────────────────────────────────────────

    private var mainContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {

                // ── 1. Hero ──────────────────────────────────────────────
                CMLabel("Für dich empfohlen")
                    .padding(.horizontal, 16)

                Button { showGrowthExp = true } label: { HeroCard() }
                    .buttonStyle(PressButtonStyle())
                    .padding(.horizontal, 16)

                // ── 2. Analysieren & Verstehen ───────────────────────────
                CMLabel("Analysieren & Verstehen")
                    .padding(.horizontal, 16)

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 8),
                              GridItem(.flexible(), spacing: 8)],
                    spacing: 8
                ) {
                    CMAnalCard(
                        icon: "camera.viewfinder", title: "Neue Profilanalyse",
                        desc: "Profil scannen und AVEN Score aktualisieren.", badge: nil
                    ) {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showNewScan = true }
                    }
                    CMAnalCard(
                        icon: "film.stack", title: "Video analysieren",
                        desc: "Hook, Inhalt, CTA und Tempo analysieren.", badge: nil
                    ) { showVideoSheet = true }
                    CMAnalCard(
                        icon: "person.fill.questionmark", title: "AI Coach",
                        desc: "Persönliche Wachstums-Empfehlungen erhalten.", badge: "PRO+"
                    ) { showCoach = true }
                    CMAnalCard(
                        icon: "chart.xyaxis.line", title: "Account Performance",
                        desc: "TikTok-Daten und Entwicklung auswerten.", badge: nil
                    ) {
                        comingTitle = "Account Performance analysieren"
                        showComing  = true
                    }
                }
                .padding(.horizontal, 16)

                // ── 3. Wachstum & Tools ──────────────────────────────────
                CMLabel("Wachstum & Tools")
                    .padding(.horizontal, 16)

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 7),
                              GridItem(.flexible(), spacing: 7),
                              GridItem(.flexible(), spacing: 7),
                              GridItem(.flexible(), spacing: 7)],
                    spacing: 7
                ) {
                    CMToolCard(icon: "lightbulb.fill", title: "Content-Idee",
                               desc: "Kreative Ideen für viralen Content.") {
                        comingTitle = "Content-Idee generieren"; showComing = true
                    }
                    CMToolCard(icon: "clock.fill", title: "Posting-Zeit",
                               desc: "Beste Zeit für dein Publikum.") {
                        comingTitle = "Beste Posting-Zeit"; showComing = true
                    }
                    CMToolCard(icon: "target", title: "Ziel setzen",
                               desc: "Klare Ziele definieren.") { showGoalSetter = true }
                    CMToolCard(icon: "flask.fill", title: "Experiment",
                               desc: "Hooks & Strategien testen.") { showGrowthExp = true }
                }
                .padding(.horizontal, 16)

                // ── 4. PRO+ Banner ───────────────────────────────────────
                Button { showPaywall = true } label {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16))
                            .foregroundStyle(LinearGradient(
                                colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                                startPoint: .leading, endPoint: .trailing))
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 4) {
                                Text("Noch mehr Power mit")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(AVENColor.textPrimary)
                                Text("PRO+")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(LinearGradient(
                                        colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                                        startPoint: .leading, endPoint: .trailing))
                            }
                            Text("Schalte den AI Coach und weitere Premium-Features frei.")
                                .font(.system(size: 10))
                                .foregroundColor(AVENColor.textSecondary)
                        }
                        Spacer()
                        Text("PRO+ entdecken")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(LinearGradient(
                                colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                                startPoint: .leading, endPoint: .trailing))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color.white.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5))
                }
                .buttonStyle(PressButtonStyle())
                .padding(.horizontal, 16)

                Color.clear.frame(height: 6)
            }
            .padding(.top, 2)
        }
    }
}

// ─── Section label ────────────────────────────────────────────────────────────

private struct CMLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundColor(AVENColor.textMuted)
    }
}

// ─── Hero Card ────────────────────────────────────────────────────────────────

private struct HeroCard: View {
    var body: some View {
        HStack(alignment: .center, spacing: 0) {

            // Left — text
            VStack(alignment: .leading, spacing: 8) {
                // Badge
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 8, weight: .semibold))
                    Text("Empfohlen")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                }
                .foregroundColor(AVENColor.accentPurple)
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(Color.white.opacity(0.85))
                .clipShape(Capsule())

                // Title — single line, scales down if needed
                Text("Growth Experiment")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#0D0E1A"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                // Description
                Text("Teste gezielt, was bei deinem Account wirklich funktioniert.")
                    .font(.system(size: 11.5))
                    .foregroundColor(Color(hex: "#5C5E72"))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                // CTA
                HStack(spacing: 4) {
                    Text("Jetzt starten")
                        .font(.system(size: 11.5, weight: .medium))
                    Text("→")
                        .font(.system(size: 11.5))
                }
                .foregroundColor(AVENColor.accentPurple)
                .padding(.horizontal, 11).padding(.vertical, 6)
                .background(Color.white.opacity(0.85))
                .clipShape(Capsule())
                .overlay(Capsule()
                    .strokeBorder(AVENColor.accentPurple.opacity(0.28), lineWidth: 1))
            }
            .padding(.leading, 18)
            .padding(.vertical, 18)
            .layoutPriority(1)  // text wins, flask gets remainder

            // Right — flask illustration (fixed 130pt wide)
            ZStack {
                // sparkles
                SparkleShape().fill(AVENColor.accentPurple.opacity(0.45))
                    .frame(width: 11, height: 11).offset(x: -22, y: -40)
                SparkleShape().fill(AVENColor.accentPurple.opacity(0.28))
                    .frame(width: 7, height: 7).offset(x: 18, y: -48)
                SparkleShape().fill(AVENColor.accentPurple.opacity(0.18))
                    .frame(width: 5, height: 5).offset(x: 32, y: -24)

                // Premium flask drawn with SwiftUI shapes
                PremiumFlask()
                    .frame(width: 84, height: 100)
            }
            .frame(width: 130)
            .padding(.trailing, 10)
        }
        .background(
            LinearGradient(
                colors: [Color(hex: "#EDEEFF"), Color(hex: "#E5E7FA")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(AVENColor.accentPurple.opacity(0.16), lineWidth: 1))
    }
}

// ─── Premium Flask ────────────────────────────────────────────────────────────
// Drawn as SwiftUI Canvas — Erlenmeyer shape with glass highlights,
// liquid body, specular dots.  Fully contained in its .frame().

private struct PremiumFlask: View {
    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width, h = sz.height

            // ── Colours ────────────────────────────────────────────────────
            let base   = Color(hex: "#7B5CE8")          // main purple
            let dark   = Color(hex: "#5535C4")          // shadow / liquid deep
            let light  = Color(hex: "#A98EF5")          // lit area
            let glass  = Color.white.opacity(0.22)      // glass sheen
            let gloss  = Color.white.opacity(0.55)      // specular streak
            let bubble = Color.white.opacity(0.38)      // bubbles

            // ── Helper: smooth lerp for outline ────────────────────────────
            func flaskLeft(_ t: CGFloat) -> CGFloat {
                let neck: CGFloat = 0.28, body: CGFloat = 0.10
                let e = t * t * (3 - 2 * t)
                return w * (neck - e * (neck - body))
            }
            func flaskRight(_ t: CGFloat) -> CGFloat { w - flaskLeft(t) }

            let neckTopY: CGFloat  = h * 0.02
            let neckBotY: CGFloat  = h * 0.30
            let bodyBotY: CGFloat  = h * 0.86
            let steps              = 40

            // Build outline
            var outline = Path()
            outline.move(to: CGPoint(x: flaskLeft(0), y: neckTopY))
            // Left neck → body
            for i in 0...steps {
                let t = CGFloat(i) / CGFloat(steps)
                let y = neckBotY + (bodyBotY - neckBotY) * t
                outline.addLine(to: CGPoint(x: flaskLeft(t), y: y))
            }
            // Bottom arc
            outline.addArc(
                center: CGPoint(x: w / 2, y: bodyBotY),
                radius: w / 2 - flaskLeft(1),
                startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false
            )
            // Right body → neck
            for i in stride(from: steps, through: 0, by: -1) {
                let t = CGFloat(i) / CGFloat(steps)
                let y = neckBotY + (bodyBotY - neckBotY) * t
                outline.addLine(to: CGPoint(x: flaskRight(t), y: y))
            }
            outline.addLine(to: CGPoint(x: flaskRight(0), y: neckTopY))
            outline.closeSubpath()

            // ── Fill base ─────────────────────────────────────────────────
            ctx.fill(outline, with: .color(base))

            // ── Liquid (lower 40 %) ────────────────────────────────────────
            let liquidY: CGFloat = bodyBotY - (bodyBotY - neckBotY) * 0.40
            let liqLX = flaskLeft(0.60)
            let liqRX = flaskRight(0.60)
            var liquid = Path()
            // Curved surface
            liquid.move(to: CGPoint(x: liqLX, y: liquidY))
            liquid.addCurve(
                to: CGPoint(x: liqRX, y: liquidY),
                control1: CGPoint(x: w * 0.33, y: liquidY - h * 0.03),
                control2: CGPoint(x: w * 0.67, y: liquidY - h * 0.03)
            )
            // Down right side
            for i in stride(from: steps * 6 / 10, through: steps, by: 1) {
                let t = CGFloat(i) / CGFloat(steps)
                let y = neckBotY + (bodyBotY - neckBotY) * t
                liquid.addLine(to: CGPoint(x: flaskRight(t), y: y))
            }
            liquid.addArc(
                center: CGPoint(x: w / 2, y: bodyBotY),
                radius: w / 2 - flaskLeft(1),
                startAngle: .degrees(0), endAngle: .degrees(180), clockwise: true
            )
            for i in stride(from: steps, through: steps * 6 / 10, by: -1) {
                let t = CGFloat(i) / CGFloat(steps)
                let y = neckBotY + (bodyBotY - neckBotY) * t
                liquid.addLine(to: CGPoint(x: flaskLeft(t), y: y))
            }
            liquid.closeSubpath()
            ctx.fill(liquid, with: .color(dark))

            // ── Left glass highlight streak ────────────────────────────────
            var streak = Path()
            streak.move(to: CGPoint(x: flaskLeft(0) + 4, y: neckTopY + 2))
            streak.addCurve(
                to: CGPoint(x: flaskLeft(0.50) + 6, y: neckBotY + (bodyBotY - neckBotY) * 0.45),
                control1: CGPoint(x: flaskLeft(0) + 3, y: neckBotY * 0.6),
                control2: CGPoint(x: flaskLeft(0.25) + 5, y: neckBotY + (bodyBotY - neckBotY) * 0.25)
            )
            streak.addLine(to: CGPoint(x: flaskLeft(0.50) + 18, y: neckBotY + (bodyBotY - neckBotY) * 0.45))
            streak.addCurve(
                to: CGPoint(x: flaskLeft(0) + 14, y: neckTopY + 2),
                control1: CGPoint(x: flaskLeft(0.25) + 16, y: neckBotY + (bodyBotY - neckBotY) * 0.25),
                control2: CGPoint(x: flaskLeft(0) + 13, y: neckBotY * 0.6)
            )
            streak.closeSubpath()
            ctx.fill(streak, with: .color(gloss))

            // ── Right soft glow ────────────────────────────────────────────
            var rglow = Path()
            let rx0 = flaskRight(0.30)
            rglow.move(to: CGPoint(x: rx0 - 4, y: neckBotY + (bodyBotY - neckBotY) * 0.10))
            rglow.addLine(to: CGPoint(x: rx0 - 4, y: neckBotY + (bodyBotY - neckBotY) * 0.50))
            rglow.addLine(to: CGPoint(x: rx0 - 18, y: neckBotY + (bodyBotY - neckBotY) * 0.50))
            rglow.addLine(to: CGPoint(x: rx0 - 18, y: neckBotY + (bodyBotY - neckBotY) * 0.10))
            rglow.closeSubpath()
            ctx.fill(rglow, with: .color(glass))

            // ── Neck ──────────────────────────────────────────────────────
            var neck = Path()
            neck.addRect(CGRect(
                x: flaskLeft(0), y: neckTopY,
                width: flaskRight(0) - flaskLeft(0), height: neckBotY - neckTopY
            ))
            ctx.fill(neck, with: .color(dark.opacity(0.55)))

            // Neck highlight
            var nhl = Path()
            nhl.addRect(CGRect(x: flaskLeft(0) + 3, y: neckTopY + 2, width: 7, height: neckBotY - neckTopY - 4))
            ctx.fill(nhl, with: .color(gloss))

            // ── Rim cap ────────────────────────────────────────────────────
            var rim = Path()
            rim.addRoundedRect(
                in: CGRect(x: flaskLeft(0) - 3, y: 0, width: flaskRight(0) - flaskLeft(0) + 6, height: h * 0.07),
                cornerSize: CGSize(width: 3, height: 3)
            )
            ctx.fill(rim, with: .color(dark))

            // ── Bubbles ────────────────────────────────────────────────────
            for (bx, by, br) in [(w*0.40, h*0.75, 4.5), (w*0.58, h*0.80, 3.0), (w*0.50, h*0.70, 2.5)] {
                var b = Path(); b.addEllipse(in: CGRect(x: bx-br, y: by-br, width: br*2, height: br*2))
                ctx.fill(b, with: .color(bubble))
                var bhl = Path(); bhl.addEllipse(in: CGRect(x: bx-1.5, y: by-2, width: 2, height: 1.5))
                ctx.fill(bhl, with: .color(Color.white.opacity(0.7)))
            }

            // ── Bottom catch-light ─────────────────────────────────────────
            var btm = Path()
            btm.addEllipse(in: CGRect(x: w*0.35, y: bodyBotY - 8, width: w*0.30, height: 10))
            ctx.fill(btm, with: .color(Color.white.opacity(0.14)))
        }
    }
}

// ─── SparkleShape ─────────────────────────────────────────────────────────────

private struct SparkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let cx = rect.midX, cy = rect.midY
        let r  = min(rect.width, rect.height) / 2
        var p  = Path()
        for i in 0..<8 {
            let angle  = Double(i) * .pi / 4 - .pi / 2
            let radius = i.isMultiple(of: 2) ? r : r * 0.25
            let x = cx + CGFloat(cos(angle)) * radius
            let y = cy + CGFloat(sin(angle)) * radius
            if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
            else       { p.addLine(to: CGPoint(x: x, y: y)) }
        }
        p.closeSubpath()
        return p
    }
}

// ─── Analysieren card (2-col) ─────────────────────────────────────────────────

private struct CMAnalCard: View {
    let icon:   String
    let title:  String
    let desc:   String
    let badge:  String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(AVENColor.accentPurple.opacity(0.10))
                            .frame(width: 40, height: 40)
                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundColor(AVENColor.accentPurple)
                    }
                    Spacer()
                    if let b = badge {
                        Text(b)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(AVENColor.accentPurple)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(AVENColor.accentPurple.opacity(0.10))
                            .clipShape(Capsule())
                    }
                }
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#0D0E1A"))
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#5C5E72"))
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                HStack {
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AVENColor.accentPurple)
                }
            }
            .padding(13)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.black.opacity(0.07), lineWidth: 0.5))
        }
        .buttonStyle(PressButtonStyle())
    }
}

// ─── Wachstum tool card (4-col) ───────────────────────────────────────────────

private struct CMToolCard: View {
    let icon:   String
    let title:  String
    let desc:   String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AVENColor.accentPurple.opacity(0.10))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(AVENColor.accentPurple)
                }
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#0D0E1A"))
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Text(desc)
                    .font(.system(size: 9.5))
                    .foregroundColor(Color(hex: "#5C5E72"))
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AVENColor.accentPurple)
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.black.opacity(0.07), lineWidth: 0.5))
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
            CMTab(icon: "house",             label: "Home")    { onDismiss(); DispatchQueue.main.asyncAfter(deadline: .now()+0.3) { selectedTab = .home } }
            CMTab(icon: "chart.bar",         label: "Analyse") { onDismiss(); DispatchQueue.main.asyncAfter(deadline: .now()+0.3) { selectedTab = .analytics } }
            // Centre + (active = outline ring)
            ZStack {
                Circle().stroke(AVENColor.accentPurple.opacity(0.5), lineWidth: 1.5)
                    .frame(width: 48, height: 48)
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(AVENColor.accentPurple)
            }
            .frame(maxWidth: .infinity).offset(y: -6)
            CMTab(icon: "checkmark.circle", label: "Plan")    { onDismiss(); DispatchQueue.main.asyncAfter(deadline: .now()+0.3) { selectedTab = .actionPlan } }
            CMTab(icon: "person",           label: "Profil")  { onDismiss(); DispatchQueue.main.asyncAfter(deadline: .now()+0.3) { selectedTab = .profile } }
        }
        .padding(.top, 8).padding(.bottom, 28)
        .background(
            Color.white
                .overlay(Rectangle().frame(height: 0.5)
                    .foregroundColor(Color.black.opacity(0.08)), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

private struct CMTab: View {
    let icon:   String
    let label:  String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 18))
                Text(label).font(.system(size: 10))
            }
            .foregroundColor(AVENColor.textMuted)
            .frame(maxWidth: .infinity)
        }.buttonStyle(.plain)
    }
}

// ─── Feature sheets ───────────────────────────────────────────────────────────

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
            Color(hex: "#F3F3FB").ignoresSafeArea()
            VStack(spacing: 0) {
                Capsule().fill(Color.black.opacity(0.08)).frame(width: 36, height: 4).padding(.top, 10)
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
                            Divider().background(Color.black.opacity(0.06))
                            ForEach(details.points, id: \.self) { pt in
                                HStack(spacing: 8) {
                                    Circle().fill(details.color).frame(width: 5, height: 5)
                                    Text(pt).font(.system(size: 13))
                                        .foregroundColor(AVENColor.textSecondary)
                                }
                            }
                        }
                        .padding(14).background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5))

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

private struct VideoAnalysisSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let features = [
        ("play.circle.fill", "Hook-Analyse (erste 3 Sekunden)"),
        ("text.bubble.fill", "Content-Qualität & Skript"),
        ("hand.tap.fill",    "CTA-Wirksamkeit"),
        ("timer",            "Pacing & Video-Länge"),
        ("star.fill",        "AVEN Content Score"),
    ]
    var body: some View {
        ZStack {
            Color(hex: "#F3F3FB").ignoresSafeArea()
            VStack(spacing: 0) {
                Capsule().fill(Color.black.opacity(0.08)).frame(width: 36, height: 4).padding(.top, 10)
                HStack {
                    Text("Video analysieren").font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(AVENColor.textPrimary)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 22))
                            .foregroundColor(AVENColor.textMuted)
                    }.buttonStyle(PressButtonStyle())
                }.padding(.horizontal, 16).padding(.vertical, 12)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Was wird analysiert?")
                                .font(.system(size: 12, weight: .semibold)).foregroundColor(AVENColor.textMuted)
                                .padding(.bottom, 10)
                            ForEach(features.indices, id: \.self) { i in
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8).fill(AVENColor.accentBlue.opacity(0.10))
                                            .frame(width: 30, height: 30)
                                        Image(systemName: features[i].0).font(.system(size: 13))
                                            .foregroundColor(AVENColor.accentBlue)
                                    }
                                    Text(features[i].1).font(.system(size: 13))
                                        .foregroundColor(AVENColor.textPrimary)
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                if i < features.count-1 { Divider().background(Color.black.opacity(0.05)) }
                            }
                        }
                        .padding(14).background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5))
                        HStack(spacing: 10) {
                            Image(systemName: "bolt.circle.fill").font(.system(size: 20))
                                .foregroundColor(AVENColor.accentBlue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Backend-Verbindung erforderlich")
                                    .font(.system(size: 13, weight: .semibold)).foregroundColor(AVENColor.textPrimary)
                                Text("KI-Analyse wird mit dem AVEN-Backend freigeschaltet.")
                                    .font(.system(size: 11)).foregroundColor(AVENColor.textSecondary)
                            }
                        }
                        .padding(13).background(AVENColor.accentBlue.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(AVENColor.accentBlue.opacity(0.20), lineWidth: 1))
                    }.padding(16)
                }
                Button { dismiss() } label: {
                    Text("Schließen").font(.system(size: 15)).foregroundColor(AVENColor.textSecondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                }.buttonStyle(PressButtonStyle()).padding(.horizontal, 16).padding(.bottom, 28)
            }
        }
        .presentationDetents([.large]).presentationCornerRadius(28)
    }
}

private struct AICoachPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss
    private let caps = [("sparkles","Strategie-Empfehlungen","Personalisierte Wachstumsstrategie für deinen Account"),
                        ("text.bubble.fill","Content-Beratung","Ideen und Feedback zu deinen Videos"),
                        ("chart.line.uptrend.xyaxis","Performance-Analyse","Interpretation deiner Zahlen"),
                        ("target","Ziel-Coaching","Erreichung deiner Follower-Ziele")]
    var body: some View {
        ZStack {
            Color(hex: "#F3F3FB").ignoresSafeArea()
            VStack(spacing: 0) {
                Capsule().fill(Color.black.opacity(0.08)).frame(width: 36, height: 4).padding(.top, 10)
                HStack {
                    Text("AI Coach").font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(AVENColor.textPrimary)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 22))
                            .foregroundColor(AVENColor.textMuted)
                    }.buttonStyle(PressButtonStyle())
                }.padding(.horizontal, 16).padding(.vertical, 12)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Was kann der AI Coach?")
                                .font(.system(size: 12, weight: .semibold)).foregroundColor(AVENColor.textMuted)
                                .padding(.bottom, 10)
                            ForEach(caps.indices, id: \.self) { i in
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8).fill(AVENColor.accentPurple.opacity(0.10))
                                            .frame(width: 30, height: 30)
                                        Image(systemName: caps[i].0).font(.system(size: 13))
                                            .foregroundColor(AVENColor.accentPurple)
                                    }
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(caps[i].1).font(.system(size: 13, weight: .medium))
                                            .foregroundColor(AVENColor.textPrimary)
                                        Text(caps[i].2).font(.system(size: 11))
                                            .foregroundColor(AVENColor.textSecondary)
                                    }
                                    Spacer()
                                }.padding(.vertical, 9)
                                if i < caps.count-1 { Divider().background(Color.black.opacity(0.05)) }
                            }
                        }
                        .padding(14).background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5))
                        HStack(spacing: 10) {
                            Image(systemName: "lock.fill").font(.system(size: 18))
                                .foregroundColor(AVENColor.accentPurple)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("PRO+ erforderlich").font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AVENColor.textPrimary)
                                Text("AI Coach ist exklusiv für PRO+-Nutzer.")
                                    .font(.system(size: 11)).foregroundColor(AVENColor.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(13).background(AVENColor.accentPurple.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(AVENColor.accentPurple.opacity(0.20), lineWidth: 1))
                        AVENPrimaryButton(title: "PRO+ freischalten", icon: "sparkles") { dismiss() }
                    }.padding(16)
                }
                Button { dismiss() } label: {
                    Text("Später").font(.system(size: 15)).foregroundColor(AVENColor.textMuted)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                }.buttonStyle(PressButtonStyle()).padding(.horizontal, 16).padding(.bottom, 28)
            }
        }
        .presentationDetents([.large]).presentationCornerRadius(28)
    }
}

private struct CoachProPlusGate: View {
    var body: some View { AICoachPlaceholderView() }
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
            Color(hex: "#F3F3FB").ignoresSafeArea()
            VStack(spacing: 0) {
                Capsule().fill(Color.black.opacity(0.08)).frame(width: 36, height: 4).padding(.top, 10)
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
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5))
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
                                Capsule().fill(Color.black.opacity(0.07)).frame(height: 8)
                                Capsule().fill(goalType.color).frame(width: g.size.width * min(c/t, 1), height: 8)
                            }
                        }.frame(height: 8)
                    }
                    .padding(13).background(Color.white)
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
                                    .background(deadline==d ? goalType.color : Color.white)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().strokeBorder(deadline==d ? Color.clear : Color.black.opacity(0.08), lineWidth: 0.5))
                            }.buttonStyle(PressButtonStyle())
                        }
                    }
                }

                AVENPrimaryButton(title: "Ziel speichern", icon: "checkmark") {
                    guard !target.isEmpty else { return }
                    let entry: [String: String] = ["type": goalType.rawValue, "current": current,
                        "target": target, "deadline": deadline,
                        "date": ISO8601DateFormatter().string(from: Date())]
                    var all = (UserDefaults.standard.array(forKey: "aven.goals.v2") as? [[String:String]]) ?? []
                    all.removeAll { $0["type"] == goalType.rawValue }
                    all.append(entry)
                    UserDefaults.standard.set(all, forKey: "aven.goals.v2")
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
                                Capsule().fill(Color.black.opacity(0.07)).frame(height: 10)
                                Capsule().fill(goalType.color).frame(width: g.size.width * max(min(c/t,1), 0.04), height: 10)
                            }
                        }.frame(height: 10)
                    }.padding(14).background(Color.white)
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
                .padding(.horizontal, 13).padding(.vertical, 11).background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(focus.wrappedValue ? color.opacity(0.5) : Color.black.opacity(0.07),
                                  lineWidth: focus.wrappedValue ? 1.5 : 1))
        }
    }
}

// ─── Growth Experiment Sheet ──────────────────────────────────────────────────

private struct GrowthExperimentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""; @State private var hypothesis = ""
    @State private var metric = ""; @State private var baseline = ""
    @State private var duration = "7"; @State private var saved = false
    @FocusState private var focus: GEField?
    enum GEField: Hashable { case title, hypo, metric, baseline }
    private var valid: Bool { !title.trimmingCharacters(in:.whitespaces).isEmpty && !hypothesis.trimmingCharacters(in:.whitespaces).isEmpty }

    var body: some View {
        ZStack {
            Color(hex: "#F3F3FB").ignoresSafeArea()
            VStack(spacing: 0) {
                Capsule().fill(Color.black.opacity(0.08)).frame(width: 36, height: 4).padding(.top, 10)
                HStack {
                    Text("Growth Experiment").font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(AVENColor.textPrimary)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 22))
                            .foregroundColor(AVENColor.textMuted)
                    }.buttonStyle(PressButtonStyle())
                }.padding(.horizontal, 16).padding(.vertical, 12)

                if saved { successView } else { formView }
            }
        }
        .presentationDetents([.large]).presentationCornerRadius(28)
        .onTapGesture { focus = nil }
    }

    private var formView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 13) {
                Text("Teste gezielt, was bei deinem Account wirklich funktioniert.")
                    .font(.system(size: 13)).foregroundColor(AVENColor.textSecondary)
                GEField("Titel", "z. B. Posting-Zeit testen", $title, $focus, .title)
                GEField("Hypothese", "Wenn ich … dann …", $hypothesis, $focus, .hypo)
                GEField("Kennzahl", "z. B. Views, Follower", $metric, $focus, .metric)
                GEField("Ausgangswert", "z. B. 500", $baseline, $focus, .baseline, kbd: .numberPad)
                VStack(alignment: .leading, spacing: 7) {
                    Text("Dauer").font(.system(size: 12, weight: .semibold)).foregroundColor(AVENColor.textMuted)
                    HStack(spacing: 7) {
                        ForEach(["3","7","14","30"], id: \.self) { d in
                            Button { duration = d } label: {
                                Text("\(d)d").font(.system(size: 13, weight: duration==d ? .semibold : .regular))
                                    .foregroundColor(duration==d ? .white : AVENColor.textSecondary)
                                    .padding(.horizontal, 15).padding(.vertical, 7)
                                    .background(duration==d ? AVENColor.accentPurple : Color.white)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().strokeBorder(duration==d ? Color.clear : Color.black.opacity(0.08), lineWidth: 0.5))
                            }.buttonStyle(PressButtonStyle())
                        }
                    }
                }
                HStack(spacing: 6) {
                    Image(systemName: "info.circle").foregroundColor(AVENColor.textMuted).font(.system(size: 11))
                    Text("KI-Auswertung wird mit dem AVEN-Backend freigeschaltet.")
                        .font(.system(size: 10)).foregroundColor(AVENColor.textMuted)
                }
                AVENPrimaryButton(title: "Experiment starten", icon: "play.fill") {
                    guard valid else { return }
                    var all = (UserDefaults.standard.array(forKey: "aven.growthExperiments") as? [[String:String]]) ?? []
                    all.append(["id": UUID().uuidString, "title": title, "hypothesis": hypothesis,
                                "metric": metric, "baseline": baseline, "duration": duration,
                                "startDate": ISO8601DateFormatter().string(from: Date()), "status": "active"])
                    UserDefaults.standard.set(all, forKey: "aven.growthExperiments")
                    AVENHaptic.success(); withAnimation { saved = true }
                }.opacity(valid ? 1 : 0.5)
                Color.clear.frame(height: 16)
            }.padding(16)
        }
    }

    private var successView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(AVENColor.accentPurple.opacity(0.10)).frame(width: 72, height: 72)
                    Image(systemName: "flask.fill").font(.system(size: 34))
                        .foregroundStyle(LinearGradient(colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                VStack(spacing: 7) {
                    Text("Experiment läuft!").font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundColor(AVENColor.textPrimary)
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(AVENColor.accentPurple)
                    Text("Trage nach \(duration) Tagen deinen Endwert ein.")
                        .font(.system(size: 13)).foregroundColor(AVENColor.textSecondary).multilineTextAlignment(.center)
                }
            }
            Spacer()
            Button { dismiss() } label: {
                Text("Fertig").font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(LinearGradient(colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                                               startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }.buttonStyle(PressButtonStyle()).padding(.horizontal, 16).padding(.bottom, 32)
        }
    }
}

private struct GEField: View {
    let label: String; let ph: String
    @Binding var text: String
    var focus: FocusState<GrowthExperimentSheet.GEField?>.Binding
    let tag: GrowthExperimentSheet.GEField
    var kbd: UIKeyboardType = .default
    init(_ l: String, _ p: String, _ t: Binding<String>,
         _ f: FocusState<GrowthExperimentSheet.GEField?>.Binding,
         _ tag: GrowthExperimentSheet.GEField, kbd: UIKeyboardType = .default) {
        label=l; ph=p; _text=t; focus=f; self.tag=tag; self.kbd=kbd
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.system(size: 12, weight: .semibold)).foregroundColor(AVENColor.textMuted)
            TextField(ph, text: $text, axis: .vertical).font(.system(size: 13))
                .foregroundColor(AVENColor.textPrimary).keyboardType(kbd).focused(focus, equals: tag)
                .padding(10).background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(focus.wrappedValue == tag ? AVENColor.accentPurple.opacity(0.45) : Color.black.opacity(0.07),
                                  lineWidth: focus.wrappedValue == tag ? 1.5 : 1))
        }
    }
}

#Preview {
    CreationMenuSheet(showNewScan: .constant(false), showAIVideo: .constant(false))
        .environmentObject(AppContainer.preview)
}
