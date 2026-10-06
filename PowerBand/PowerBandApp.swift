import SwiftUI

@main
struct PowerBandApp: App {
    @State private var store = Store()
    @State private var sensor = SensorManager()
    @State private var account = Account()
    @AppStorage("onboarded") private var onboarded = false

    var body: some Scene {
        WindowGroup {
            Group {
                if !onboarded { OnboardingView(done: { onboarded = true }) }
                else if account.profile == nil { CreateProfileView() }
                else if !account.signedIn { SignInView() }
                else { RootView() }
            }
            .environment(store)
            .environment(sensor)
            .environment(account)
            .preferredColorScheme(.dark)
            .tint(Theme.green)
        }
    }
}
