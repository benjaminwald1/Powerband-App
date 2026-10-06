import SwiftUI
import Charts

struct TrendsView: View {
    @Environment(Store.self) private var store
    @AppStorage("useMph") private var useMph = true
    @State private var range = 7

    var body: some View {
        Screen {
            ScreenHeader(kicker: "Last \(range) days", title: "Trends")

            Picker("Range", selection: $range) { Text("7 days").tag(7); Text("30 days").tag(30) }.pickerStyle(.segmented)

            let daily = store.dailyShots(days: range)
            VStack(alignment: .leading, spacing: 8) {
                HStack { Kicker("Shots per day"); Spacer(); Text("\(daily.map(\.count).reduce(0, +).formatted()) total").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.muted) }
                Chart(daily, id: \.date) { d in
                    BarMark(x: .value("Day", d.date, unit: .day), y: .value("Shots", d.count))
                        .foregroundStyle(Calendar.current.isDateInToday(d.date) ? Theme.green : Color.white.opacity(0.22))
                        .cornerRadius(4)
                }
                .chartXAxis { AxisMarks(values: .stride(by: .day, count: range == 7 ? 1 : 7)) { _ in AxisValueLabel(format: range == 7 ? .dateTime.weekday(.narrow) : .dateTime.month().day()).foregroundStyle(Theme.muted) } }
                .chartYAxis { AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4])).foregroundStyle(Color.white.opacity(0.12)); AxisValueLabel().foregroundStyle(Theme.muted) } }
                .frame(height: 170)
            }
            .card()

            SectionLabel("PERSONAL BESTS")
            HStack(spacing: 10) {
                StatTile(label: "Fastest swing", value: String(Int(Units.speed(store.bestSwing, useMph: useMph))), unit: Units.label(useMph: useMph), progress: 1)
                StatTile(label: "Fastest ball", value: String(Int(Units.speed(store.bestBall, useMph: useMph))), unit: Units.label(useMph: useMph), progress: 1, progressColor: Theme.blue)
            }
            HStack(spacing: 10) {
                StatTile(label: "Most spin", value: store.bestSpin.formatted(), unit: "rpm", progress: 1, progressColor: Theme.slate)
                StatTile(label: "Hardest punch", value: Int(store.bestForce).formatted(), unit: "N", progress: 1)
            }

            SectionLabel("BY SPORT")
            let split = store.sportBreakdown()
            if !split.isEmpty {
                HStack(spacing: 16) {
                    Chart(split, id: \.sport) { e in
                        SectorMark(angle: .value("Shots", e.shots), innerRadius: .ratio(0.62), angularInset: 2)
                            .foregroundStyle(by: .value("Sport", e.sport.title))
                    }
                    .chartForegroundStyleScale(range: [Theme.green, Theme.blue, Theme.slate, Theme.volt, Theme.red])
                    .chartLegend(.hidden)
                    .frame(width: 130, height: 130)
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(split, id: \.sport) { e in
                            HStack { SportIcon(sport: e.sport, color: Theme.muted).scaleEffect(0.7).frame(width: 26, height: 26)
                                Text(e.sport.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                                Spacer(); Text(e.shots.formatted()).font(.num(18)).foregroundStyle(Theme.muted) }
                        }
                    }
                }
                .card()
            }
        }
    }
}
