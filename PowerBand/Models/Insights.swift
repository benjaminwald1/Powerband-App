import Foundation

struct Insight: Identifiable, Hashable {
    enum Tone { case good, warn, info }
    let id = UUID()
    let symbol: String
    let title: String
    let text: String
    let tone: Tone
}

/// Plain-language takeaways generated from the numbers. Everything runs on the device.
enum InsightEngine {
    static func forSession(_ s: Session, store: Store) -> [Insight] {
        var out: [Insight] = []
        let swings = s.swings.sorted { $0.time < $1.time }
        guard swings.count >= 6 else {
            return [Insight(symbol: "figure.walk", title: "Warm-up", text: "Play a few more shots and PowerBand will start spotting patterns.", tone: .info)]
        }

        // Fatigue: first third vs last third
        let third = max(2, swings.count / 3)
        let early = swings.prefix(third).map(\.swingMph).reduce(0, +) / Double(third)
        let late = swings.suffix(third).map(\.swingMph).reduce(0, +) / Double(third)
        let drop = (early - late) / max(early, 1)
        if drop > 0.05 {
            out.append(Insight(symbol: "battery.50percent", title: "You faded late", text: "\(s.sport.speedLabel) fell \(Int(drop * 100))% in the last third of the session. Short rests between sets can keep it up.", tone: .warn))
        } else if drop < -0.03 {
            out.append(Insight(symbol: "flame.fill", title: "You got faster", text: "\(s.sport.speedLabel) rose \(Int(-drop * 100))% as you warmed up. Strong finish.", tone: .good))
        }

        if s.sport.hasFace {
            let rate = s.sweetSpotRate
            if rate >= 0.7 {
                out.append(Insight(symbol: "scope", title: "Clean contact", text: "\(Int(rate * 100))% of shots hit the sweet spot. That is where the most power and feel come from.", tone: .good))
            } else if rate < 0.5 {
                let mx = swings.map(\.impactX).reduce(0, +) / Double(swings.count)
                let my = swings.map(\.impactY).reduce(0, +) / Double(swings.count)
                let side = abs(my) > abs(mx) ? (my < 0 ? "high" : "low") : (mx < 0 ? "left" : "right")
                out.append(Insight(symbol: "target", title: "Contact is drifting", text: "Only \(Int(rate * 100))% hit the sweet spot, and most were \(side) on the face. Watch the ball onto the strings.", tone: .warn))
            }
            if s.sport == .tennis || s.sport == .padel {
                if (12...22).contains(s.avgPath) {
                    out.append(Insight(symbol: "arrow.up.right", title: "Good swing path", text: "A \(Int(s.avgPath))° low-to-high path gives you the topspin and net clearance you want.", tone: .good))
                } else if s.avgPath < 8 {
                    out.append(Insight(symbol: "arrow.up.right", title: "Flat swing path", text: "Your path averaged \(Int(s.avgPath))°. Brushing up a little more adds spin and margin over the net.", tone: .info))
                }
            }
            if s.avgFace < -5 { out.append(Insight(symbol: "rotate.right", title: "Face is closing", text: "The face averaged \(Int(-s.avgFace))° closed at contact, which pushes the ball into the ground.", tone: .warn)) }
        }

        if s.sport == .golf, s.avgTempo > 3.4 || s.avgTempo < 2.6 {
            out.append(Insight(symbol: "metronome.fill", title: "Tempo", text: "Your tempo averaged \(String(format: "%.1f", s.avgTempo)) : 1. Most good swings sit near 3 : 1.", tone: .info))
        }
        if s.sport == .boxing, s.maxForce > 0 {
            out.append(Insight(symbol: "bolt.fill", title: "Peak punch", text: "Your hardest punch hit \(Int(s.maxForce)) N.", tone: .good))
        }

        if s.consistency > 0.88 { out.append(Insight(symbol: "waveform.path", title: "Very consistent", text: "Your speed barely varied from shot to shot. That repeatability is what wins points.", tone: .good)) }

        let prior = store.sessions.filter { $0.sport == s.sport && $0.start < s.start }.map(\.maxSpeed).max() ?? 0
        if prior > 0, s.maxSpeed > prior {
            out.append(Insight(symbol: "trophy.fill", title: "New personal best", text: "\(Int(s.maxSpeed)) mph beat your previous best of \(Int(prior)) mph.", tone: .good))
        }
        return Array(out.prefix(4))
    }

    static func overview(_ store: Store) -> [Insight] {
        var out: [Insight] = []
        let cal = Calendar.current
        let now = Date()
        let weekAgo = cal.date(byAdding: .day, value: -7, to: now)!, twoWeeks = cal.date(byAdding: .day, value: -14, to: now)!
        let thisWeek = store.sessions.filter { $0.start >= weekAgo }
        let lastWeek = store.sessions.filter { $0.start >= twoWeeks && $0.start < weekAgo }
        let a = thisWeek.map(\.count).reduce(0, +), b = lastWeek.map(\.count).reduce(0, +)
        if b > 0, a > 0 {
            let pct = Int((Double(a - b) / Double(b) * 100).rounded())
            out.append(Insight(symbol: pct >= 0 ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis", title: "This week",
                               text: pct >= 0 ? "You hit \(a.formatted()) shots, \(pct)% more than last week." : "You hit \(a.formatted()) shots, \(-pct)% fewer than last week.", tone: pct >= 0 ? .good : .info))
        }
        if let top = Dictionary(grouping: thisWeek, by: \.sport).max(by: { $0.value.map(\.count).reduce(0, +) < $1.value.map(\.count).reduce(0, +) }) {
            out.append(Insight(symbol: top.key.symbol, title: "Most played", text: "\(top.key.title) took \(top.value.map(\.count).reduce(0, +).formatted()) of your shots this week.", tone: .info))
        }
        if store.streak >= 2 { out.append(Insight(symbol: "flame.fill", title: "\(store.streak)-day streak", text: "You have played \(store.streak) days in a row. Keep it going.", tone: .good)) }
        return out
    }
}
