import SwiftUI
import Charts

/// Number that animates (counts up) whenever `value` changes.
struct CountUpText: View, Animatable {
    var value: Double
    var format: (Double) -> String = { Int($0.rounded()).formatted() }
    var animatableData: Double { get { value } set { value = newValue } }
    var body: some View { Text(format(value)) }
}

struct CountUp: View {
    let target: Double
    var format: (Double) -> String = { Int($0.rounded()).formatted() }
    @State private var shown = 0.0
    var body: some View {
        CountUpText(value: shown, format: format)
            .onAppear { withAnimation(.easeOut(duration: 1.1)) { shown = target } }
            .onChange(of: target) { _, new in withAnimation(.easeOut(duration: 0.8)) { shown = new } }
    }
}

struct RingView: View {
    var progress: Double
    var color: Color
    var value: String
    var label: String
    var size: CGFloat = 96
    var lineWidth: CGFloat? = nil
    @State private var drawn = 0.0

    var body: some View {
        let lw = lineWidth ?? size * 0.085
        VStack(spacing: 6) {
            ZStack {
                Circle().stroke(Theme.track, lineWidth: lw)
                Circle().trim(from: 0, to: drawn)
                    .stroke(color, style: StrokeStyle(lineWidth: lw, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(0.55), radius: 6)
                Text(value).font(.num(size * 0.3)).foregroundStyle(.white).minimumScaleFactor(0.6).lineLimit(1)
                    .padding(.horizontal, lw + 2)
            }
            .frame(width: size, height: size)
            Kicker(label, color: Color(hex: 0x9AA4AB))
        }
        .onAppear { withAnimation(.easeOut(duration: 1.2)) { drawn = max(0.001, min(progress, 1)) } }
        .onChange(of: progress) { _, p in withAnimation(.easeOut(duration: 0.8)) { drawn = max(0.001, min(p, 1)) } }
    }
}

struct StatTile: View {
    let label: String
    let value: String
    var unit: String = ""
    var sub: String? = nil
    var subColor: Color = Theme.green
    var progress: Double? = nil
    var progressColor: Color = Theme.green

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Kicker(label)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(.num(28)).foregroundStyle(.white)
                if !unit.isEmpty { Text(unit).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.muted) }
            }
            if let sub { Text(sub).font(.system(size: 10, weight: .semibold)).foregroundStyle(subColor) }
            if let progress {
                Capsule().fill(Theme.track).frame(height: 4)
                    .overlay(alignment: .leading) {
                        GeometryReader { g in Capsule().fill(progressColor).frame(width: g.size.width * max(0.02, min(progress, 1))) }
                    }
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View { Kicker(text).padding(.top, 6) }
}

struct ScreenHeader: View {
    let kicker: String
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Kicker(kicker)
            Text(title.uppercased()).font(.num(34)).tracking(0.5).foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: Charts

struct SpeedChart: View {
    let points: [(index: Int, mph: Double)]
    var color: Color = Theme.green
    var useMph = true

    var body: some View {
        let vals = points.map { Units.speed($0.mph, useMph: useMph) }
        let lo = (vals.min() ?? 0) * 0.85, hi = (vals.max() ?? 1) * 1.06
        Chart {
            ForEach(Array(points.enumerated()), id: \.offset) { i, p in
                let v = Units.speed(p.mph, useMph: useMph)
                AreaMark(x: .value("i", i), yStart: .value("lo", lo), yEnd: .value("v", v))
                    .foregroundStyle(LinearGradient(colors: [color.opacity(0.4), color.opacity(0)], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.catmullRom)
                LineMark(x: .value("i", i), y: .value("v", v))
                    .foregroundStyle(color).lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round))
                    .interpolationMethod(.catmullRom)
            }
            if let last = points.indices.last {
                PointMark(x: .value("i", last), y: .value("v", Units.speed(points[last].mph, useMph: useMph)))
                    .foregroundStyle(.white).symbolSize(60)
            }
        }
        .chartXAxis(.hidden)
        .chartYScale(domain: lo...max(hi, lo + 1))
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4])).foregroundStyle(Color.white.opacity(0.12))
                AxisValueLabel().foregroundStyle(Theme.muted).font(.system(size: 9, weight: .medium))
            }
        }
        .frame(height: 110)
    }
}

/// Racquet / paddle face with a heat map of where the ball made contact.
struct FaceHeatmap: View {
    let swings: [Swing]
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Canvas { ctx, size in
                let rect = CGRect(x: size.width * 0.12, y: size.height * 0.06, width: size.width * 0.76, height: size.height * 0.88)
                let face = Path(ellipseIn: rect)
                ctx.clip(to: face)
                // strings
                var grid = Path()
                for i in 0...14 { let x = rect.minX + rect.width * CGFloat(i) / 14; grid.move(to: CGPoint(x: x, y: rect.minY)); grid.addLine(to: CGPoint(x: x, y: rect.maxY)) }
                for i in 0...16 { let y = rect.minY + rect.height * CGFloat(i) / 16; grid.move(to: CGPoint(x: rect.minX, y: y)); grid.addLine(to: CGPoint(x: rect.maxX, y: y)) }
                ctx.stroke(grid, with: .color(.white.opacity(0.15)), lineWidth: 0.6)
                // heat blobs
                for s in swings.suffix(300) {
                    let c = CGPoint(x: rect.midX + CGFloat(s.impactX) * rect.width / 2, y: rect.midY + CGFloat(s.impactY) * rect.height / 2)
                    let r = rect.width * 0.12
                    let blob = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
                    ctx.fill(blob, with: .radialGradient(Gradient(colors: [Theme.green.opacity(0.18), .clear]), center: c, startRadius: 0, endRadius: r))
                }
                ctx.clip(to: Path(CGRect(origin: .zero, size: size)), options: .init(rawValue: 0))
            }
            Canvas { ctx, size in
                let rect = CGRect(x: size.width * 0.12, y: size.height * 0.06, width: size.width * 0.76, height: size.height * 0.88)
                ctx.stroke(Path(ellipseIn: rect), with: .color(.white), lineWidth: 4)
                let sweet = CGRect(x: rect.midX - rect.width * 0.16, y: rect.midY - rect.height * 0.16, width: rect.width * 0.32, height: rect.height * 0.32)
                ctx.stroke(Path(ellipseIn: sweet), with: .color(.white.opacity(0.9)), style: StrokeStyle(lineWidth: 1.4, dash: [3, 4]))
                for s in swings.suffix(40) {
                    let c = CGPoint(x: rect.midX + CGFloat(s.impactX) * rect.width / 2, y: rect.midY + CGFloat(s.impactY) * rect.height / 2)
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x - 3, y: c.y - 3, width: 6, height: 6)), with: .color(.white))
                }
            }
            let rate = swings.isEmpty ? 0 : Double(swings.filter(\.isSweetSpot).count) / Double(swings.count)
            Text("SWEET SPOT \(Int((rate * 100).rounded()))%")
                .font(.system(size: 9, weight: .bold)).tracking(1)
                .foregroundStyle(.black).padding(.horizontal, 9).padding(.vertical, 5)
                .background(.white, in: Capsule()).padding(10)
        }
        .aspectRatio(1.7, contentMode: .fit)
        .card(padding: 6)
    }
}

/// Side-on drawing of the swing path through the contact point.
struct PathDiagram: View {
    let pathDeg: Double
    let faceDeg: Double
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            for i in 0..<4 {
                let y = h * (0.2 + 0.2 * CGFloat(i))
                var l = Path(); l.move(to: CGPoint(x: 0, y: y)); l.addLine(to: CGPoint(x: w, y: y))
                ctx.stroke(l, with: .color(.white.opacity(0.08)), style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
            }
            let rise = CGFloat(min(max(pathDeg, 0), 40)) / 40
            let contact = CGPoint(x: w * 0.5, y: h * 0.62)
            var p = Path()
            p.move(to: CGPoint(x: w * 0.05, y: h * 0.82))
            p.addCurve(to: contact, control1: CGPoint(x: w * 0.25, y: h * 0.86), control2: CGPoint(x: w * 0.38, y: h * 0.72))
            p.addCurve(to: CGPoint(x: w * 0.94, y: h * (0.62 - 0.46 * (0.4 + rise * 0.6))), control1: CGPoint(x: w * 0.65, y: h * 0.52), control2: CGPoint(x: w * 0.8, y: h * 0.26))
            ctx.stroke(p, with: .linearGradient(Gradient(colors: [Theme.green.opacity(0), Theme.green]), startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: w, y: 0)),
                       style: StrokeStyle(lineWidth: 7, lineCap: .round))
            // racquet face at contact
            var face = Path()
            face.move(to: CGPoint(x: contact.x, y: contact.y - 30)); face.addLine(to: CGPoint(x: contact.x, y: contact.y + 30))
            let rot = CGAffineTransform(translationX: contact.x, y: contact.y).rotated(by: CGFloat(faceDeg - 28) * .pi / 180).translatedBy(x: -contact.x, y: -contact.y)
            ctx.stroke(face.applying(rot), with: .color(.white), style: StrokeStyle(lineWidth: 6, lineCap: .round))
            ctx.fill(Path(ellipseIn: CGRect(x: contact.x - 8, y: contact.y - 8, width: 16, height: 16)), with: .color(.black))
            ctx.stroke(Path(ellipseIn: CGRect(x: contact.x - 8, y: contact.y - 8, width: 16, height: 16)), with: .color(Theme.green), lineWidth: 2.4)
        }
        .overlay(alignment: .topLeading) { Kicker("Backswing").padding([.leading, .top], 6).opacity(0) }
        .frame(height: 130)
        .card(padding: 8)
    }
}

struct BarRow: View {
    let label: String
    let value: Double
    let max: Double
    let color: Color
    let text: String
    var body: some View {
        VStack(spacing: 4) {
            HStack { Kicker(label, color: Color(hex: 0x9AA4AB)); Spacer(); Text(text).font(.num(16)).foregroundStyle(.white) }
            Capsule().fill(Theme.track).frame(height: 6)
                .overlay(alignment: .leading) {
                    GeometryReader { g in Capsule().fill(color).frame(width: g.size.width * min(1, value / Swift.max(max, 1))).shadow(color: color.opacity(0.5), radius: 4) }
                }
        }
    }
}

struct SportIcon: View {
    let sport: Sport
    var color: Color = Theme.blue
    var body: some View {
        Image(systemName: sport.symbol).font(.system(size: 15, weight: .semibold)).foregroundStyle(color)
            .frame(width: 34, height: 34)
            .overlay(Circle().stroke(color.opacity(0.4), lineWidth: 1.5))
    }
}

struct SessionRow: View {
    let session: Session
    var body: some View {
        HStack(spacing: 12) {
            SportIcon(sport: session.sport)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.sport.title).font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                Text("\(durationText(session.duration)) · \(session.count) shots").font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.muted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text(String(format: "%.1f", session.load)).font(.num(22)).foregroundStyle(Theme.blue)
                Kicker("Load")
            }
        }
        .card(padding: 11)
    }
}

func durationText(_ s: TimeInterval) -> String {
    let m = Int(s / 60)
    return m >= 60 ? "\(m / 60)h \(String(format: "%02d", m % 60))m" : "\(max(m, 1))m"
}
