import SwiftUI
import AuthenticationServices

/// Sign in with Apple, Google or email and password, plus "continue without an account".
struct AuthView: View {
    @Environment(Account.self) private var account
    @Environment(AuthService.self) private var auth
    var title = "Welcome to PowerBand"
    var subtitle = "Create an account to keep your profile with you, or continue without one."
    var allowSkip = true

    @State private var creating = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focus: Bool

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    Text("P").font(.system(size: 48, weight: .heavy).italic()).foregroundStyle(.white).padding(.top, 24)
                    Text(title).font(.num(34)).foregroundStyle(.white).multilineTextAlignment(.center)
                    Text(subtitle).font(.system(size: 14)).foregroundStyle(Theme.muted).multilineTextAlignment(.center).padding(.horizontal, 24)

                    #if DEBUG
                    if !auth.isConfigured {
                        Text("Developer note: add GoogleService-Info.plist to turn on sign-in (see docs/AUTH_SETUP.md). You can still continue without an account.")
                            .font(.system(size: 11)).foregroundStyle(Theme.volt).padding(10).background(Theme.volt.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    }
                    #endif

                    SignInWithAppleButton(.continue) { auth.prepareApple($0) } onCompletion: { result in
                        Task { if await auth.completeApple(result), let u = auth.user { account.adopt(u) } }
                    }
                    .signInWithAppleButtonStyle(.white).frame(height: 50).clipShape(RoundedRectangle(cornerRadius: 14))

                    Button {
                        Task { if await auth.signInWithGoogle(), let u = auth.user { account.adopt(u) } }
                    } label: {
                        HStack(spacing: 10) {
                            Text("G").font(.system(size: 17, weight: .bold)).foregroundStyle(Color(hex: 0x4285F4))
                            Text("Continue with Google").font(.system(size: 17, weight: .semibold)).foregroundStyle(.black)
                        }
                        .frame(maxWidth: .infinity).frame(height: 50).background(.white, in: RoundedRectangle(cornerRadius: 14))
                    }

                    HStack { Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1); Text("or").font(.system(size: 12)).foregroundStyle(Theme.muted); Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1) }

                    Picker("", selection: $creating) { Text("Sign in").tag(false); Text("Create account").tag(true) }.pickerStyle(.segmented)

                    VStack(spacing: 10) {
                        if creating { field("Your name", text: $name).textContentType(.name) }
                        field("Email", text: $email).textContentType(.emailAddress).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                        SecureField(creating ? "Password (8+ characters)" : "Password", text: $password).textContentType(creating ? .newPassword : .password)
                            .padding(14).background(Theme.card, in: RoundedRectangle(cornerRadius: 14)).focused($focus)
                    }

                    if let m = auth.message { Text(m).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.red).multilineTextAlignment(.center) }
                    if let i = auth.info { Text(i).font(.system(size: 12)).foregroundStyle(Theme.green).multilineTextAlignment(.center) }

                    Button {
                        focus = false
                        Task {
                            let ok = creating ? await auth.createAccount(name: name, email: email, password: password) : await auth.signIn(email: email, password: password)
                            if ok, let u = auth.user { account.adopt(u) }
                        }
                    } label: {
                        Group { if auth.busy { ProgressView().tint(.black) } else { Text(creating ? "Create account" : "Sign in").font(.system(size: 17, weight: .bold)) } }
                            .frame(maxWidth: .infinity).padding(.vertical, 15)
                    }
                    .buttonStyle(.borderedProminent).tint(Theme.green).foregroundStyle(.black).disabled(auth.busy)

                    if !creating { Button("Forgot password?") { Task { await auth.sendPasswordReset(email: email) } }.font(.system(size: 13)).foregroundStyle(Theme.muted) }

                    if allowSkip {
                        Button("Continue without an account") { account.create(name: name.isEmpty ? "Athlete" : name, email: "") }
                            .font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.muted).padding(.top, 6)
                    }

                    Text("By continuing you agree to the [Terms of Service](https://powerband.fit/terms/) and [Privacy Policy](https://powerband.fit/privacy/).")
                        .font(.system(size: 11)).foregroundStyle(Theme.muted).multilineTextAlignment(.center).padding(.horizontal, 20).padding(.bottom, 20)
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear { auth.message = nil; auth.info = nil }
    }

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text).padding(14).background(Theme.card, in: RoundedRectangle(cornerRadius: 14)).focused($focus)
    }
}
