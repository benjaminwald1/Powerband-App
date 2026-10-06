import SwiftUI

struct OverviewView: View {
    @Environment(Store.self) private var store
    @Environment(SensorManager.self) private var sensor
    @AppStorage("useMph") private var useMph = true
    @AppStorage("dailyGoal") private var goal = 200
    @State private var showProfile = false
    var goLive: () -> Void

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) { case 5..<12: "Good morning"; case 12..<17: "Good afternoon"; case 17..<22: "Good evening"; default: "Late session?" }
    }

    var body: some View {
        NavigationStack {
            Screen {
                HStack(alignment: .top) {
                    ScreenHeader(kicker: Date.now.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()), title: "Overview")
                    Spacer(minLength: 8)
                    HStack(spacing: 8) {
                        if store.streak > 0 {
                            Label("\(store.streak)", systemImage: "flame.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.volt)
                                .padding(.horizontal, 10).padding(.vertical, 7).background(Theme.volt.opacity(0.13), in: Capsule())
                        }
                        Button { showProfile = true } label: {
                            Image(systemName: "person.crop.circle.fill").font(.system(size: 26)).foregroundStyle(Theme.muted)
                        }
                    }
                    .padding(.top, 12)
                }
                Text(greeting).font(.system(size: 14)).foregroundStyle(Theme.muted).padding(.top, -6)

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
                        Capsule().fill(Theme.track).frame(height: 5)
                            .overlay(alignment: .leading) { GeometryReader { g in Capsule().fill(store.shotsToday >= goal ? Theme.volt : Theme.green).frame(width: g.size.width * min(1, Double(store.shotsToday) / Double(max(goal, 1)))) } }
                        Text(store.shotsToday >= goal ? "Goal reached" : "Goal \(goal)").font(.system(size: 10, weight: .semibold)).foregroundStyle(store.shotsToday >= goal ? Theme.volt : Theme.muted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).card()
                    VStack(alignment: .leading, spacing: 4) {
                        Kicker("Total shots")
                        CountUp(target: Double(store.totalShots)).font(.num(34)).foregroundStyle(.white)
                        Text("\(store.sessions.count) sessions").font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.green)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).card()
                }
                .fixedSize(horizontal: false, vertical: true)

                let focus = store.featured.first?.sport
                VStack(alignment: .leading, spacing: 4) {
                    HStack { Kicker(focus?.speedLabel ?? "Swing speed"); Spacer()
                        if let f = focus { Text("BEST \(Int(Units.speed(store.bestSpeed(for: f), useMph: useMph)))").font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(.black).padding(.horizontal, 8).padding(.vertical, 3).background(Theme.green, in: Capsule()) }
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        CountUp(target: Units.speed(store.featured.first?.avgSpeed ?? 0, useMph: useMph)).font(.num(50)).foregroundStyle(.white)
                        Text(Units.label(useMph: useMph).uppercased()).font(.system(size: 12, weight: .semibold)).tracking(1.2).foregroundStyle(Theme.muted)
                        Text("avg").font(.system(size: 11)).foregroundStyle(Theme.muted)
                    }
                    SpeedChart(points: store.recentSpeeds(for: focus), useMph: useMph)
                }
                .card()

                let tips = InsightEngine.overview(store)
                if !tips.isEmpty {
                    SectionLabel("INSIGHTS")
                    ForEach(tips) { InsightCard(insight: $0) }
                }

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
            .sheet(isPresented: $showProfile) { ProfileView() }
        }
    }
}
