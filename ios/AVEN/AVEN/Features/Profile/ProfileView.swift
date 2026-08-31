import SwiftUI
import AuthenticationServices

// ─── ProfileView ──────────────────────────────────────────────────────────────

struct ProfileView: View {
    @StateObject private var vm = ProfileViewModel()
    @EnvironmentObject private var container: AppContainer
    @State private var appeared = false

    var body: some View {
        ZStack {
            AVENColor.backgroundPrimary.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: AVENSpacing.lg) {
                    Text("Profil")
                        .font(AVENFont.display(24))
                        .foregroundColor(AVENColor.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, AVENSpacing.sm)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : -8)
                        .animation(AVENMotion.spring.delay(0), value: appeared)

                    // Account card
                    ProfileAccountCard(vm: vm)
                        .cardAppear(delay: 0.06)

                    // Connected accounts
                    ProfileSection(title: "Verbundene Konten") {
                        SocialConnectRow(
                            platform: "TikTok",
                            icon: "music.note",
                            iconBg: Color.black,
                            connectionState: container.isTikTokConnected
                                ? .connected(username: container.connectedTikTokAccount?.username ?? "", accountId: container.connectedTikTokAccount?.openId ?? "")
                                : vm.tiktokState
                        ) {
                            // Open TikTokAccountView which has the working ASWebAuth OAuth flow
                            vm.showTikTokAccount = true
                        }
                          disconnectAction: {
                            container.disconnectTikTok()
                            vm.tiktokState = .disconnected
                          }
                    }
                    .cardAppear(delay: 0.1)

                    ProfileSection(title: "Einstellungen") {
                        SettingsRow(icon: "bell.fill",        label: "Benachrichtigungen") { vm.showNotifications = true }
                        SettingsRow(icon: "creditcard.fill",  label: "Abonnement verwalten") { vm.showPaywall = true }
                        SettingsRow(icon: "gear",             label: "Einstellungen")       { vm.showSettings = true }
                    }
                    .cardAppear(delay: 0.14)



                    ProfileSection(title: "Support") {
                        SettingsRow(icon: "questionmark.circle.fill", label: "Hilfe & Support") { vm.showHelp = true }
                        SettingsRow(icon: "shield.fill",               label: "Datenschutz")    { vm.showPrivacy = true }
                        SettingsRow(icon: "doc.text.fill",             label: "AGB")            { vm.showTerms = true }
                    }
                    .cardAppear(delay: 0.18)

                    Text("AVEN v0.1.0 – Preview Build")
                        .font(AVENFont.body(12))
                        .foregroundColor(AVENColor.textMuted)
                        .padding(.vertical, AVENSpacing.md)
                        .opacity(appeared ? 1 : 0)
                        .animation(AVENMotion.spring.delay(0.22), value: appeared)

                    Spacer(minLength: AVENSpacing.xxl)
                }
                .padding(.horizontal, AVENSpacing.md)
            }
        }
        .onAppear { withAnimation { appeared = true } }
        .sheet(isPresented: $vm.showPaywall)         { PaywallView() }
        .confirmationDialog("Account wirklich löschen?",
                            isPresented: $vm.showDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Account löschen", role: .destructive) {
                container.authService.logout()
                    UserDefaults.standard.removeObject(forKey: "aven.coach.chatHistory")
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Dein Account wird gelöscht. AVEN Score, Analysen und Abo-Status bleiben unberührt.")
        }
        .sheet(isPresented: $vm.showTikTokAccount) {
            TikTokAccountView(onNewAnalysis: {
                // MARK: trigger new scan from account page
            })
        }
        .sheet(isPresented: $vm.showTikTokConnect)   { TikTokConnectSheet(vm: vm) }
        .sheet(isPresented: $vm.showNotifications)   { NotificationsSettingsSheet() }
        .sheet(isPresented: $vm.showSettings)        { AppSettingsSheet() }
        .sheet(isPresented: $vm.showHelp)            { HelpSheet() }
        .sheet(isPresented: $vm.showPrivacy)         { PrivacySheet() }
        .sheet(isPresented: $vm.showTerms)           { TermsSheet() }
        .alert("Fehler", isPresented: $vm.showErrorAlert) {
            Button("OK", role: .cancel) { vm.clearError() }
        } message: {
            Text(vm.errorMessage)
        }
    }
}

// ─── Account card ─────────────────────────────────────────────────────────────

private struct ProfileAccountCard: View {
    @ObservedObject var vm: ProfileViewModel
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        AVENCard(accentBorder: true) {
            VStack(spacing: AVENSpacing.md) {
                if let tiktok = container.connectedTikTokAccount {
                    // Real connected account
                    TikTokAvatarView(
                        displayName: tiktok.displayName,
                        avatarUrl:   tiktok.avatarUrl,
                        size:        72,
                        ringColor:   AVENColor.accentPurple
                    )
                    VStack(spacing: 4) {
                        Text(tiktok.displayName)
                            .font(AVENFont.body(17, weight: .semibold))
                            .foregroundColor(AVENColor.textPrimary)
                        Text(tiktok.username)
                            .font(AVENFont.body(13))
                            .foregroundColor(AVENColor.textSecondary)
                    }
                    HStack(spacing: AVENSpacing.lg) {
                        ProfileStat(value: formatCount(tiktok.followers), label: "Follower")
                        ProfileStat(value: formatCount(tiktok.following), label: "Folge ich")
                        ProfileStat(value: formatCount(tiktok.likes),     label: "Likes")
                    }
                } else {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [AVENColor.accentPurple.opacity(0.3), AVENColor.accentBlue.opacity(0.2)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 72, height: 72)
                    Image(systemName: "person.fill")
                        .font(.system(size: 32))
                        .foregroundColor(AVENColor.accentPurple)
                }
                VStack(spacing: 4) {
                    Text("Anonymes Konto")
                        .font(AVENFont.body(17, weight: .semibold))
                        .foregroundColor(AVENColor.textPrimary)
                    Text("Kein Account verbunden")
                        .font(AVENFont.body(13))
                        .foregroundColor(AVENColor.textSecondary)
                }
                Button { vm.showPaywall = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill").font(.system(size: 14))
                        Text("Auf PRO upgraden").font(AVENFont.body(15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(LinearGradient(
                        colors: [AVENColor.accentGradientStart, AVENColor.accentGradientEnd],
                        startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: AVENRadius.md))
                    .foregroundColor(.white)
                    .avGlow(color: AVENColor.accentPurple, radius: 12, breathes: true)
                }
                .buttonStyle(PressButtonStyle())
                }  // end else (not connected)
            }
            .frame(maxWidth: .infinity)
            .padding(AVENSpacing.sm)
        }
    }

    private func formatCount(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n)/1_000_000) }
        if n >= 1_000     { return String(format: "%.1fK", Double(n)/1_000) }
        return "\(n)"
    }
}

// ─── Profile stat pill ────────────────────────────────────────────────────────

private struct ProfileStat: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(AVENFont.body(15, weight: .semibold)).foregroundColor(AVENColor.textPrimary)
            Text(label).font(AVENFont.body(11)).foregroundColor(AVENColor.textSecondary)
        }.frame(maxWidth: .infinity)
    }
}

// ─── Section ──────────────────────────────────────────────────────────────────

private struct ProfileSection<Content: View>: View {
    let title:   String
    let content: Content
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(AVENFont.body(11, weight: .semibold))
                .foregroundColor(AVENColor.textMuted)
                .padding(.leading, 4).padding(.bottom, 4)
            VStack(spacing: 1) { content }
                .clipShape(RoundedRectangle(cornerRadius: AVENRadius.md))
        }
    }
}

// ─── Social connect row ───────────────────────────────────────────────────────

private struct SocialConnectRow: View {
    let platform:         String
    let icon:             String
    let iconBg:           Color
    let connectionState:  TikTokConnectionState
    let connectAction:    () -> Void
    let disconnectAction: () -> Void
    @State private var showManageSheet = false

    init(platform: String, icon: String, iconBg: Color,
         connectionState: TikTokConnectionState,
         connectAction: @escaping () -> Void,
         disconnectAction: @escaping () -> Void) {
        self.platform         = platform
        self.icon             = icon
        self.iconBg           = iconBg
        self.connectionState  = connectionState
        self.connectAction    = connectAction
        self.disconnectAction = disconnectAction
    }

    private var isConnected: Bool {
        if case .connected = connectionState { return true }
        return false
    }
    private var isConnecting: Bool { connectionState == .connecting }
    private var isUnconfigured: Bool { connectionState == .unconfigured }
    private var username: String? {
        if case .connected(let u, _) = connectionState { return u }
        return nil
    }

    var body: some View {
        Button(action: {
            if isConnected { showManageSheet = true }
            else           { connectAction() }
        }) {
            HStack(spacing: AVENSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconBg).frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold)).foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(platform)
                        .font(AVENFont.body(15, weight: .semibold)).foregroundColor(AVENColor.textPrimary)
                    if let u = username {
                        Text(u).font(AVENFont.body(12)).foregroundColor(AVENColor.textSecondary)
                    } else {
                        Text(isConnected ? "Verbunden" : "Nicht verbunden")
                            .font(AVENFont.body(12))
                            .foregroundColor(isConnected ? AVENColor.textPositive : AVENColor.textMuted)
                    }
                }
                Spacer()
                if isConnecting {
                    ProgressView().tint(AVENColor.accentPurple).scaleEffect(0.8)
                } else if isConnected {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14)).foregroundColor(AVENColor.textPositive)
                        Text("Verwalten")
                            .font(AVENFont.body(12, weight: .semibold)).foregroundColor(AVENColor.textPositive)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11)).foregroundColor(AVENColor.textMuted)
                    }
                } else if isUnconfigured {
                    HStack(spacing: 4) {
                        Image(systemName: "wrench.adjustable")
                            .font(.system(size: 12)).foregroundColor(AVENColor.textSecondary)
                        Text("Setup").font(AVENFont.body(12, weight: .semibold)).foregroundColor(AVENColor.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11)).foregroundColor(AVENColor.textMuted)
                    }
                } else {
                    HStack(spacing: 4) {
                        Text("TikTok verbinden")
                            .font(AVENFont.body(13, weight: .semibold)).foregroundColor(AVENColor.accentPurple)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11)).foregroundColor(AVENColor.accentPurple.opacity(0.6))
                    }
                }
            }
            .padding(AVENSpacing.md)
            .background(AVENColor.backgroundCard)
            .animation(AVENMotion.spring, value: isConnected)
        }
        .buttonStyle(PressButtonStyle())
        .confirmationDialog("TikTok Account verwalten",
                            isPresented: $showManageSheet,
                            titleVisibility: .visible) {
            Button("Account trennen", role: .destructive) { disconnectAction() }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Den verbundenen TikTok-Account entfernen?\nAVEN Score, Analysen und Verlauf bleiben erhalten.")
        }
    }
}

// ─── TikTok connect sheet ─────────────────────────────────────────────────────

struct TikTokConnectSheet: View {
    @ObservedObject var vm: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false

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
                        Image(systemName: "music.note")
                            .font(.system(size: 36))
                            .foregroundStyle(LinearGradient(
                                colors: [AVENColor.accentPurple, AVENColor.accentBlue],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                    .scaleEffect(appeared ? 1 : 0.7)
                    .animation(AVENMotion.spring.delay(0.05), value: appeared)

                    Text("TikTok verbinden")
                        .font(AVENFont.display(24)).foregroundColor(AVENColor.textPrimary)
                        .opacity(appeared ? 1 : 0)
                        .animation(AVENMotion.spring.delay(0.1), value: appeared)

                    Text("Verbinde deinen TikTok-Account, damit AVEN dein Profil analysieren und personalisierte Wachstums-Insights erstellen kann.")
                        .font(AVENFont.body(15)).foregroundColor(AVENColor.textSecondary)
                        .multilineTextAlignment(.center).lineSpacing(4)
                        .padding(.horizontal, AVENSpacing.lg)
                        .opacity(appeared ? 1 : 0)
                        .animation(AVENMotion.spring.delay(0.15), value: appeared)

                    // Configuration status
                    ConfigStatusBadge()
                        .opacity(appeared ? 1 : 0)
                        .animation(AVENMotion.spring.delay(0.2), value: appeared)
                }

                Spacer()

                VStack(spacing: AVENSpacing.sm) {
                    AVENPrimaryButton(title: "Mit TikTok verbinden", icon: "music.note") {
                        dismiss()
                        vm.connectTikTok()
                    }
                    Button { dismiss() } label: {
                        Text("Abbrechen")
                            .font(AVENFont.body(15)).foregroundColor(AVENColor.textSecondary)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                    }
                    .buttonStyle(PressButtonStyle())
                }
                .padding(.horizontal, AVENSpacing.md).padding(.bottom, AVENSpacing.lg)
            }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(28)
        .onAppear { withAnimation { appeared = true } }
    }
}

private struct ConfigStatusBadge: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundColor(AVENColor.accentBlue)
                .font(.system(size: 13))
            Text("Öffnet TikTok-Anmeldung im Browser")
                .font(AVENFont.body(13))
                .foregroundColor(AVENColor.textSecondary)
        }
        .padding(.horizontal, AVENSpacing.md)
        .padding(.vertical, 10)
        .background(AVENColor.backgroundElevated)
        .clipShape(RoundedRectangle(cornerRadius: AVENRadius.md))
        .overlay(RoundedRectangle(cornerRadius: AVENRadius.md)
            .strokeBorder(AVENColor.borderSubtle, lineWidth: 1))
    }
}

// ─── Settings row ─────────────────────────────────────────────────────────────

private struct SettingsRow: View {
    let icon: String; let label: String; var tint: Color = AVENColor.accentPurple; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: AVENSpacing.md) {
                Image(systemName: icon).font(.system(size: 15))
                    .foregroundColor(tint).frame(width: 22)
                Text(label).font(AVENFont.body(15)).foregroundColor(tint == AVENColor.accentPurple ? AVENColor.textPrimary : tint)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(AVENColor.textMuted)
            }
            .padding(AVENSpacing.md)
            .background(AVENColor.backgroundCard)
        }
        .buttonStyle(PressButtonStyle())
    }
}

// ─── Placeholder sheet ────────────────────────────────────────────────────────

// ─── Settings sheets (replace Kommt-bald placeholders) ───────────────────────

private struct NotificationsSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("aven.notif.analysis")  private var notifAnalysis  = true
    @AppStorage("aven.notif.tips")      private var notifTips      = true
    @AppStorage("aven.notif.weekly")    private var notifWeekly    = false

    var body: some View {
        SheetChrome(title: "Benachrichtigungen", icon: "bell.fill") {
            AVENCard {
                VStack(spacing: 0) {
                    ToggleRow(label: "Analyse-Erinnerungen", sublabel: "Erinnert dich, neue Screenshots hochzuladen", isOn: $notifAnalysis)
                    Divider().background(AVENColor.borderSubtle)
                    ToggleRow(label: "Wachstums-Tipps", sublabel: "Tägliche Tipps zu Bio, Hooks und Content", isOn: $notifTips)
                    Divider().background(AVENColor.borderSubtle)
                    ToggleRow(label: "Wöchentliche Zusammenfassung", sublabel: "Score-Entwicklung und Fortschritt", isOn: $notifWeekly)
                }
            }
        }
    }
}

private struct AppSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("aven.settings.haptic")  private var hapticOn   = true
    @AppStorage("aven.settings.reduced") private var reducedUI  = false

    var body: some View {
        SheetChrome(title: "Einstellungen", icon: "gear") {
            VStack(spacing: AVENSpacing.sm) {
                AVENCard {
                    VStack(spacing: 0) {
                        ToggleRow(label: "Haptisches Feedback", sublabel: "Vibration bei Aktionen", isOn: $hapticOn)
                        Divider().background(AVENColor.borderSubtle)
                        ToggleRow(label: "Animationen reduzieren", sublabel: "Weniger Bewegungseffekte", isOn: $reducedUI)
                    }
                }
                AVENCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Version").font(AVENFont.body(14)).foregroundColor(AVENColor.textPrimary)
                        Text("AVEN 1.0 (Beta)").font(AVENFont.body(13)).foregroundColor(AVENColor.textSecondary)
                    }
                }
            }
        }
    }
}

private struct HelpSheet: View {
    private let faqs: [(String, String)] = [
        ("Was ist der AVEN Score?", "Der AVEN Score (0–100) bewertet dein TikTok-Profil anhand von Bio, Positionierung, Content-Klarheit und mehr. Je höher der Score, desto klarer und reichweitenstärker ist dein Profil aufgestellt."),
        ("Wie verbessere ich meinen Score?", "Erledige die Aufgaben im Aktionsplan – jede abgeschlossene Aufgabe bringt Punkte. Lade Nachweise hoch, damit AVEN deinen Fortschritt erkennt."),
        ("Was ist ein Hook?", "Ein Hook ist der Einstieg deines Videos (erste 1–2 Sekunden). Er entscheidet, ob jemand weiterschaut. Gute Hooks starten mit einer Frage, einem Widerspruch oder einer überraschenden Aussage."),
        ("Was ist ein CTA?", "CTA steht für Call to Action – eine Handlungsaufforderung. Beispiel in der Bio: \"→ Guide unten\" oder im Video: \"Folge mir für mehr Tipps\"."),
        ("Wie verbinde ich TikTok?", "Gehe zum Profil-Tab → Verbundene Konten → TikTok verbinden. Du wirst zur offiziellen TikTok-Anmeldeseite weitergeleitet."),
    ]

    var body: some View {
        SheetChrome(title: "Hilfe & Support", icon: "questionmark.circle.fill") {
            VStack(spacing: AVENSpacing.sm) {
                ForEach(faqs, id: \.0) { q, a in
                    AVENCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(q).font(AVENFont.body(14, weight: .semibold)).foregroundColor(AVENColor.textPrimary)
                            Text(a).font(AVENFont.body(13)).foregroundColor(AVENColor.textSecondary).lineSpacing(3)
                        }
                    }
                }
                AVENCard {
                    HStack(spacing: 12) {
                        Image(systemName: "envelope.fill").foregroundColor(AVENColor.accentPurple)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Kontakt").font(AVENFont.body(14, weight: .semibold)).foregroundColor(AVENColor.textPrimary)
                            Text("support@avencreator.app").font(AVENFont.body(13)).foregroundColor(AVENColor.textSecondary)
                        }
                        Spacer()
                    }
                }
            }
        }
    }
}

private struct PrivacySheet: View {
    var body: some View {
        SheetChrome(title: "Datenschutz", icon: "shield.fill") {
            VStack(spacing: AVENSpacing.sm) {
                ForEach([
                    ("Was wir speichern", "AVEN speichert deinen AVEN Score, deinen Aktionsplan-Fortschritt und deine App-Einstellungen lokal auf deinem Gerät. Hochgeladene Screenshots werden nur zur Analyse verwendet und nicht dauerhaft gespeichert."),
                    ("TikTok-Verbindung", "Wenn du deinen TikTok-Account verbindest, werden öffentliche Profildaten (Username, Follower, Likes) abgerufen. AVEN speichert niemals dein TikTok-Passwort."),
                    ("Deine Rechte", "Du kannst jederzeit alle gespeicherten Daten löschen, indem du die App deinstallierst oder dein Konto unter Einstellungen löschst. Bei Fragen: support@avencreator.app"),
                ], id: \.0) { title, text in
                    AVENCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(title).font(AVENFont.body(14, weight: .semibold)).foregroundColor(AVENColor.textPrimary)
                            Text(text).font(AVENFont.body(13)).foregroundColor(AVENColor.textSecondary).lineSpacing(3)
                        }
                    }
                }
            }
        }
    }
}

private struct TermsSheet: View {
    var body: some View {
        SheetChrome(title: "AGB", icon: "doc.text.fill") {
            VStack(spacing: AVENSpacing.sm) {
                ForEach([
                    ("Nutzung", "AVEN ist ein Analyse- und Optimierungstool für Social-Media-Creator. Die Nutzung erfolgt auf eigene Verantwortung."),
                    ("Inhalte", "Hochgeladene Screenshots dürfen nur eigene oder rechtlich erlaubte Inhalte zeigen. AVEN übernimmt keine Haftung für die Richtigkeit der Analyseergebnisse."),
                    ("Abonnement", "Pro- und Pro+-Abonnements werden über den App Store abgerechnet und können jederzeit im App Store gekündigt werden."),
                    ("Haftung", "AVEN GmbH haftet nicht für Umsatz- oder Reichweitenverluste, die im Zusammenhang mit der Nutzung der App entstehen."),
                    ("Änderungen", "AVEN behält sich vor, diese Bedingungen mit angemessener Vorankündigung zu ändern. Die aktuelle Version ist immer in der App abrufbar."),
                ], id: \.0) { title, text in
                    AVENCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(title).font(AVENFont.body(14, weight: .semibold)).foregroundColor(AVENColor.textPrimary)
                            Text(text).font(AVENFont.body(13)).foregroundColor(AVENColor.textSecondary).lineSpacing(3)
                        }
                    }
                }
            }
        }
    }
}

// ─── Shared chrome for content sheets ────────────────────────────────────────

private struct SheetChrome<Content: View>: View {
    let title:   String
    let icon:    String
    @ViewBuilder let content: () -> Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AVENColor.backgroundPrimary.ignoresSafeArea()
            VStack(spacing: 0) {
                Capsule().fill(AVENColor.borderSubtle).frame(width: 36, height: 4)
                    .padding(.top, AVENSpacing.sm).padding(.bottom, AVENSpacing.md)
                HStack {
                    Image(systemName: icon).font(.system(size: 18)).foregroundColor(AVENColor.accentPurple)
                    Text(title).font(AVENFont.display(20)).foregroundColor(AVENColor.textPrimary)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 24)).foregroundColor(AVENColor.textMuted)
                    }.buttonStyle(PressButtonStyle())
                }
                .padding(.horizontal, AVENSpacing.md).padding(.bottom, AVENSpacing.md)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AVENSpacing.sm) { content() }
                        .padding(.horizontal, AVENSpacing.md)
                        .padding(.bottom, AVENSpacing.xxl)
                }
            }
        }
        .presentationDetents([.medium, .large]).presentationCornerRadius(28)
    }
}

private struct ToggleRow: View {
    let label:    String
    let sublabel: String
    @Binding var isOn: Bool
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(AVENFont.body(14)).foregroundColor(AVENColor.textPrimary)
                Text(sublabel).font(AVENFont.body(12)).foregroundColor(AVENColor.textSecondary)
            }
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden().tint(AVENColor.accentPurple)
        }
        .padding(.vertical, 6)
    }
}

// ─── ViewModel ────────────────────────────────────────────────────────────────

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var tiktokState: TikTokConnectionState = .disconnected

    @Published var showPaywall          = false
    @Published var showTikTokAccount    = false
    @Published var showTikTokConnect    = false
    @Published var showNotifications    = false
    @Published var showSettings         = false
    @Published var showHelp             = false
    @Published var showPrivacy          = false
    @Published var showTerms            = false
    @Published var showDeleteConfirm    = false
    @Published var showErrorAlert       = false
    @Published var errorMessage         = ""

    private let oauthService = TikTokOAuthService()

    // MARK: - Integration Point: provide real token and profileId from your auth system
    private var currentToken     = "dev-token"         // replace with real session token
    private var currentProfileId = "dev-profile-id"    // replace with real profile ID

    func connectTikTok(onSuccess: ((ConnectedTikTokAccount) -> Void)? = nil) {
        showTikTokConnect = false

        // Check synchronously if backend is even configured before spinning
        if !oauthService.isBackendConfigured() {
            withAnimation(AVENMotion.spring) {
                tiktokState = .unconfigured
            }
            errorMessage   = TikTokOAuthError.backendNotConfigured.userMessage
            showErrorAlert = true
            return
        }

        tiktokState = .connecting
        Task {
            let result = await oauthService.connect(profileId: currentProfileId, token: currentToken)
            withAnimation(AVENMotion.spring) {
                tiktokState = result
            }
            if case .connected(let username, let accountId) = result {
                // Write to AppContainer so Home and all screens update immediately
                let account = ConnectedTikTokAccount(
                    openId:      accountId,
                    username:    username.hasPrefix("@") ? username : "@\(username)",
                    displayName: username,
                    avatarUrl:   nil,
                    followers:   0,
                    following:   0,
                    likes:       0,
                    videoCount:  0
                )
                onSuccess?(account)
            }
            if case .error(let err) = result, err != .userCancelled {
                errorMessage   = err.userMessage
                showErrorAlert = true
            }
            if case .unconfigured = result {
                errorMessage   = TikTokOAuthError.backendNotConfigured.userMessage
                showErrorAlert = true
            }
        }
    }

    func disconnectTikTok() {
        withAnimation(AVENMotion.spring) {
            tiktokState = .disconnected
        }
        // MARK: - Integration Point: call DELETE /social/accounts/:id on backend
    }

    func clearError() {
        errorMessage   = ""
        showErrorAlert = false
        switch tiktokState {
        case .error, .unconfigured:
            tiktokState = .disconnected
        default:
            break
        }
    }
}

#Preview { ProfileView() }
