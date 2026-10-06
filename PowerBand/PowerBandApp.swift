import SwiftUI

@main
struct PowerBandApp: App {
    @State private var store = Store()
    @State private var sensor = SensorManager()
    @AppStorage("onboarded") private var onboarded = false

    var body: some Scene {
        WindowGroup {
            Group {
                if onboarded { RootView() } else { OnboardingView(done: { onboarded = true }) }
            }
            .environment(store)
            .environment(sensor)
            .preferredColorScheme(.dark)
            .tint(Theme.green)
        }
    }
}
