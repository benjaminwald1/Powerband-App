import SwiftUI

struct OverviewView: View {
    @Environment(Store.self) private var store
    @Environment(SensorManager.self) private var sensor
    @AppStorage("useMph") private var useMph = true
    var goLive: () -> Void

    var body: some View {
        NavigationStack {
            Screen {
                ScreenHeader(kicker: Date.now.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()), title: "Overview")

                HStack(alignment: .top) {
                    RingView(progress: store.power, color: Theme.green, value: "\(Int(store.power * 100))%", label: "Power", size: 104)
                    Spacer()
                    RingView(progress: store.load / 21, color: Theme.blue, value: String(format: "%.1f", store.load), label: "Load", size: 104)
                    Spacer()
                    RingView(progress: store.form, color: Theme.slate, value: "\(Int(store.form * 100))%", label: "Form", size: 104)
                }
                .padding(.vertical, 4)

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Kicker("Shots today")
                        CountUp(target: Double(store.shotsToday)).font(.num(34)).foregroundStyle(.white)
                        let diff = store.shotsToday - store.averageDailyShots
                        Text(diff >= 0 ? "▲ \(diff) vs your average" : "▼ \(-diff) vs your average")
                            .font(.system(size: 10, weight: .semibold)).foregroundStyle(diff >= 0 ? Theme.green : Theme.red)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).card()
                    VStack(alignment: .leading, spacing: 4) {
                        Kicker("Total shots")
                        CountUp(target: Double(store.totalShots)).font(.num(34)).foregroundStyle(.white)
                        Text("Since you started").font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.green)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).card()
                }

                let focus = store.featured.first?.sport
                VStack(alignment: .leading, spacing: 4) {
                    HStack { Kicker(focus?.speedLabel ?? "Swing speed"); Spacer()
                        if store.bestSwing > 0 { Text("BEST \(Int(Units.speed(store.sessions.filter { $0.sport == focus }.map(\.maxSpeed).max() ?? store.bestSwing, useMph: useMph)))").font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(.black).padding(.horizontal, 8).padding(.vertical, 3).background(Theme.green, in: Capsule()) }
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        CountUp(target: Units.speed(store.featured.first?.avgSpeed ?? 0, useMph: useMph)).font(.num(50)).foregroundStyle(.white)
                        Text(Units.label(useMph: useMph).uppercased()).font(.system(size: 12, weight: .semibold)).tracking(1.2).foregroundStyle(Theme.muted)
                        Text("avg").font(.system(size: 11)).foregroundStyle(Theme.muted)
                    }
                    SpeedChart(points: store.recentSpeeds(for: focus), useMph: useMph)
                }
                .card()

                SectionLabel(store.todaySessions.isEmpty ? "LATEST SESSIONS" : "TODAY'S SESSIONS")
                ForEach(store.featured) { s in
                    NavigationLink(value: s) { SessionRow(session: s) }.buttonStyle(.plain)
                }
                if store.featured.isEmpty {
                    VStack(spacing: 10) {
                        Text("No sessions yet").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                        Text("Connect your sensor and start a live session.").font(.system(size: 12)).foregroundStyle(Theme.muted)
                        Button("Start a session", action: goLive).buttonStyle(.borderedProminent).tint(Theme.green).foregroundStyle(.black)
                    }
                    .frame(maxWidth: .infinity).card(padding: 22)
                }
            }
            .navigationDestination(for: Session.self) { SessionDetailView(session: $0) }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
