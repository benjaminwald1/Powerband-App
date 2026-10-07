import SwiftUI

@main
struct PowerBandApp: App {
    @State private var store = Store()
    @State private var sensor = SensorManager()
    @State private var account = Account()
    @State private var auth = AuthService()
    @State private var movement = MovementStore()
    @AppStorage("onboarded") private var onboarded = false

    var body: some Scene {
        WindowGroup {
            Group {
                if !onboarded { OnboardingView(done: { onboarded = true }) }
                else if account.profile == nil { AuthView() }
                else if !account.signedIn { SignInView() }
                else { RootView() }
            }
            .environment(store)
            .environment(sensor)
            .environment(account)
            .environment(auth)
            .environment(movement)
            .task {
                // A cloud account whose session expired or was revoked has to sign in again.
                if let p = account.profile, p.authMethod != .local, account.signedIn, auth.isConfigured, auth.user == nil { account.signOut() }
            }
            .preferredColorScheme(.dark)
            .tint(Theme.green)
        }
    }
}
