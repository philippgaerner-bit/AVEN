import SwiftUI

// ─── AVEN Premium Onboarding — 6 visually unique screens ─────────────────────
// onComplete() fires ONLY on screen 6 "AVEN starten".
// RootView: @AppStorage("aven.hasCompletedOnboarding") gates entry.

struct AVENOnboardingView: View {
    let onComplete: () -> Void
    @State private var page = 0
    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                // Swipeable pages
                TabView(selection: $page) {
                    OBHeroScreen().tag(0)
                    OBScanScreen().tag(1)
                    OBScoreScreen().tag(2)
                    OBActionScreen().tag(3)
                    OBGrowthScreen().tag(4)
                    OBReadyScreen(onComplete: onComplete).tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(reduce ? .none : .easeInOut(duration: 0.38), value: page)

                // Dot indicator
                HStack(spacing: 8) {
                    ForEach(0..<6, id: \.self) { i in
                        Capsule()
                            .fill(i == page
                                  ? AnyShapeStyle(LinearGradient(
                                        colors: [Color(hex:"#9B5CFF"), Color(hex:"#4F8FFF")],
                                        startPoint: .leading, endPoint: .trailing))
                                  : AnyShapeStyle(Color(hex:"#222234")))
                            .frame(width: i == page ? 22 : 8, height: 8)
                            .animation(.spring(response: 0.4), value: page)
                    }
                }
                .padding(.bottom, 14)

                // Next button — hidden on last page (has its own)
                if page < 5 {
                    OBButton("Weiter") {
                        withAnimation(.easeInOut(duration: 0.38)) { page += 1 }
                    }
                }
            }
        }
    }
}

// ─── Shared button ────────────────────────────────────────────────────────────

struct OBButton: View {
    let title: String
    let action: () -> Void
    @State private var pressing = false
    init(_ title: String, action: @escaping () -> Void) {
        self.title = title; self.action = action
    }
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 17)
                .background(LinearGradient(
                    colors: [Color(hex:"#7B4FFF"), Color(hex:"#4F8FFF")],
                    startPoint: .leading, endPoint: .trailing))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .scaleEffect(pressing ? 0.97 : 1.0)
                .animation(.spring(response: 0.25), value: pressing)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24).padding(.bottom, 44)
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in pressing = true }
            .onEnded   { _ in pressing = false })
    }
}

// ─── Glow orb helper ─────────────────────────────────────────────────────────

private struct GlowOrb: View {
    let color: Color
    let size: CGFloat
    var opacity: Double = 0.25
    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [color.opacity(opacity), .clear],
                                 center: .center, startRadius: 0, endRadius: size/2))
            .frame(width: size, height: size)
            .blur(radius: 20)
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN 1 — AVEN HERO
// Large gradient "AVEN" text + pulsing glow orbs + sparkle particles
// ══════════════════════════════════════════════════════════════════════════════

struct OBHeroScreen: View {
    @State private var on = false
    @State private var breathe = false
    // 6 fixed sparkle positions (x,y as fraction of 300px canvas)
    private let sparkPos: [(CGFloat,CGFloat)] =
        [(0.15,0.20),(0.80,0.15),(0.10,0.65),(0.85,0.60),(0.50,0.10),(0.30,0.80)]
    @State private var sparkAlpha: [Double] = Array(repeating: 0, count: 6)
    @State private var sparkTask: Task<Void,Never>? = nil

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                // Background glow orbs — Purple / Blue / Cyan
                GlowOrb(color: Color(hex:"#9B5CFF"), size: 200, opacity: breathe ? 0.28 : 0.08)
                    .offset(x: -40, y: -30)
                    .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: breathe)
                GlowOrb(color: Color(hex:"#4F8FFF"), size: 160, opacity: breathe ? 0.20 : 0.06)
                    .offset(x: 50, y: 20)
                    .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true), value: breathe)
                GlowOrb(color: Color(hex:"#00D4FF"), size: 120, opacity: breathe ? 0.15 : 0.04)
                    .offset(x: 10, y: 50)
                    .animation(.easeInOut(duration: 3.1).repeatForever(autoreverses: true), value: breathe)

                // Sparkles — Purple / Blue / Cyan
                ForEach(0..<sparkPos.count, id: \.self) { i in
                    Image(systemName: i % 3 == 0 ? "sparkle" : i % 3 == 1 ? "star.fill" : "circle.fill")
                        .font(.system(size: i % 3 == 0 ? 13 : i % 3 == 1 ? 9 : 5))
                        .foregroundColor(i % 3 == 0 ? Color(hex:"#9B5CFF") : i % 3 == 1 ? Color(hex:"#4F8FFF") : Color(hex:"#00D4FF"))
                        .opacity(sparkAlpha[i])
                        .position(x: sparkPos[i].0 * 300, y: sparkPos[i].1 * 300)
                }

                // AVEN text — the actual hero
                VStack(spacing: 10) {
                    Text("AVEN")
                        .font(.system(size: 76, weight: .black, design: .rounded))
                        .foregroundStyle(LinearGradient(
                            colors: [Color(hex:"#C07AFF"), Color(hex:"#5B9FFF"), Color(hex:"#00D4FF")],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .shadow(color: Color(hex:"#9B5CFF").opacity(0.5), radius: 24)
                        .shadow(color: Color(hex:"#00D4FF").opacity(0.2), radius: 36)
                        .scaleEffect(on ? (breathe ? 1.015 : 1.0) : 0.82)
                        .opacity(on ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.05), value: on)
                        .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: breathe)

                    // Premium product label
                    HStack(spacing: 5) {
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [Color(hex:"#9B5CFF").opacity(0), Color(hex:"#9B5CFF")],
                                startPoint: .leading, endPoint: .trailing))
                            .frame(width: 22, height: 1)
                        Text("TikTok Profile Intelligence")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(LinearGradient(
                                colors: [Color(hex:"#A07AFF"), Color(hex:"#5B9FFF"), Color(hex:"#00D4FF")],
                                startPoint: .leading, endPoint: .trailing))
                            .tracking(2.5)
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [Color(hex:"#00D4FF"), Color(hex:"#00D4FF").opacity(0)],
                                startPoint: .leading, endPoint: .trailing))
                            .frame(width: 22, height: 1)
                    }
                    .opacity(on ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.28), value: on)
                }
            }
            .frame(width: 300, height: 300)

            // Headline + body — improved hierarchy
            VStack(spacing: 8) {
                Text("Willkommen bei AVEN")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white).multilineTextAlignment(.center)
                    .opacity(on ? 1 : 0).offset(y: on ? 0 : 14)
                    .animation(.easeOut(duration: 0.5).delay(0.4), value: on)

                Text("Dein Profil. Dein Wachstum. Dein nächstes Level.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(hex:"#A07AFF"), Color(hex:"#5B9FFF"), Color(hex:"#00D4FF")],
                        startPoint: .leading, endPoint: .trailing))
                    .multilineTextAlignment(.center)
                    .opacity(on ? 1 : 0).offset(y: on ? 0 : 8)
                    .animation(.easeOut(duration: 0.5).delay(0.52), value: on)

                Spacer().frame(height: 6)

                Text("AVEN analysiert dein TikTok-Profil und zeigt dir Schritt für Schritt, wie du es verbesserst.")
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex:"#8E8EA0"))
                    .multilineTextAlignment(.center).lineSpacing(4)
                    .padding(.horizontal, 32)
                    .opacity(on ? 1 : 0).offset(y: on ? 0 : 8)
                    .animation(.easeOut(duration: 0.5).delay(0.62), value: on)
            }
            Spacer()
        }
        .onAppear {
            on = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { breathe = true }
            sparkTask = Task {
                for i in 0..<sparkPos.count {
                    try? await Task.sleep(nanoseconds: UInt64((0.5 + Double(i)*0.15) * 1e9))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeIn(duration: 0.3)) { sparkAlpha[i] = Double.random(in: 0.5...1.0) }
                }
                // Slow pulse loop
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                    guard !Task.isCancelled else { return }
                    for i in 0..<sparkAlpha.count {
                        withAnimation(.easeInOut(duration: 0.9)) {
                            sparkAlpha[i] = Double.random(in: 0.15...0.85)
                        }
                    }
                }
            }
        }
        .onDisappear {
            on = false; breathe = false
            sparkTask?.cancel(); sparkTask = nil
            sparkAlpha = Array(repeating: 0, count: 6)
        }
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN 2 — LIVE PROFILE SCANNER
// Fake TikTok profile card with animated scan line
// ══════════════════════════════════════════════════════════════════════════════

struct OBScanScreen: View {
    @State private var on = false
    @State private var scanning = false
    @State private var checkAvatar = false
    @State private var checkBio = false
    @State private var checkStats = false
    @State private var done = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            // Profile card
            ZStack(alignment: .top) {
                // Card body
                VStack(alignment: .leading, spacing: 10) {
                    // Row 1: avatar + handle
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(LinearGradient(colors:[Color(hex:"#9B5CFF"),Color(hex:"#4F8FFF")],
                                                        startPoint:.topLeading,endPoint:.bottomTrailing))
                                .frame(width: 46, height: 46)
                            Text("A").font(.system(size:20,weight:.bold)).foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("@creator_pro").font(.system(size:14,weight:.semibold)).foregroundColor(.white)
                            Text("Content Creator · Growth").font(.system(size:11)).foregroundColor(Color(hex:"#8E8EA0"))
                        }
                        Spacer()
                        if checkAvatar {
                            Image(systemName:"checkmark.circle.fill")
                                .foregroundColor(Color(hex:"#34D399")).font(.system(size:16))
                                .transition(.scale.combined(with:.opacity))
                        }
                    }
                    Rectangle().fill(Color(hex:"#222234")).frame(height: 1)
                    // Bio
                    HStack {
                        Text("🎯 TikTok Growth & Strategie\n✨ Täglich neue Tipps\n👇 Link unten")
                            .font(.system(size:12)).foregroundColor(Color(hex:"#8E8EA0")).lineSpacing(3)
                        Spacer()
                        if checkBio {
                            Image(systemName:"checkmark.circle.fill")
                                .foregroundColor(Color(hex:"#34D399")).font(.system(size:16))
                                .transition(.scale.combined(with:.opacity))
                        }
                    }
                    Rectangle().fill(Color(hex:"#222234")).frame(height: 1)
                    // Stats row
                    HStack {
                        ForEach(["12K\nFollower","840K\nLikes","8.7%\nEngage"], id:\.self) { s in
                            Text(s).font(.system(size:11,weight:.medium)).foregroundColor(Color(hex:"#8E8EA0"))
                                .multilineTextAlignment(.center).frame(maxWidth:.infinity)
                        }
                        if checkStats {
                            Image(systemName:"checkmark.circle.fill")
                                .foregroundColor(Color(hex:"#34D399")).font(.system(size:16))
                                .transition(.scale.combined(with:.opacity))
                        }
                    }
                    // Thumbnails — scan line strictly clipped here
                    ZStack {
                        HStack(spacing: 6) {
                            ForEach(0..<3, id:\.self) { _ in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(hex:"#222234")).frame(height: 50).frame(maxWidth:.infinity)
                            }
                        }
                        if scanning {
                            Rectangle()
                                .fill(LinearGradient(
                                    colors:[Color(hex:"#9B5CFF").opacity(0),
                                            Color(hex:"#9B5CFF"),
                                            Color(hex:"#4F8FFF"),
                                            Color(hex:"#00D4FF"),
                                            Color(hex:"#00D4FF").opacity(0)],
                                    startPoint:.leading, endPoint:.trailing))
                                .frame(height: 2)
                                .shadow(color:Color(hex:"#9B5CFF"), radius:6)
                        }
                    }
                    .frame(height: 50)
                    .clipped()
                    if done {
                        Label("Analyse abgeschlossen", systemImage:"checkmark.shield.fill")
                            .font(.system(size:12,weight:.semibold)).foregroundColor(Color(hex:"#34D399"))
                            .transition(.move(edge:.bottom).combined(with:.opacity))
                    }
                }
                .padding(16)
                .background(Color(hex:"#16161F"))
                .clipShape(RoundedRectangle(cornerRadius:16))
                .overlay(RoundedRectangle(cornerRadius:16).stroke(Color(hex:"#222234"),lineWidth:1))

                // Scan corners only (scan line now lives inside thumbnail ZStack)
                OBScanFrame()
            }
            .frame(maxWidth: 300)
            .opacity(on ? 1 : 0).scaleEffect(on ? 1 : 0.9)
            .animation(.easeOut(duration:0.4), value: on)

            Spacer().frame(height: 20)
            VStack(spacing: 12) {
                Text("Analysiere dein Profil")
                    .font(.system(size:26,weight:.bold,design:.rounded)).foregroundColor(.white)
                    .opacity(on ? 1 : 0).offset(y: on ? 0 : 10)
                    .animation(.easeOut(duration:0.5).delay(0.2), value: on)
                Text("AVEN erkennt, was bereits stark ist – und wo noch Potenzial steckt.")
                    .font(.system(size:15)).foregroundColor(Color(hex:"#8E8EA0"))
                    .multilineTextAlignment(.center).padding(.horizontal,32)
                    .opacity(on ? 1 : 0).offset(y: on ? 0 : 6)
                    .animation(.easeOut(duration:0.5).delay(0.35), value: on)
            }
            Spacer()
        }
        .onAppear {
            on = true
            DispatchQueue.main.asyncAfter(deadline:.now()+0.5) {
                scanning = true
                DispatchQueue.main.asyncAfter(deadline:.now()+0.3){ withAnimation(.spring()){ checkAvatar=true } }
                DispatchQueue.main.asyncAfter(deadline:.now()+0.7){ withAnimation(.spring()){ checkBio=true } }
                DispatchQueue.main.asyncAfter(deadline:.now()+1.1){ withAnimation(.spring()){ checkStats=true } }
                DispatchQueue.main.asyncAfter(deadline:.now()+1.5){ scanning=false; withAnimation(.spring()){ done=true } }
            }
        }
        .onDisappear {
            on=false; scanning=false
            checkAvatar=false; checkBio=false; checkStats=false; done=false
        }
    }
}

private struct OBScanFrame: View {
    var body: some View {
        GeometryReader { g in
            ZStack(alignment:.topLeading) {
                // top-left
                OBCornerMark(flipH: false, flipV: false)
                    .position(x: 12, y: 12)
                // top-right
                OBCornerMark(flipH: true, flipV: false)
                    .position(x: g.size.width-12, y: 12)
                // bottom-left
                OBCornerMark(flipH: false, flipV: true)
                    .position(x: 12, y: g.size.height-12)
                // bottom-right
                OBCornerMark(flipH: true, flipV: true)
                    .position(x: g.size.width-12, y: g.size.height-12)
            }
        }
    }
}

private struct OBCornerMark: View {
    let flipH: Bool; let flipV: Bool
    var body: some View {
        ZStack(alignment:.topLeading) {
            Rectangle().fill(Color(hex:"#9B5CFF")).frame(width:18,height:2)
            Rectangle().fill(Color(hex:"#9B5CFF")).frame(width:2,height:18)
        }
        .scaleEffect(x: flipH ? -1 : 1, y: flipV ? -1 : 1)
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN 3 — AVEN SCORE RING
// Circular progress ring + count-up + dimension bars
// ══════════════════════════════════════════════════════════════════════════════

struct OBScoreScreen: View {
    @State private var on = false
    @State private var ringProg: Double = 0
    @State private var scoreNum: Int = 0
    @State private var barsOn = false
    private let dims = [("PROFIL",0.92),("BIO",0.84),("BRANDING",0.89),("CONTENT",0.81)]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            // Ring
            ZStack {
                Circle().stroke(Color(hex:"#222234"), lineWidth:12).frame(width:180,height:180)
                Circle()
                    .trim(from:0, to:ringProg)
                    .stroke(LinearGradient(colors:[Color(hex:"#9B5CFF"),Color(hex:"#4F8FFF")],
                                           startPoint:.topLeading,endPoint:.bottomTrailing),
                            style: StrokeStyle(lineWidth:12,lineCap:.round))
                    .rotationEffect(.degrees(-90))
                    .frame(width:180,height:180)
                    .shadow(color:Color(hex:"#9B5CFF").opacity(0.5),radius:8)
                    .animation(.easeOut(duration:1.5).delay(0.3), value:ringProg)
                VStack(spacing:4) {
                    Text("\(scoreNum)")
                        .font(.system(size:52,weight:.black,design:.rounded))
                        .foregroundStyle(LinearGradient(
                            colors:[Color(hex:"#B07AFF"),Color(hex:"#4F8FFF")],
                            startPoint:.topLeading,endPoint:.bottomTrailing))
                    Text("AVEN SCORE").font(.system(size:10,weight:.bold)).foregroundColor(Color(hex:"#5A5A6E")).tracking(2)
                }
            }
            .scaleEffect(on ? 1 : 0.7).opacity(on ? 1 : 0)
            .animation(.spring(response:0.6,dampingFraction:0.7).delay(0.1), value:on)

            // Status pill
            Text("Sehr gut ↑")
                .font(.system(size:13,weight:.semibold)).foregroundColor(Color(hex:"#34D399"))
                .padding(.horizontal,14).padding(.vertical,5)
                .background(Color(hex:"#34D399").opacity(0.12)).clipShape(Capsule())
                .padding(.top,8)
                .opacity(on ? 1 : 0).animation(.easeOut(duration:0.4).delay(0.9), value:on)

            Spacer().frame(height:18)

            // Dimension bars
            VStack(spacing:8) {
                ForEach(Array(dims.enumerated()), id:\.offset) { idx, dim in
                    HStack(spacing:10) {
                        Text(dim.0).font(.system(size:11,weight:.semibold)).foregroundColor(Color(hex:"#8E8EA0"))
                            .frame(width:60,alignment:.leading)
                        GeometryReader { g in
                            ZStack(alignment:.leading) {
                                RoundedRectangle(cornerRadius:3).fill(Color(hex:"#222234"))
                                RoundedRectangle(cornerRadius:3)
                                    .fill(LinearGradient(colors:[Color(hex:"#9B5CFF"),Color(hex:"#4F8FFF")],
                                                        startPoint:.leading,endPoint:.trailing))
                                    .frame(width: barsOn ? g.size.width*dim.1 : 0)
                                    .animation(.easeOut(duration:0.8).delay(0.1+Double(idx)*0.08), value:barsOn)
                            }
                        }
                        .frame(height:6)
                        Text("\(Int(dim.1*100))").font(.system(size:11,weight:.medium))
                            .foregroundColor(.white).frame(width:24,alignment:.trailing)
                    }
                }
            }
            .padding(.horizontal,32)
            .opacity(on ? 1 : 0).animation(.easeOut(duration:0.4).delay(0.85), value:on)

            Spacer().frame(height:16)
            VStack(spacing:12) {
                Text("Dein AVEN Score")
                    .font(.system(size:26,weight:.bold,design:.rounded)).foregroundColor(.white)
                    .opacity(on ? 1 : 0).offset(y: on ? 0 : 10)
                    .animation(.easeOut(duration:0.5).delay(0.15), value:on)
                Text("Sieh sofort, wie stark dein Profil optimiert ist.")
                    .font(.system(size:15)).foregroundColor(Color(hex:"#8E8EA0"))
                    .multilineTextAlignment(.center).padding(.horizontal,32)
                    .opacity(on ? 1 : 0).offset(y: on ? 0 : 6)
                    .animation(.easeOut(duration:0.5).delay(0.3), value:on)
            }
            Spacer()
        }
        .onAppear {
            on = true
            DispatchQueue.main.asyncAfter(deadline:.now()+0.4) {
                ringProg = 0.87; barsOn = true
                let total = 87
                for i in 0...total {
                    DispatchQueue.main.asyncAfter(deadline:.now()+Double(i)*(1.5/Double(total))) {
                        scoreNum = i
                    }
                }
            }
        }
        .onDisappear { on=false; ringProg=0; scoreNum=0; barsOn=false }
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN 4 — ACTION PLAN
// Cards fly in, checkmarks animate, points float up
// ══════════════════════════════════════════════════════════════════════════════

struct OBActionScreen: View {
    @State private var on = false
    @State private var c0=false
    @State private var c1=false
    @State private var c2=false
    @State private var ch0=false
    @State private var ch1=false
    @State private var p0=false
    @State private var p1=false

    private let tasks: [(String,String)] = [
        ("Bio klarer positionieren","+5"),
        ("CTA hinzufügen","+3"),
        ("Branding vereinheitlichen","+4"),
    ]

    var body: some View {
        VStack(spacing:0) {
            Spacer()
            // Progress bar
            VStack(alignment:.leading,spacing:6) {
                HStack {
                    Text("2 von 3 erledigt").font(.system(size:12,weight:.semibold)).foregroundColor(Color(hex:"#8E8EA0"))
                    Spacer()
                }
                GeometryReader { g in
                    ZStack(alignment:.leading) {
                        RoundedRectangle(cornerRadius:3).fill(Color(hex:"#222234"))
                        RoundedRectangle(cornerRadius:3)
                            .fill(LinearGradient(colors:[Color(hex:"#9B5CFF"),Color(hex:"#4F8FFF")],
                                                startPoint:.leading,endPoint:.trailing))
                            .frame(width: on ? g.size.width * 0.667 : 0)
                            .animation(.easeOut(duration:0.8).delay(0.8), value:on)
                    }
                }
                .frame(height:5)
            }
            .padding(.horizontal,32)
            .opacity(on ? 1 : 0).animation(.easeOut(duration:0.4).delay(0.2), value:on)

            Spacer().frame(height:14)

            // Task cards
            VStack(spacing:10) {
                OBTaskCard(title:tasks[0].0, pts:tasks[0].1, visible:c0, checked:ch0, ptsUp:p0)
                OBTaskCard(title:tasks[1].0, pts:tasks[1].1, visible:c1, checked:ch1, ptsUp:p1)
                OBTaskCard(title:tasks[2].0, pts:tasks[2].1, visible:c2, checked:false, ptsUp:false)
            }
            .frame(maxWidth:300)

            Spacer().frame(height:18)
            VStack(spacing:12) {
                Text("Dein persönlicher Aktionsplan")
                    .font(.system(size:24,weight:.bold,design:.rounded)).foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .opacity(on ? 1 : 0).offset(y: on ? 0 : 10)
                    .animation(.easeOut(duration:0.5).delay(0.1), value:on)
                Text("Du bekommst konkrete Aufgaben statt allgemeiner Tipps.")
                    .font(.system(size:15)).foregroundColor(Color(hex:"#8E8EA0"))
                    .multilineTextAlignment(.center).padding(.horizontal,32)
                    .opacity(on ? 1 : 0).offset(y: on ? 0 : 6)
                    .animation(.easeOut(duration:0.5).delay(0.25), value:on)
            }
            Spacer()
        }
        .onAppear {
            on = true
            DispatchQueue.main.asyncAfter(deadline:.now()+0.2){ withAnimation(.spring(response:0.45)){ c0=true } }
            DispatchQueue.main.asyncAfter(deadline:.now()+0.38){ withAnimation(.spring(response:0.45)){ c1=true } }
            DispatchQueue.main.asyncAfter(deadline:.now()+0.55){ withAnimation(.spring(response:0.45)){ c2=true } }
            DispatchQueue.main.asyncAfter(deadline:.now()+0.85){ withAnimation(.spring()){ ch0=true } }
            DispatchQueue.main.asyncAfter(deadline:.now()+0.95){ withAnimation(.easeOut(duration:0.5)){ p0=true } }
            DispatchQueue.main.asyncAfter(deadline:.now()+1.15){ withAnimation(.spring()){ ch1=true } }
            DispatchQueue.main.asyncAfter(deadline:.now()+1.25){ withAnimation(.easeOut(duration:0.5)){ p1=true } }
        }
        .onDisappear { on=false;c0=false;c1=false;c2=false;ch0=false;ch1=false;p0=false;p1=false }
    }
}

private struct OBTaskCard: View {
    let title: String; let pts: String
    let visible: Bool; let checked: Bool; let ptsUp: Bool
    var body: some View {
        ZStack(alignment:.topTrailing) {
            HStack(spacing:12) {
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(checked ? Color(hex:"#34D399") : Color(hex:"#5A5A6E"))
                    .font(.system(size:18)).animation(.spring(), value:checked)
                VStack(alignment:.leading,spacing:2) {
                    Text(title).font(.system(size:14,weight:.semibold)).foregroundColor(.white)
                    Text(pts+" AVEN Punkte").font(.system(size:12)).foregroundColor(Color(hex:"#9B5CFF"))
                }
                Spacer()
            }
            .padding(.horizontal,14).padding(.vertical,13)
            .background(Color(hex:"#16161F"))
            .clipShape(RoundedRectangle(cornerRadius:12))
            .overlay(RoundedRectangle(cornerRadius:12).stroke(
                checked ? Color(hex:"#34D399").opacity(0.35) : Color(hex:"#222234"), lineWidth:1))

            if ptsUp {
                Text(pts)
                    .font(.system(size:14,weight:.bold)).foregroundColor(Color(hex:"#34D399"))
                    .offset(x:-8,y:-22)
                    .transition(.asymmetric(insertion:.move(edge:.bottom).combined(with:.opacity),removal:.opacity))
            }
        }
        .scaleEffect(visible ? 1 : 0.88)
        .opacity(visible ? 1 : 0)
        .offset(x: visible ? 0 : 28)
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN 5 — GROWTH DASHBOARD
// Animated line chart + counting stat cards
// ══════════════════════════════════════════════════════════════════════════════

struct OBGrowthScreen: View {
    @State private var on = false
    @State private var lineP: CGFloat = 0
    @State private var f1 = 0; @State private var f2 = 0

    var body: some View {
        VStack(spacing:0) {
            Spacer()
            // Stat grid
            HStack(spacing:10) {
                OBGrowthStat(label:"FOLLOWER",value:"\(f1 < 12400 ? "\(f1/1000).\((f1%1000)/100)K" : "12.4K")",change:"↑ 8.2%",delay:0)
                OBGrowthStat(label:"ENGAGEMENT",value:"8.4%",change:"↑ 1.6%",delay:0.1)
                OBGrowthStat(label:"LIKES",value:"\(f2 < 840000 ? "\(f2/1000)K" : "840K")",change:"↑ 12%",delay:0.2)
            }
            .padding(.horizontal,28)
            .opacity(on ? 1 : 0).animation(.easeOut(duration:0.4).delay(0.1), value:on)

            Spacer().frame(height:14)

            // Chart card
            VStack(alignment:.leading,spacing:8) {
                Text("Score-Verlauf").font(.system(size:12,weight:.semibold)).foregroundColor(Color(hex:"#8E8EA0")).tracking(1)
                ZStack(alignment:.bottomLeading) {
                    OBGrowthPath(progress:lineP)
                        .stroke(LinearGradient(colors:[Color(hex:"#9B5CFF"),Color(hex:"#4F8FFF")],
                                               startPoint:.leading,endPoint:.trailing),
                                style:StrokeStyle(lineWidth:2.5,lineCap:.round))
                        .shadow(color:Color(hex:"#9B5CFF").opacity(0.45),radius:5)
                        .animation(.easeOut(duration:1.6).delay(0.3), value:lineP)
                }
                .frame(height:80).clipped()
            }
            .padding(14)
            .background(Color(hex:"#16161F")).clipShape(RoundedRectangle(cornerRadius:14))
            .padding(.horizontal,28)
            .opacity(on ? 1 : 0).animation(.easeOut(duration:0.4).delay(0.2), value:on)

            Spacer().frame(height:16)
            VStack(spacing:12) {
                Text("Verfolge dein Wachstum")
                    .font(.system(size:26,weight:.bold,design:.rounded)).foregroundColor(.white)
                    .opacity(on ? 1 : 0).offset(y: on ? 0 : 10)
                    .animation(.easeOut(duration:0.5).delay(0.15), value:on)
                Text("Follower, Views, Likes, Engagement und Score – alles im Blick.")
                    .font(.system(size:15)).foregroundColor(Color(hex:"#8E8EA0"))
                    .multilineTextAlignment(.center).padding(.horizontal,32)
                    .opacity(on ? 1 : 0).offset(y: on ? 0 : 6)
                    .animation(.easeOut(duration:0.5).delay(0.3), value:on)
            }
            Spacer()
        }
        .onAppear {
            on = true
            DispatchQueue.main.asyncAfter(deadline:.now()+0.4) {
                lineP = 1
                let steps = 60
                for i in 0...steps {
                    DispatchQueue.main.asyncAfter(deadline:.now()+Double(i)*(1.2/Double(steps))) {
                        f1 = Int(Double(i)/Double(steps)*12400)
                        f2 = Int(Double(i)/Double(steps)*840000)
                    }
                }
            }
        }
        .onDisappear { on=false; lineP=0; f1=0; f2=0 }
    }
}

private struct OBGrowthStat: View {
    let label:String; let value:String; let change:String; let delay:Double
    var body:some View {
        VStack(spacing:4) {
            Text(value).font(.system(size:16,weight:.bold)).foregroundColor(.white)
            Text(label).font(.system(size:9,weight:.semibold)).foregroundColor(Color(hex:"#8E8EA0")).tracking(1)
            Text(change).font(.system(size:11,weight:.semibold)).foregroundColor(Color(hex:"#34D399"))
        }
        .frame(maxWidth:.infinity).padding(.vertical,10)
        .background(Color(hex:"#16161F")).clipShape(RoundedRectangle(cornerRadius:10))
    }
}

private struct OBGrowthPath: Shape {
    var progress: CGFloat
    var animatableData: CGFloat { get { progress } set { progress = newValue } }
    func path(in rect: CGRect) -> Path {
        let pts: [CGFloat] = [0.9,0.82,0.88,0.75,0.68,0.70,0.58,0.55,0.42,0.38,0.30,0.22,0.15,0.10,0.05]
        var p = Path()
        let n = pts.count
        let w = rect.width; let h = rect.height
        p.move(to: CGPoint(x:0, y: h * pts[0]))
        for i in 1..<n {
            let x = w * CGFloat(i) / CGFloat(n-1)
            p.addLine(to: CGPoint(x:x, y: h * pts[i]))
        }
        return p
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN 6 — PREMIUM COMPLETION
// AVEN text hero + gradient ring + sparkles
// ══════════════════════════════════════════════════════════════════════════════

struct OBReadyScreen: View {
    let onComplete: () -> Void
    @State private var on = false
    @State private var ringOn = false
    @State private var glow = false
    @State private var pressing = false
    @State private var sparkA: [Double] = Array(repeating:0, count:8)
    @State private var sparkTask: Task<Void,Never>? = nil

    private let positions: [(CGFloat,CGFloat)] = [
        (0,-110),(78,-78),(110,0),(78,78),(0,110),(-78,78),(-110,0),(-78,-78)
    ]

    var body: some View {
        VStack(spacing:0) {
            Spacer()
            ZStack {
                // Glow orbs
                GlowOrb(color:Color(hex:"#9B5CFF"),size:240,opacity: glow ? 0.30 : 0.05)
                    .animation(.easeInOut(duration:2.0).repeatForever(autoreverses:true), value:glow)

                // Thin gradient ring
                Circle()
                    .trim(from:0, to: ringOn ? 1 : 0)
                    .stroke(LinearGradient(colors:[Color(hex:"#9B5CFF"),Color(hex:"#4F8FFF")],
                                           startPoint:.topLeading,endPoint:.bottomTrailing),
                            style:StrokeStyle(lineWidth:2,lineCap:.round))
                    .frame(width:160,height:160)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration:1.0).delay(0.2), value:ringOn)
                    .shadow(color:Color(hex:"#9B5CFF").opacity(0.4),radius:6)

                // AVEN text hero
                VStack(spacing:6) {
                    Text("AVEN")
                        .font(.system(size:60,weight:.black,design:.rounded))
                        .foregroundStyle(LinearGradient(colors:[Color(hex:"#B07AFF"),Color(hex:"#4F8FFF")],
                                                       startPoint:.topLeading,endPoint:.bottomTrailing))
                        .shadow(color:Color(hex:"#9B5CFF").opacity(0.7),radius:16)
                    Text("100 / 100").font(.system(size:13,weight:.bold)).foregroundColor(Color(hex:"#9B5CFF"))
                }
                .scaleEffect(on ? 1 : 0.65).opacity(on ? 1 : 0)
                .animation(.spring(response:0.6,dampingFraction:0.65).delay(0.1), value:on)

                // Orbit sparkles
                ForEach(0..<positions.count, id:\.self) { i in
                    Image(systemName: i%2==0 ? "sparkle" : "star.fill")
                        .font(.system(size:i%3==0 ? 11 : 8))
                        .foregroundColor(i%2==0 ? Color(hex:"#9B5CFF") : Color(hex:"#4F8FFF"))
                        .opacity(sparkA[i])
                        .offset(x:positions[i].0, y:positions[i].1)
                }
            }
            .frame(width:280,height:280)

            VStack(spacing:14) {
                Text("Bereit loszulegen?")
                    .font(.system(size:28,weight:.bold,design:.rounded)).foregroundColor(.white)
                    .opacity(on ? 1 : 0).offset(y: on ? 0 : 14)
                    .animation(.easeOut(duration:0.5).delay(0.35), value:on)
                Text("Dein nächster Schritt beginnt jetzt.\nStarte deine erste Analyse und verbessere dein Profil Schritt für Schritt.")
                    .font(.system(size:15)).foregroundColor(Color(hex:"#8E8EA0"))
                    .multilineTextAlignment(.center).lineSpacing(4).padding(.horizontal,32)
                    .opacity(on ? 1 : 0).offset(y: on ? 0 : 8)
                    .animation(.easeOut(duration:0.5).delay(0.5), value:on)
            }
            Spacer().frame(height:24)

            // Enhanced CTA
            Button {
                pressing = false
                onComplete()
            } label: {
                HStack(spacing:8) {
                    Image(systemName:"sparkles").font(.system(size:15,weight:.semibold))
                    Text("AVEN starten").font(.system(size:18,weight:.bold))
                    Image(systemName:"arrow.right")
                        .font(.system(size:15,weight:.semibold))
                        .offset(x: pressing ? 3 : 0)
                        .animation(.spring(response:0.3), value:pressing)
                }
                .foregroundColor(.white)
                .frame(maxWidth:.infinity).padding(.vertical,18)
                .background(LinearGradient(colors:[Color(hex:"#7B4FFF"),Color(hex:"#4F8FFF")],
                                           startPoint:.leading,endPoint:.trailing))
                .clipShape(RoundedRectangle(cornerRadius:16))
                .shadow(color:Color(hex:"#7B4FFF").opacity(0.55),radius:18,y:5)
                .scaleEffect(pressing ? 0.96 : 1.0)
                .animation(.spring(response:0.25), value:pressing)
            }
            .buttonStyle(.plain)
            .padding(.horizontal,24)
            .simultaneousGesture(DragGesture(minimumDistance:0)
                .onChanged { _ in pressing=true }
                .onEnded   { _ in pressing=false })
            .opacity(on ? 1 : 0).animation(.easeOut(duration:0.4).delay(0.65), value:on)

            Spacer().frame(height:44)
        }
        .onAppear {
            on=true; ringOn=true
            DispatchQueue.main.asyncAfter(deadline:.now()+0.3) { glow=true }
            sparkTask = Task {
                for i in 0..<positions.count {
                    try? await Task.sleep(nanoseconds: UInt64((0.4+Double(i)*0.09)*1e9))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeIn(duration:0.3)){ sparkA[i] = Double.random(in:0.5...1.0) }
                }
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_400_000_000)
                    guard !Task.isCancelled else { return }
                    for i in 0..<sparkA.count {
                        withAnimation(.easeInOut(duration:0.9)){ sparkA[i]=Double.random(in:0.15...0.85) }
                    }
                }
            }
        }
        .onDisappear {
            on=false; ringOn=false; glow=false; pressing=false
            sparkTask?.cancel(); sparkTask=nil; sparkA=Array(repeating:0,count:8)
        }
    }
}

#Preview {
    AVENOnboardingView(onComplete: {})
        .preferredColorScheme(.dark)
}
