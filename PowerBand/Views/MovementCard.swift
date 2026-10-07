import SwiftUI
import Charts

/// All-day movement summary: score ring, steps, active hours, a stillness nudge and the last 7 days.
struct MovementCard: View {
    @Environment(MovementStore.self) private var move
    @Environment(Store.self) private var store
    @AppStorage("weightKg") private var weightKg = 70.0
    @Environment(\.scenePhase) private var phase
    @AppStorage("stepGoal") private var stepGoal = 8000
    @AppStorage("useMph") private var useMph = true

    private var score: Int { move.score(goal: stepGoal) }
    private var dailyKcal: Int { Int(move.walkingCalories(weightKg: weightKg).rounded()) }
    private var sportKcal: Int { Int(store.todaySessions.map { $0.extraCalories(weightKg: weightKg) }.reduce(0, +).rounded()) }
    private var distance: String {
        let mi = move.distanceMeters / 1609.344, km = move.distanceMeters / 1000
        return useMph ? String(format: "%.1f mi", mi) : String(format: "%.1f km", km)
    }
    private var verdict: String {
        switch score { case 85...: "Crushing it"; case 60..<85: "Moving well"; case 30..<60: "Getting going"; default: "Time to move" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Kicker("Daily movement"); Spacer(); if move.available && !move.denied { Text(verdict.uppercased()).font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(Theme.green) } }

            if !move.available {
                note("Step counting isn't available on this device.")
            } else if move.denied {
                VStack(alignment: .leading, spacing: 8) {
                    note("Allow Motion & Fitness to see your daily movement. It stays on your phone.")
                    Button("Open Settings") { if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) } }
                        .font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.green)
                }
            } else {
                HStack(spacing: 18) {
                    RingView(progress: Double(score) / 100, color: Theme.green, value: "\(score)", label: "Score", size: 96)
                    VStack(alignment: .leading, spacing: 10) {
                        stat("\(move.steps.formatted())", "of \(stepGoal.formatted()) steps")
                        HStack(spacing: 18) {
                            stat(distance, "distance"); stat("\(move.activeHours)", "active hrs")
                        }
                    }
                    Spacer(minLength: 0)
                }
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\((dailyKcal + sportKcal).formatted())").font(.num(30)).foregroundStyle(.white)
                        Text("active calories today").font(.system(size: 10)).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Label("\(dailyKcal) daily", systemImage: "figure.walk").foregroundStyle(Theme.green)
                        Label("\(sportKcal) sport", systemImage: "figure.tennis").foregroundStyle(Theme.blue)
                    }.font(.system(size: 11, weight: .semibold))
                }
                .padding(12).background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                if let still = move.minutesStill, still >= 60 {
                    Label("Still for \(still / 60) hr \(still % 60) min. Stand up and stretch.", systemImage: "figure.walk")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.volt)
                        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.volt.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                }
                dayTimeline
                if move.week.contains(where: { $0.steps > 0 }) {
                    Chart(move.week) { d in
                        BarMark(x: .value("Day", d.date, unit: .day), y: .value("Steps", d.steps), width: .fixed(16))
                            .foregroundStyle(Calendar.current.isDateInToday(d.date) ? Theme.green : Theme.green.opacity(0.35))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        RuleMark(y: .value("Goal", stepGoal)).lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3])).foregroundStyle(Theme.muted.opacity(0.5))
                    }
                    .chartXAxis { AxisMarks(values: .stride(by: .day)) { _ in AxisValueLabel(format: .dateTime.weekday(.narrow)).foregroundStyle(Theme.muted) } }
                    .chartYAxis(.hidden)
                    .frame(height: 70)
                }
            }
        }
        .card()
        .task { await move.refresh() }
        .onChange(of: phase) { _, p in if p == .active { Task { await move.refresh() } } }
    }

    /// One strip for the whole day: steps by hour with sport sessions marked on top.
    private var dayTimeline: some View {
        let cal = Calendar.current
        let sessions = store.todaySessions
        func hourFloat(_ d: Date) -> Double { Double(cal.component(.hour, from: d)) + Double(cal.component(.minute, from: d)) / 60 }
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("TODAY, HOUR BY HOUR").font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(Theme.muted)
                Spacer()
                Label("Steps", systemImage: "circle.fill").foregroundStyle(Theme.green)
                Label("Sport", systemImage: "circle.fill").foregroundStyle(Theme.blue)
            }.font(.system(size: 9, weight: .semibold)).labelStyle(DotLabel())
            Chart {
                ForEach(0..<24, id: \.self) { h in
                    BarMark(x: .value("Hour", Double(h) + 0.5), y: .value("Steps", move.hourly[h]), width: .fixed(9))
                        .foregroundStyle(Theme.green.opacity(move.hourly[h] >= 250 ? 1 : 0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                ForEach(sessions) { s in
                    RectangleMark(xStart: .value("Start", hourFloat(s.start)), xEnd: .value("End", max(hourFloat(s.end), hourFloat(s.start) + 0.4)), yStart: .value("Base", 0), yEnd: .value("Top", max(move.hourly.max() ?? 1000, 1000)))
                        .foregroundStyle(Theme.blue.opacity(0.28))
                }
            }
            .chartXScale(domain: 0...24)
            .chartXAxis { AxisMarks(values: [0, 6, 12, 18, 24]) { v in AxisValueLabel { Text(["12a", "6a", "12p", "6p", ""][min(4, (v.as(Int.self) ?? 0) / 6)]).foregroundStyle(Theme.muted) } } }
            .chartYAxis(.hidden)
            .frame(height: 70)
            if let s = sessions.first {
                Text("\(s.sport.title) at \(s.start.formatted(.dateTime.hour().minute())) · \(Int(s.totalCalories(weightKg: weightKg))) kcal").font(.system(size: 11)).foregroundStyle(Theme.muted)
            }
        }
    }

    private func stat(_ v: String, _ l: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(v).font(.num(22)).foregroundStyle(.white)
            Text(l).font(.system(size: 10)).foregroundStyle(Theme.muted)
        }
    }
    private func note(_ t: String) -> some View { Text(t).font(.system(size: 12)).foregroundStyle(Theme.muted) }
}

private struct DotLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) { configuration.icon.font(.system(size: 5)); configuration.title.foregroundStyle(Theme.muted) }
    }
}
