import SwiftUI

struct RootView: View {
    @State private var tab = UserDefaults.standard.integer(forKey: "startTab")
    @Environment(Store.self) private var store
    @Environment(SensorManager.self) private var sensor
    @Environment(AutoRecorder.self) private var auto
    @AppStorage("autoRecord") private var autoRecord = true
    var body: some View {
        TabView(selection: $tab) {
            OverviewView(goLive: { tab = 1 }).tabItem { Label("Overview", systemImage: "house.fill") }.tag(0)
            LiveView().tabItem { Label("Live", systemImage: "bolt.fill") }.tag(1)
            ProgressHub().tabItem { Label("Progress", systemImage: "chart.bar.fill") }.tag(2)
            DeviceView().tabItem { Label("Device", systemImage: "dot.radiowaves.left.and.right") }.tag(3)
            AccountView().tabItem { Label("Account", systemImage: "person.crop.circle.fill") }.tag(4)
        }
        .toolbarBackground(Theme.card, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .onAppear { sync() }
        .onChange(of: sensor.isConnected) { _, _ in sync() }
        .onChange(of: autoRecord) { _, _ in sync() }
        .onChange(of: tab) { _, _ in sync() }
    }
}

extension RootView {
    /// Auto-record whenever a sensor is connected and the Live tab is not being used by hand.
    fileprivate func sync() {
        if auto.manualActive { return }
        if tab == 1 || !autoRecord || !sensor.isConnected { auto.stop(sensor: sensor) }
        else { auto.start(sensor: sensor, store: store, enabled: true) }
    }
}

struct Screen<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) { content }
                .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 28)
        }
        .background(Theme.bg.ignoresSafeArea())
        .scrollIndicators(.hidden)
    }
}
