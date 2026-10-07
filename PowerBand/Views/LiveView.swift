import SwiftUI

struct LiveView: View {
    @Environment(Store.self) private var store
    @Environment(SensorManager.self) private var sensor
    @AppStorage("useMph") private var useMph = true
    @AppStorage("dailyGoal") private var goal = 200
    @AppStorage("hapticsOn") private var hapticsOn = true
    @AppStorage("voiceOn") private var voiceOn = false
    @State private var sport: Sport = .tennis
    @State private var running = false
    @State private var paused = false
    @State private var swings: [Swing] = []
    @Environment(AutoRecorder.self) private var auto
    @State private var start = Date()
    @State private var now = Date()
    @State private var pausedTotal: TimeInterval = 0
    @State private var pauseStart: Date?
    @State private var finished: Session?
    @State private var pbBanner: String?
    @State private var baselineBest = 0.0
    @State private var sessionBest = 0.0
    @State private var pulse = false
    private let tick = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private var elapsed: TimeInterval {
        now.timeIntervalSince(start) - pausedTotal - (paused ? now.timeIntervalSince(pauseStart ?? now) : 0)
    }

    var body: some View {
        NavigationStack {
            Screen {
                ScreenHeader(kicker: running ? (paused ? "Paused" : "Recording") : "Ready", title: "Live session")
                if running { liveBody } else { setupBody }
            }
            .overlay(alignment: .top) {
                if let b = pbBanner {
                    HStack(spacing: 8) { Image(systemName: "trophy.fill"); Text(b).font(.system(size: 14, weight: .bold)) }
                        .foregroundStyle(.black).padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Theme.volt, in: Capsule()).shadow(color: Theme.volt.opacity(0.5), radius: 12)
                        .padding(.top, 8).transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .navigationDestination(item: $finished) { SessionDetailView(session: $0) }
            .toolbar(.hidden, for: .navigationBar)
            .onReceive(tick) { now = $0 }
            .onChange(of: running) { _, r in UIApplication.shared.isIdleTimerDisabled = r }
        }
    }

    // MARK: Setup

    @ViewBuilder private var setupBody: some View {
        SectionLabel("SPORT")
        FilterChips(options: Sport.allCases, selection: $sport, title: { $0.title })

        let best = store.bestSpeed(for: sport)
        HStack(spacing: 14) {
            Image(systemName: sport.symbol).font(.system(size: 24, weight: .semibold)).foregroundStyle(Theme.green).frame(width: 52, height: 52).background(Theme.green.opacity(0.13), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(sport.title).font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                Text(best > 0 ? "Best \(sport.speedLabel.lowercased()): \(Int(Units.speed(best, useMph: useMph))) \(Units.label(useMph: useMph))" : "No sessions yet").font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
            Spacer()
            Text(sport.mount.rawValue).font(.system(size: 11)).foregroundStyle(Theme.muted).multilineTextAlignment(.trailing).frame(maxWidth: 110)
        }
        .card()

        HStack {
            Circle().fill(sensor.isConnected ? Theme.green : Theme.red).frame(width: 9, height: 9)
            Text(sensor.isConnected ? "\(sensor.connectedName ?? "Sensor") connected" : "No sensor connected").font(.system(size: 13, weight: .medium)).foregroundStyle(.white)
            Spacer()
            if sensor.isConnected { Label("\(sensor.battery)%", systemImage: "battery.75percent").font(.system(size: 12)).foregroundStyle(Theme.muted) }
        }
        .card()

        let goalLeft = max(0, goal - store.shotsToday)
        HStack { Image(systemName: "target").foregroundStyle(Theme.blue)
            Text(goalLeft == 0 ? "Daily goal reached. Anything more is a bonus." : "\(goalLeft) shots to your daily goal of \(goal)").font(.system(size: 12.5)).foregroundStyle(Color(hex: 0xB6BEC4)); Spacer() }
            .card(padding: 12)

        Button { begin() } label: {
            Text(sensor.isConnected ? "Start session" : "Connect a sensor first").font(.system(size: 17, weight: .bold)).frame(maxWidth: .infinity).padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent).tint(Theme.green).foregroundStyle(.black).disabled(!sensor.isConnected)
        if !sensor.isConnected { Text("Open the Device tab and connect your sensor or the demo sensor.").font(.system(size: 12)).foregroundStyle(Theme.muted) }

        VStack(alignment: .leading, spacing: 10) {
            Toggle("Haptic tap on every shot", isOn: $hapticsOn)
            Toggle("Speak swing speed aloud", isOn: $voiceOn)
        }
        .font(.system(size: 14, weight: .medium)).tint(Theme.green).card()
    }

    // MARK: Live

    @ViewBuilder private var liveBody: some View {
        let last = swings.last
        let best = max(baselineBest, sessionBest)

        HStack { Spacer()
            SpeedDial(value: last.map { Units.speed($0.swingMph, useMph: useMph) } ?? 0, best: Units.speed(best, useMph: useMph), label: last?.kind ?? "Waiting for a swing", unit: Units.label(useMph: useMph), tint: (last?.swingMph ?? 0) >= best && best > 0 && last != nil ? Theme.volt : Theme.green)
            Spacer() }
            .padding(.vertical, 4)

        HStack(spacing: 10) {
            StatTile(label: "Shots", value: swings.count.formatted(), sub: nil)
            StatTile(label: "Time", value: clock(elapsed), sub: paused ? "Paused" : nil, subColor: Theme.volt)
            StatTile(label: "Goal", value: "\(min(999, Int(Double(store.shotsToday + swings.count) / Double(max(goal, 1)) * 100)))", unit: "%", progress: Double(store.shotsToday + swings.count) / Double(max(goal, 1)), progressColor: Theme.blue)
        }
        .fixedSize(horizontal: false, vertical: true)

        if !swings.isEmpty {
            SectionLabel("LAST SHOTS")
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(Array(swings.suffix(10).reversed())) { w in ShotChip(swing: w, useMph: useMph, isBest: w.swingMph >= best && best > 0) }
                }
            }
            .scrollIndicators(.hidden)
        }

        if let last {
            HStack(spacing: 10) {
                if sport == .boxing {
                    StatTile(label: "Force", value: Int(last.forceN).formatted(), unit: "N", progress: last.forceN / max(store.bestForce, 1), progressColor: Theme.blue)
                } else {
                    StatTile(label: "Ball speed", value: String(Int(Units.speed(last.ballMph, useMph: useMph))), unit: Units.label(useMph: useMph), progress: last.ballMph / max(store.bestBall, 1), progressColor: Theme.blue)
                }
                if sport.hasFace {
                    StatTile(label: "Spin", value: last.spinRpm.formatted(), unit: "rpm", progress: Double(last.spinRpm) / 3500, progressColor: Theme.slate)
                } else {
                    StatTile(label: "Tempo", value: String(format: "%.1f", last.tempo), unit: ": 1", progress: 1 - abs(last.tempo - 3) / 2, progressColor: Theme.slate)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        if sport.hasFace { FaceHeatmap(swings: swings) }

        HStack(spacing: 10) {
            Button { togglePause() } label: {
                Label(paused ? "Resume" : "Pause", systemImage: paused ? "play.fill" : "pause.fill").font(.system(size: 16, weight: .bold)).frame(maxWidth: .infinity).padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent).tint(Color(hex: 0x2A3036)).foregroundStyle(.white)
            Button { end() } label: {
                Label("End", systemImage: "stop.fill").font(.system(size: 16, weight: .bold)).frame(maxWidth: .infinity).padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent).tint(Theme.red).foregroundStyle(.black)
        }
    }

    // MARK: Actions

    private func begin() {
        swings = []; start = Date(); now = Date(); pausedTotal = 0; pauseStart = nil; paused = false
        baselineBest = store.bestSpeed(for: sport); sessionBest = 0
        withAnimation { running = true }
        if hapticsOn { Haptics.success() }
        auto.finish(); auto.manualActive = true
        sensor.startStream(sport: sport) { swing in receive(swing) }
    }

    private func receive(_ swing: Swing) {
        guard !paused else { return }
        withAnimation(.snappy) { swings.append(swing) }
        let isPB = baselineBest > 0 && swing.swingMph > max(baselineBest, sessionBest) && swings.count > 1
        sessionBest = max(sessionBest, swing.swingMph)
        if isPB {
            if hapticsOn { Haptics.success() }
            withAnimation(.spring) { pbBanner = "NEW BEST  \(Int(Units.speed(swing.swingMph, useMph: useMph))) \(Units.label(useMph: useMph))" }
            Task { try? await Task.sleep(for: .seconds(3)); withAnimation { pbBanner = nil } }
        } else if hapticsOn { Haptics.thud() }
        if voiceOn { Speaker.shared.say("\(Int(Units.speed(swing.swingMph, useMph: useMph)))") }
    }

    private func togglePause() {
        if paused { pausedTotal += Date().timeIntervalSince(pauseStart ?? Date()); pauseStart = nil; paused = false }
        else { pauseStart = Date(); paused = true }
        if hapticsOn { Haptics.tap() }
    }

    private func end() {
        sensor.stopStream(); auto.manualActive = false
        let endDate = Date()
        withAnimation { running = false }
        let s = Session(sport: sport, start: start, end: endDate, swings: swings)
        if s.count > 0 { store.add(s); finished = s }
    }

    private func clock(_ t: TimeInterval) -> String { let s = max(0, Int(t)); return String(format: "%d:%02d", s / 60, s % 60) }
}
