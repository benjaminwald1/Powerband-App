import SwiftUI

private enum Legal {
    static let privacy = URL(string: "https://powerband.fit/privacy/")!
    static let terms = URL(string: "https://powerband.fit/terms/")!
    static let support = URL(string: "mailto:Benjaminwald11@gmail.com?subject=PowerBand%20support")!
}

private struct Row<Trailing: View>: View {
    let title: String
    var tint: Color = .white
    @ViewBuilder var trailing: Trailing
    var body: some View {
        HStack { Text(title).font(.system(size: 14, weight: .medium)).foregroundStyle(tint); Spacer(); trailing }.padding(.vertical, 11)
    }
}

private struct Rows<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { VStack(spacing: 0) { content }.card() }
}

private var divider: some View { Divider().overlay(Color.white.opacity(0.07)) }

// MARK: Account tab

struct AccountView: View {
    @Environment(Store.self) private var store
    @Environment(Account.self) private var account
    @Environment(SensorManager.self) private var sensor
    @AppStorage("useMph") private var useMph = true
    @AppStorage("dailyGoal") private var goal = 200
    @AppStorage("hapticsOn") private var hapticsOn = true
    @AppStorage("voiceOn") private var voiceOn = false
    @State private var editing = false
    @State private var confirmSignOut = false
    @State private var confirmClear = false
    @State private var deleting = false

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "PowerBand \(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            Screen {
                ScreenHeader(kicker: "Signed in on this phone", title: "Account")

                if let p = account.profile {
                    HStack(spacing: 14) {
                        Text(p.initial).font(.num(30)).foregroundStyle(.black).frame(width: 60, height: 60)
                            .background(LinearGradient(colors: [Theme.volt, Theme.green], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(p.name).font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                            Text(p.email.isEmpty ? "No email added" : p.email).font(.system(size: 13)).foregroundStyle(Theme.muted)
                            Text("Member since \(p.createdAt.formatted(.dateTime.month(.wide).year()))").font(.system(size: 11)).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Button("Edit") { editing = true }.font(.system(size: 13, weight: .semibold)).buttonStyle(.bordered).tint(Theme.green)
                    }
                    .card()
                }

                HStack(spacing: 10) {
                    StatTile(label: "Shots", value: store.totalShots.formatted())
                    StatTile(label: "Sessions", value: "\(store.sessions.count)", progressColor: Theme.blue)
                    StatTile(label: "Streak", value: "\(store.streak)", unit: "d", subColor: Theme.volt)
                }
                .fixedSize(horizontal: false, vertical: true)

                SectionLabel("PREFERENCES")
                VStack(spacing: 0) {
                    HStack { Text("Speed units").font(.system(size: 14, weight: .medium)).foregroundStyle(.white); Spacer()
                        Picker("Units", selection: $useMph) { Text("mph").tag(true); Text("km/h").tag(false) }.pickerStyle(.segmented).frame(width: 140) }.padding(.vertical, 8)
                    divider
                    Stepper(value: $goal, in: 50...1000, step: 25) { Text("Daily goal: \(goal) shots").font(.system(size: 14, weight: .medium)).foregroundStyle(.white) }.padding(.vertical, 8)
                    divider
                    Toggle("Haptic tap on every shot", isOn: $hapticsOn).font(.system(size: 14, weight: .medium)).tint(Theme.green).padding(.vertical, 8)
                    divider
                    Toggle("Speak swing speed aloud", isOn: $voiceOn).font(.system(size: 14, weight: .medium)).tint(Theme.green).padding(.vertical, 8)
                }
                .card()

                SectionLabel("YOUR DATA")
                Rows {
                    ShareLink(item: store.csv(), subject: Text("PowerBand shots"), message: Text("PowerBand export")) {
                        Row(title: "Export all shots (CSV)") { Image(systemName: "square.and.arrow.up").foregroundStyle(Theme.muted) }
                    }
                    divider
                    NavigationLink { ProfileView() } label: { Row(title: "Achievements") { Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(Theme.muted) } }
                    divider
                    Button { store.loadDemoData() } label: { Row(title: "Load demo history") {} }
                    divider
                    Button { confirmClear = true } label: { Row(title: "Delete all sessions", tint: Theme.red) {} }
                }
                Text("Your sessions are stored only on this phone. PowerBand never uploads, sells or shares them.").font(.system(size: 11)).foregroundStyle(Theme.muted)

                SectionLabel("HELP & LEGAL")
                Rows {
                    Link(destination: Legal.privacy) { Row(title: "Privacy Policy") { Image(systemName: "arrow.up.right").font(.system(size: 12)).foregroundStyle(Theme.muted) } }
                    divider
                    Link(destination: Legal.terms) { Row(title: "Terms of Service") { Image(systemName: "arrow.up.right").font(.system(size: 12)).foregroundStyle(Theme.muted) } }
                    divider
                    Link(destination: Legal.support) { Row(title: "Contact support") { Image(systemName: "envelope").font(.system(size: 12)).foregroundStyle(Theme.muted) } }
                }

                SectionLabel("ACCOUNT")
                Rows {
                    Button { confirmSignOut = true } label: { Row(title: "Sign out") { Image(systemName: "rectangle.portrait.and.arrow.right").foregroundStyle(Theme.muted) } }
                    divider
                    Button { deleting = true } label: { Row(title: "Delete account", tint: Theme.red) { Image(systemName: "trash").foregroundStyle(Theme.red) } }
                }

                Text(version).font(.system(size: 11)).foregroundStyle(Theme.muted).frame(maxWidth: .infinity).padding(.top, 8)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $editing) { EditProfileView() }
            .sheet(isPresented: $deleting) { DeleteAccountView() }
            .confirmationDialog("Sign out of PowerBand?", isPresented: $confirmSignOut, titleVisibility: .visible) {
                Button("Sign out", role: .destructive) { account.signOut() }
            } message: { Text("Your sessions stay on this phone and are here when you sign back in.") }
            .confirmationDialog("Delete every session on this phone?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Delete all sessions", role: .destructive) { store.deleteAll() }
            } message: { Text("This can't be undone. Your account and settings are kept.") }
        }
    }
}

struct EditProfileView: View {
    @Environment(Account.self) private var account
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") { TextField("Your name", text: $name).textContentType(.name) }
                Section { TextField("Email (optional)", text: $email).textContentType(.emailAddress).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled() } header: { Text("Email") } footer: { Text("Only stored on this phone. It's used to pre-fill support emails.") }
            }
            .scrollContentBackground(.hidden).background(Theme.bg)
            .navigationTitle("Edit profile").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { account.update(name: name, email: email); dismiss() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty) }
            }
            .onAppear { name = account.profile?.name ?? ""; email = account.profile?.email ?? "" }
        }
        .presentationDetents([.medium])
    }
}

struct DeleteAccountView: View {
    @Environment(Store.self) private var store
    @Environment(Account.self) private var account
    @Environment(SensorManager.self) private var sensor
    @Environment(\.dismiss) private var dismiss
    @State private var typed = ""

    var body: some View {
        NavigationStack {
            Screen {
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 34)).foregroundStyle(Theme.red).frame(maxWidth: .infinity)
                Text("Delete your account?").font(.num(30)).foregroundStyle(.white).frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 8) {
                    Text("This permanently removes from this phone:").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                    ForEach(["Your profile (name and email)", "All \(store.totalShots.formatted()) shots across \(store.sessions.count) sessions", "Your goals, units and other settings", "The connection to your paired sensor"], id: \.self) { t in
                        Label(t, systemImage: "minus.circle.fill").font(.system(size: 13)).foregroundStyle(Color(hex: 0xB6BEC4)).labelStyle(.titleAndIcon)
                    }
                    Text("There is nothing to recover afterwards: PowerBand doesn't keep a copy on any server. Export your shots first if you want to keep them.").font(.system(size: 12)).foregroundStyle(Theme.muted)
                }
                .card()
                VStack(alignment: .leading, spacing: 8) {
                    Kicker("Type DELETE to confirm")
                    TextField("DELETE", text: $typed).textInputAutocapitalization(.characters).autocorrectionDisabled()
                        .padding(12).background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                }
                Button(role: .destructive) { dismiss(); account.deleteAccount(store: store, sensor: sensor) } label: {
                    Text("Delete my account").font(.system(size: 16, weight: .bold)).frame(maxWidth: .infinity).padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent).tint(Theme.red).foregroundStyle(.black).disabled(typed.uppercased() != "DELETE")
                Button("Cancel") { dismiss() }.frame(maxWidth: .infinity).foregroundStyle(Theme.muted)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: Sign-in and profile creation

struct CreateProfileView: View {
    @Environment(Account.self) private var account
    @State private var name = ""
    @State private var email = ""

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer(minLength: 20)
                Text("P").font(.system(size: 54, weight: .heavy).italic()).foregroundStyle(.white)
                Text("Create your profile").font(.num(36)).foregroundStyle(.white)
                Text("Your profile and every swing stay on this phone. There's no password and nothing is uploaded.").font(.system(size: 14)).foregroundStyle(Theme.muted).multilineTextAlignment(.center).padding(.horizontal, 30)
                VStack(spacing: 12) {
                    TextField("Your name", text: $name).textContentType(.name).padding(14).background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                    TextField("Email (optional)", text: $email).textContentType(.emailAddress).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled().padding(14).background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                Spacer()
                Button { account.create(name: name, email: email) } label: {
                    Text("Continue").font(.system(size: 17, weight: .bold)).frame(maxWidth: .infinity).padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent).tint(Theme.green).foregroundStyle(.black).padding(.horizontal, 24)
                Button("Skip for now") { account.create(name: "Athlete", email: "") }.font(.system(size: 14)).foregroundStyle(Theme.muted)
                Text("By continuing you agree to the [Terms of Service](https://powerband.fit/terms/) and [Privacy Policy](https://powerband.fit/privacy/).")
                    .font(.system(size: 11)).foregroundStyle(Theme.muted).multilineTextAlignment(.center).padding(.horizontal, 32).padding(.bottom, 14)
            }
        }
    }
}

struct SignInView: View {
    @Environment(Store.self) private var store
    @Environment(Account.self) private var account
    @Environment(SensorManager.self) private var sensor
    @State private var confirmDelete = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer()
                Text(account.profile?.initial ?? "A").font(.num(54)).foregroundStyle(.black).frame(width: 110, height: 110)
                    .background(LinearGradient(colors: [Theme.volt, Theme.green], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                Text("Welcome back").font(.system(size: 14)).foregroundStyle(Theme.muted)
                Text(account.profile?.name ?? "Athlete").font(.num(44)).foregroundStyle(.white)
                Text("\(store.totalShots.formatted()) shots saved on this phone").font(.system(size: 13)).foregroundStyle(Theme.muted)
                Spacer()
                Button { account.signIn() } label: { Text("Sign in").font(.system(size: 17, weight: .bold)).frame(maxWidth: .infinity).padding(.vertical, 16) }
                    .buttonStyle(.borderedProminent).tint(Theme.green).foregroundStyle(.black).padding(.horizontal, 24)
                Button("Delete this account", role: .destructive) { confirmDelete = true }.font(.system(size: 13)).padding(.bottom, 24)
            }
            .confirmationDialog("Delete this account and all its data from the phone?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete account", role: .destructive) { account.deleteAccount(store: store, sensor: sensor) }
            } message: { Text("This permanently removes the profile, every session and your settings. It can't be undone.") }
        }
    }
}

// MARK: Progress hub (History + Trends share one tab so the bar stays at five tabs)

struct ProgressHub: View {
    @State private var segment = 0
    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $segment) { Text("Sessions").tag(0); Text("Trends").tag(1) }
                .pickerStyle(.segmented).padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 4).background(Theme.bg)
            if segment == 0 { HistoryView() } else { TrendsView() }
        }
        .background(Theme.bg)
    }
}
