import SwiftUI

struct RootView: View {
    @State private var tab = UserDefaults.standard.integer(forKey: "startTab")
    var body: some View {
        TabView(selection: $tab) {
            OverviewView(goLive: { tab = 1 }).tabItem { Label("Overview", systemImage: "house.fill") }.tag(0)
            LiveView().tabItem { Label("Live", systemImage: "bolt.fill") }.tag(1)
            HistoryView().tabItem { Label("History", systemImage: "list.bullet.rectangle.fill") }.tag(2)
            TrendsView().tabItem { Label("Trends", systemImage: "chart.bar.fill") }.tag(3)
            DeviceView().tabItem { Label("Device", systemImage: "dot.radiowaves.left.and.right") }.tag(4)
        }
        .toolbarBackground(Theme.card, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
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
