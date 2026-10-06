import SwiftUI

struct LiveView: View {
    @Environment(Store.self) private var store
    @Environment(SensorManager.self) private var sensor
    @AppStorage("useMph") private var useMph = true
    @State private var sport: Sport = .tennis
    @State private var running = false
    @State private var swings: [Swing] = []
    @State private var start = Date()
    @State private var now = Date()
    @State private var finished: Session?
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            Screen {
                ScreenHeader(kicker: running ? "Recording" : "Ready", title: "Live session")

                if !running {
                    SectionLabel("SPORT")
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(Sport.allCases) { s in
                                Button { sport = s } label: {
                                    HStack(spacing: 6) { Image(systemName: s.symbol); Text(s.title) }
                                        .font(.system(size: 13, weight: .semibold)).padding(.horizontal, 14).padding(.vertical, 10)
                                        .background(sport == s ? Color.white : Theme.card, in: Capsule())
                                        .foregroundStyle(sport == s ? .black : .white)
                                }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)

                    HStack {
                        Circle().fill(sensor.isConnected ? Theme.green : Theme.red).frame(width: 8, height: 8)
                        Text(sensor.isConnected ? "\(sensor.connectedName ?? "Sensor") connected" : "No sensor connected").font(.system(size: 13, weight: .medium)).foregroundStyle(.white)
                        Spacer()
                        Text("Mount: \(sport.mount.rawValue)").font(.system(size: 11)).foregroundStyle(Theme.muted)
                    }
                    .card()

                    Button { begin() } label: {
                        Text(sensor.isConnected ? "Start session" : "Connect a sensor first").font(.system(size: 17, weight: .bold)).frame(maxWidth: .infinity).padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent).tint(Theme.green).foregroundStyle(.black).disabled(!sensor.isConnected)
                } else {
                    liveBody
                }
            }
            .navigationDestination(item: $finished) { SessionDetailView(session: $0) }
            .toolbar(.hidden, for: .navigationBar)
            .onReceive(tick) { now = $0 }
        }
    }

    @ViewBuilder private var liveBody: some View {
        let last = swings.last
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Kicker("Shots")
                CountUp(target: Double(swings.count)).font(.num(72)).foregroundStyle(.white)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Kicker("Time")
                Text(durationClock(now.timeIntervalSince(start))).font(.num(34)).foregroundStyle(Theme.muted)
            }
        }
        .card()

        HStack(spacing: 10) {
            StatTile(label: sport.speedLabel, value: last.map { String(Int(Units.speed($0.swingMph, useMph: useMph))) } ?? "–", unit: Units.label(useMph: useMph), sub: last?.kind, progress: last.map { $0.swingMph / max(store.bestSwing, 1) })
            if sport == .boxing {
                StatTile(label: "Force", value: last.map { String(Int($0.forceN)) } ?? "–", unit: "N", progress: last.map { $0.forceN / max(store.bestForce, 1) }, progressColor: Theme.blue)
            } else {
                StatTile(label: "Ball speed", value: last.map { String(Int(Units.speed($0.ballMph, useMph: useMph))) } ?? "–", unit: Units.label(useMph: useMph), progress: last.map { $0.ballMph / max(store.bestBall, 1) }, progressColor: Theme.blue)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        if sport.hasFace {
            HStack(spacing: 10) {
                StatTile(label: "Spin", value: last.map { $0.spinRpm.formatted() } ?? "–", unit: "rpm", progress: last.map { Double($0.spinRpm) / 3500 }, progressColor: Theme.slate)
                StatTile(label: "Path", value: last.map { String(format: "%.0f", $0.pathDeg) } ?? "–", unit: "°", progress: last.map { $0.pathDeg / 30 })
            }
            .fixedSize(horizontal: false, vertical: true)
            FaceHeatmap(swings: swings)
        }

        Button(role: .destructive) { end() } label: {
            Text("End session").font(.system(size: 17, weight: .bold)).frame(maxWidth: .infinity).padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent).tint(Color(hex: 0x2A3036)).foregroundStyle(.white)
    }

    private func begin() {
        swings = []; start = Date(); now = Date(); running = true
        sensor.startStream(sport: sport) { swing in
            withAnimation(.snappy) { swings.append(swing) }
        }
    }

    private func end() {
        sensor.stopStream()
        running = false
        let s = Session(sport: sport, start: start, end: Date(), swings: swings)
        if s.count > 0 { store.add(s); finished = s }
    }

    private func durationClock(_ t: TimeInterval) -> String {
        let s = Int(t); return String(format: "%d:%02d", s / 60, s % 60)
    }
}
