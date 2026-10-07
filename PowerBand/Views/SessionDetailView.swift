import SwiftUI
import Charts

struct SessionDetailView: View {
    let session: Session
    @Environment(Store.self) private var store
    @AppStorage("useMph") private var useMph = true
    @AppStorage("weightKg") private var weightKg = 70.0
    @State private var shareImage: Image?

    private var series: [(index: Int, mph: Double)] {
        let s = session.swings.sorted { $0.time < $1.time }
        let step = max(1, s.count / 28)
        return stride(from: 0, to: s.count, by: step).enumerated().map { i, start in
            let chunk = s[start..<min(start + step, s.count)]
            return (i, chunk.map(\.swingMph).reduce(0, +) / Double(chunk.count))
        }
    }

    var body: some View {
        let s = session
        Screen {
            ScreenHeader(kicker: "\(s.start.formatted(.dateTime.weekday(.abbreviated).month().day().hour().minute())) · \(durationText(s.duration))", title: s.sport.title)

            HStack(alignment: .firstTextBaseline) {
                CountUp(target: Double(s.count)).font(.num(64)).foregroundStyle(.white)
                Text("SHOTS").font(.system(size: 12, weight: .semibold)).tracking(1.4).foregroundStyle(Theme.muted)
                Spacer()
                Text("LOAD \(String(format: "%.1f", s.load))").font(.system(size: 10, weight: .bold)).tracking(1).foregroundStyle(.black).padding(.horizontal, 9).padding(.vertical, 4).background(Theme.blue, in: Capsule())
            }

            let tips = InsightEngine.forSession(s, store: store)
            if !tips.isEmpty { SectionLabel("INSIGHTS"); ForEach(tips) { InsightCard(insight: $0) } }

            VStack(alignment: .leading, spacing: 4) {
                Kicker(s.sport.speedLabel)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(String(Int(Units.speed(s.avgSpeed, useMph: useMph)))).font(.num(44)).foregroundStyle(.white)
                    Text("\(Units.label(useMph: useMph).uppercased()) AVG · BEST \(Int(Units.speed(s.maxSpeed, useMph: useMph)))").font(.system(size: 11, weight: .semibold)).tracking(1).foregroundStyle(Theme.muted)
                }
                SpeedChart(points: series, useMph: useMph)
            }
            .card()

            StatTile(label: "Calories burned", value: Int(s.totalCalories(weightKg: weightKg)).formatted(), unit: "kcal", sub: "\(s.sport.title) at \(Int(weightKg)) kg, estimated", subColor: Theme.muted, progress: min(1, s.totalCalories(weightKg: weightKg) / 800), progressColor: Theme.volt)

            if s.sport.hasFace {
                SectionLabel("CONTACT POINT")
                FaceHeatmap(swings: s.swings)
                SectionLabel("RACQUET PATH")
                PathDiagram(pathDeg: s.avgPath, faceDeg: s.avgFace)
                HStack(spacing: 10) {
                    StatTile(label: "Path angle", value: String(format: "%.0f", s.avgPath), unit: "°", progress: s.avgPath / 30)
                    StatTile(label: "Face angle", value: String(format: "%.0f", s.avgFace), unit: s.avgFace < 0 ? "° closed" : "° open", progress: abs(s.avgFace) / 10, progressColor: Theme.blue)
                }
                SectionLabel("BALL & SPIN")
                VStack(spacing: 12) {
                    BarRow(label: "Top ball speed", value: s.maxBall, max: 130, color: Theme.green, text: "\(Int(Units.speed(s.maxBall, useMph: useMph))) \(Units.label(useMph: useMph))")
                    BarRow(label: "Average spin", value: Double(s.avgSpin), max: 3500, color: Theme.blue, text: "\(s.avgSpin.formatted()) rpm")
                    BarRow(label: "Sweet spot", value: s.sweetSpotRate, max: 1, color: Theme.slate, text: "\(Int(s.sweetSpotRate * 100))%")
                }
                .card()
            } else if s.sport == .golf {
                HStack(spacing: 10) {
                    StatTile(label: "Top club speed", value: String(Int(Units.speed(s.maxSpeed, useMph: useMph))), unit: Units.label(useMph: useMph), progress: s.maxSpeed / 120)
                    StatTile(label: "Tempo", value: String(format: "%.1f", s.avgTempo), unit: ": 1", progress: 1 - abs(s.avgTempo - 3) / 2, progressColor: Theme.blue)
                }
                StatTile(label: "Top ball speed", value: String(Int(Units.speed(s.maxBall, useMph: useMph))), unit: Units.label(useMph: useMph), progress: s.maxBall / 190)
            } else {
                HStack(spacing: 10) {
                    StatTile(label: "Peak force", value: Int(s.maxForce).formatted(), unit: "N", progress: s.maxForce / 2000)
                    StatTile(label: "Consistency", value: "\(Int(s.consistency * 100))", unit: "%", progress: s.consistency, progressColor: Theme.slate)
                }
                SectionLabel("PUNCH MIX")
                VStack(spacing: 12) {
                    let kinds = Sport.boxing.kinds
                    ForEach(kinds, id: \.self) { k in
                        let n = s.swings.filter { $0.kind == k }.count
                        BarRow(label: k, value: Double(n), max: Double(s.count) / 2, color: Theme.green, text: "\(n)")
                    }
                }
                .card()
            }
        }
        .task { let r = ImageRenderer(content: ShareCard(session: s, useMph: useMph)); r.scale = 3; if let ui = r.uiImage { shareImage = Image(uiImage: ui) } }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let img = shareImage { ShareLink(item: img, preview: SharePreview("PowerBand \(s.sport.title) session", image: img)) { Image(systemName: "square.and.arrow.up") } }
            }
        }
        .navigationTitle(s.sport.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.bg, for: .navigationBar)
    }
}
