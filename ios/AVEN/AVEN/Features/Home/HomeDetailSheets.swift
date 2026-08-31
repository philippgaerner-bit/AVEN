import SwiftUI

// ─── Score Detail Sheet ───────────────────────────────────────────────────────

struct ScoreDetailSheet: View {
    let score: AVENScore?          // kept for call-site compatibility; live data takes priority
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRange: HistoryRange = .month
    @State private var history: [ScoreHistoryEntry] = []
    @State private var hoveredEntry: ScoreHistoryEntry? = nil

    // Always read live score so a new analysis is instantly reflected
    private var liveScore: Int   { AVENAnalysisStore.currentScore }
    private var liveDims: [AnalysisDimension] {
        AVENAnalysisStore.load()?.dimensions ?? []
    }
    private var liveStatus: String {
        let s = liveScore
        if s >= 100 { return "Perfekt" }
        if s >= 90  { return "Hervorragend" }
        if s >= 80  { return "Stark" }
        if s >= 65  { return "Gut" }
        if s >= 50  { return "Ausbaufähig" }
        return "Verbesserungspotential"
    }

    enum HistoryRange: String, CaseIterable, Hashable {
        case week = "7T"; case month = "30T"; case quarter = "90T"; case year = "1J"
        var days: Int { switch self { case .week: 7; case .month: 30; case .quarter: 90; case .year: 365 } }
    }

    private var filteredHistory: [ScoreHistoryEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -selectedRange.days, to: Date()) ?? Date()
        return history.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
    }

    var body: some View {
        ZStack {
            AVENColor.backgroundPrimary.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: AVENSpacing.lg) {
                    Capsule().fill(AVENColor.borderSubtle).frame(width: 36, height: 4)
                        .padding(.top, AVENSpacing.sm)

                    AnimatedScoreArcView(targetScore: liveScore, size: 120)
                        .padding(.top, AVENSpacing.sm)

                    Text(liveStatus)
                        .font(AVENFont.display(22))
                        .foregroundStyle(LinearGradient(
                            colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                            startPoint: .leading, endPoint: .trailing))

                    // Live description from actual analysis record
                    if let rec = AVENAnalysisStore.load() {
                        Text("Analyse vom \(rec.timestamp.formatted(date: .abbreviated, time: .omitted)) · \(rec.weaknesses.isEmpty ? "Keine wesentlichen Schwächen erkannt." : "\(rec.weaknesses.count) Verbesserungsbereich\(rec.weaknesses.count == 1 ? "" : "e").")")
                            .font(AVENFont.body(13))
                            .foregroundColor(AVENColor.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AVENSpacing.lg)
                    }

                    // ── Score history chart ──────────────────────────────────
                    AVENCard(accentBorder: true) {
                        VStack(alignment: .leading, spacing: AVENSpacing.md) {
                            HStack {
                                Text("Score-Verlauf")
                                    .font(AVENFont.body(15, weight: .semibold))
                                    .foregroundColor(AVENColor.textPrimary)
                                Spacer()
                                // Range selector
                                HStack(spacing: 4) {
                                    ForEach(HistoryRange.allCases, id: \.self) { r in
                                        Button(r.rawValue) { selectedRange = r }
                                            .font(AVENFont.body(11, weight: selectedRange == r ? .bold : .regular))
                                            .foregroundColor(selectedRange == r ? AVENColor.accentPurple : AVENColor.textMuted)
                                            .padding(.horizontal, 8).padding(.vertical, 4)
                                            .background(selectedRange == r ? AVENColor.accentPurple.opacity(0.15) : Color.clear)
                                            .clipShape(Capsule())
                                    }
                                }
                            }

                            if filteredHistory.count >= 2 {
                                ScoreLineChart(entries: filteredHistory, hovered: $hoveredEntry)
                                    .frame(height: 140)

                                if let h = hoveredEntry {
                                    HStack(spacing: 8) {
                                        Text(h.date, style: .date)
                                            .font(AVENFont.body(12))
                                            .foregroundColor(AVENColor.textSecondary)
                                        Spacer()
                                        Text("Score: \(h.score)")
                                            .font(AVENFont.body(12, weight: .semibold))
                                            .foregroundColor(AVENColor.accentPurple)
                                    }
                                    if let reason = h.reason {
                                        Text(reason)
                                            .font(AVENFont.body(11))
                                            .foregroundColor(AVENColor.textMuted)
                                            .lineLimit(2)
                                    }
                                } else if let first = filteredHistory.first, let last = filteredHistory.last {
                                    let delta = last.score - first.score
                                    HStack {
                                        Text("\(filteredHistory.count) Analyse(n) in diesem Zeitraum")
                                            .font(AVENFont.body(12)).foregroundColor(AVENColor.textSecondary)
                                        Spacer()
                                        Text(delta >= 0 ? "+\(delta)" : "\(delta)")
                                            .font(AVENFont.body(12, weight: .semibold))
                                            .foregroundColor(delta >= 0 ? AVENColor.textPositive : AVENColor.textNegative)
                                    }
                                }
                            } else if filteredHistory.count == 1, let only = filteredHistory.first {
                                // Single data point — show it clearly
                                HStack(alignment: .center, spacing: 16) {
                                    VStack(spacing: 4) {
                                        Text("\(only.score)")
                                            .font(AVENFont.display(32))
                                            .foregroundStyle(LinearGradient(
                                                colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                                                startPoint: .leading, endPoint: .trailing))
                                        Text(only.date, style: .date)
                                            .font(AVENFont.body(12))
                                            .foregroundColor(AVENColor.textSecondary)
                                    }
                                    Spacer()
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Erste Analyse")
                                            .font(AVENFont.body(13, weight: .semibold))
                                            .foregroundColor(AVENColor.textPrimary)
                                        Text("Weitere Analysen zeigen deinen Score-Verlauf über die Zeit.")
                                            .font(AVENFont.body(12))
                                            .foregroundColor(AVENColor.textSecondary)
                                            .lineSpacing(2)
                                    }
                                }
                                .padding(.vertical, 4)
                                HStack(spacing: 10) {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .foregroundColor(AVENColor.accentPurple)
                                    Text("Nach der ersten Analyse siehst du hier deinen Score-Verlauf.")
                                        .font(AVENFont.body(13)).foregroundColor(AVENColor.textSecondary)
                                }
                            } else {
                                // No entries in this range but history exists in another range
                                HStack(spacing: 10) {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .foregroundColor(AVENColor.accentPurple)
                                    Text(history.isEmpty
                                         ? "Analysiere dein Profil, um den Score-Verlauf zu sehen."
                                         : "Keine Analysen in diesem Zeitraum. Wähle einen längeren Zeitraum.")
                                        .font(AVENFont.body(12)).foregroundColor(AVENColor.textSecondary)
                                }
                            }
                        }
                    }

                    // Dimension breakdown
                    let dims = liveDims
                    if !dims.isEmpty {
                        AVENCard(accentBorder: false) {
                            VStack(alignment: .leading, spacing: AVENSpacing.md) {
                                Text("Score-Aufschlüsselung")
                                    .font(AVENFont.body(15, weight: .semibold))
                                    .foregroundColor(AVENColor.textPrimary)
                                ForEach(dims, id: \.name) { dim in
                                    ScoreDimRow(dim: dim)
                                }
                            }
                        }

                        AVENCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Was du als Nächstes verbessern solltest")
                                    .font(AVENFont.body(15, weight: .semibold))
                                    .foregroundColor(AVENColor.textPrimary)
                                ForEach(Array(dims.filter { $0.score >= 0 }.sorted { $0.score < $1.score }.prefix(3)), id: \.name) { dim in
                                    ImproveTip(icon: "arrow.up.circle.fill", text: "\(dim.name): \(dim.tip)")
                                }
                            }
                        }
                    } else {
                        AVENCard {
                            HStack(spacing: 10) {
                                Image(systemName: "info.circle").foregroundColor(AVENColor.accentBlue)
                                Text("Starte eine Profil-Analyse, um eine detaillierte Score-Aufschlüsselung zu erhalten.")
                                    .font(AVENFont.body(13)).foregroundColor(AVENColor.textSecondary)
                            }
                        }
                    }

                    Button { dismiss() } label: {
                        Text("Schließen")
                            .font(AVENFont.body(15))
                            .foregroundColor(AVENColor.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(PressButtonStyle())
                    .padding(.bottom, AVENSpacing.lg)
                }
                .padding(.horizontal, AVENSpacing.md)
            }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(28)
        .onAppear { history = AVENAnalysisStore.loadHistory() }
        .onChange(of: liveScore) { _, _ in history = AVENAnalysisStore.loadHistory() }
    }
}

// ─── Interactive line chart ───────────────────────────────────────────────────

private struct ScoreLineChart: View {
    let entries: [ScoreHistoryEntry]
    @Binding var hovered: ScoreHistoryEntry?
    @State private var dragX: CGFloat? = nil

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let minS = entries.map(\.score).min() ?? 0
            let maxS = max((entries.map(\.score).max() ?? 100), minS + 1)
            let range = Double(maxS - minS)
            let xPos: (Int) -> CGFloat = { i in w * CGFloat(i) / CGFloat(max(entries.count - 1, 1)) }
            let yPos: (Int) -> CGFloat = { s in h - h * CGFloat(s - minS) / CGFloat(range) }

            ZStack(alignment: .topLeading) {
                // Grid lines
                ForEach([25, 50, 75, 100].filter { $0 >= minS && $0 <= maxS }, id: \.self) { v in
                    Path { p in
                        let yy = yPos(v)
                        p.move(to: CGPoint(x: 0, y: yy))
                        p.addLine(to: CGPoint(x: w, y: yy))
                    }
                    .stroke(AVENColor.borderSubtle, lineWidth: 0.5)
                }

                // Filled area
                Path { p in
                    guard entries.count >= 2 else { return }
                    p.move(to: CGPoint(x: xPos(0), y: h))
                    for (i, e) in entries.enumerated() { p.addLine(to: CGPoint(x: xPos(i), y: yPos(e.score))) }
                    p.addLine(to: CGPoint(x: xPos(entries.count - 1), y: h))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [AVENColor.accentPurple.opacity(0.25), AVENColor.accentPurple.opacity(0.02)],
                                     startPoint: .top, endPoint: .bottom))

                // Line
                Path { p in
                    guard entries.count >= 2 else { return }
                    p.move(to: CGPoint(x: xPos(0), y: yPos(entries[0].score)))
                    for (i, e) in entries.enumerated() { p.addLine(to: CGPoint(x: xPos(i), y: yPos(e.score))) }
                }
                .stroke(LinearGradient(colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                                        startPoint: .leading, endPoint: .trailing), lineWidth: 2)

                // Drag indicator
                if let dx = dragX {
                    let idx = Int((dx / w) * CGFloat(entries.count - 1)).clamped(to: 0...(entries.count-1))
                    let entry = entries[idx]
                    Group {
                        Rectangle()
                            .fill(AVENColor.accentPurple.opacity(0.3))
                            .frame(width: 1, height: h)
                            .position(x: xPos(idx), y: h/2)
                        Circle()
                            .fill(AVENColor.accentPurple)
                            .frame(width: 10, height: 10)
                            .position(x: xPos(idx), y: yPos(entry.score))
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { v in
                    dragX = v.location.x.clamped(to: 0...w)
                    let idx = Int((v.location.x / w) * CGFloat(entries.count - 1)).clamped(to: 0...(entries.count-1))
                    hovered = entries[idx]
                }
                .onEnded { _ in dragX = nil; hovered = nil }
            )
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self { min(max(self, range.lowerBound), range.upperBound) }
}

private struct ScoreDimRow: View {
    let dim: AnalysisDimension
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(dim.name).font(AVENFont.body(13, weight: .semibold)).foregroundColor(AVENColor.textPrimary)
                Spacer()
                if dim.score >= 0 {
                    Text("\(dim.score)/100").font(AVENFont.mono(12)).foregroundColor(AVENColor.accentPurpleLight)
                } else {
                    Text("–").font(AVENFont.mono(12)).foregroundColor(AVENColor.textMuted)
                }
            }
            if dim.score >= 0 {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(AVENColor.borderSubtle)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(LinearGradient(colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: g.size.width * CGFloat(dim.score) / 100)
                            .animation(AVENMotion.spring, value: dim.score)
                    }
                }
                .frame(height: 5)
            }
            Text(dim.score >= 0 ? (dim.negatives.first ?? dim.tip) : "Nicht aus Screenshot beurteilbar")
                .font(AVENFont.body(11)).foregroundColor(AVENColor.textMuted)
        }
    }
}

private struct ImproveTip: View {
    let icon: String; let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).font(.system(size: 14)).foregroundColor(AVENColor.accentPurple)
            Text(text).font(AVENFont.body(13)).foregroundColor(AVENColor.textSecondary).lineSpacing(3)
        }
    }
}

// ─── Metric Detail Sheet ──────────────────────────────────────────────────────

struct MetricDetailSheet: View {
    let metric: ProfileMetric
    @Environment(\.dismiss) private var dismiss

    // Mock history — real: load from analytics service
    private var history: [(String, Int)] {
        let base = Int(metric.value.replacingOccurrences(of: ".", with: "")
                           .replacingOccurrences(of: ",", with: "")
                           .replacingOccurrences(of: "K", with: "000")
                           .filter(\.isNumber)) ?? 1000
        return ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"].enumerated().map { i, d in
            let noise = Int.random(in: -Int(Double(base)*0.08)...Int(Double(base)*0.12))
            return (d, max(0, base + noise - Int(Double(base)*0.06)*(6-i)))
        }
    }

    var body: some View {
        ZStack {
            AVENColor.backgroundPrimary.ignoresSafeArea()
            VStack(spacing: AVENSpacing.lg) {
                Capsule().fill(AVENColor.borderSubtle).frame(width: 36, height: 4).padding(.top, AVENSpacing.sm)

                VStack(spacing: 4) {
                    Text(metric.label)
                        .font(AVENFont.body(14)).foregroundColor(AVENColor.textSecondary)
                    Text(metric.value)
                        .font(AVENFont.display(40)).foregroundColor(AVENColor.textPrimary)
                    AVENBadge(text: metric.change, positive: metric.isPositive)
                }
                .padding(.top, AVENSpacing.sm)

                AVENCard(accentBorder: true) {
                    VStack(alignment: .leading, spacing: AVENSpacing.sm) {
                        Text("7-Tage-Verlauf")
                            .font(AVENFont.body(14, weight: .semibold))
                            .foregroundColor(AVENColor.textPrimary)
                        // Mini bar chart
                        HStack(alignment: .bottom, spacing: 6) {
                            let maxVal = history.map(\.1).max() ?? 1
                            ForEach(history, id: \.0) { day, val in
                                VStack(spacing: 3) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(LinearGradient(
                                            colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                                            startPoint: .bottom, endPoint: .top))
                                        .frame(height: CGFloat(val) / CGFloat(maxVal) * 80)
                                    Text(day).font(AVENFont.body(9)).foregroundColor(AVENColor.textMuted)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(height: 100)
                        .padding(.top, 4)
                    }
                }

                AVENCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Was beeinflusst \(metric.label)?")
                            .font(AVENFont.body(14, weight: .semibold)).foregroundColor(AVENColor.textPrimary)
                        ImproveTip(icon: "arrow.up.circle.fill", text: positiveDriver)
                        ImproveTip(icon: "arrow.down.circle.fill", text: negativeDriver)
                    }
                }

                Spacer()
                Button { dismiss() } label: {
                    Text("Schließen")
                        .font(AVENFont.body(15)).foregroundColor(AVENColor.textSecondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                }
                .buttonStyle(PressButtonStyle())
                .padding(.bottom, AVENSpacing.lg)
            }
            .padding(.horizontal, AVENSpacing.md)
        }
        .presentationDetents([.large])
        .presentationCornerRadius(28)
    }

    private var positiveDriver: String {
        switch metric.label.lowercased() {
        case let s where s.contains("follower"): return "Stärkere Hooks und konsistentes Posting erhöhen Follower-Wachstum"
        case let s where s.contains("view"):     return "Gute Watch-Time und TikTok-Algorithmus-Signale pushen Views"
        case let s where s.contains("like"):     return "Emotional ansprechende Videos mit CTA erhöhen Likes"
        default:                                  return "Regelmäßiger, hochwertiger Content treibt diese Kennzahl"
        }
    }
    private var negativeDriver: String {
        switch metric.label.lowercased() {
        case let s where s.contains("follower"): return "Inkonsistentes Posting oder unklare Nische verlangsamt Wachstum"
        case let s where s.contains("view"):     return "Schwache Hooks in den ersten 2 Sek reduzieren View-Zahlen"
        case let s where s.contains("like"):     return "Zu langer Einstieg oder kein CTA senkt die Like-Rate"
        default:                                  return "Mangelnde Konsistenz oder Branding kann diese Zahl drücken"
        }
    }
}
