import Foundation

/// Produces realistic swings. Used by the simulated sensor and to seed demo history.
struct SwingGenerator {
    var fatigue: Double = 0   // 0...1, slows swings late in a long session

    static func gauss(_ mean: Double, _ sd: Double) -> Double {
        // Box-Muller
        let u1 = Double.random(in: 0.0001...1), u2 = Double.random(in: 0...1)
        return mean + sd * (-2 * log(u1)).squareRoot() * cos(2 * .pi * u2)
    }

    func make(sport: Sport, at date: Date) -> Swing {
        let kind = sport.kinds.randomElement()!
        let tire = 1 - 0.07 * fatigue
        var speed: Double, ball: Double, spin: Int, path: Double, force = 0.0

        switch sport {
        case .tennis:
            let base: Double = kind == "Serve" ? 92 : kind == "Volley" ? 48 : 68
            speed = Self.gauss(base, 7) * tire
            ball = speed * Self.gauss(1.3, 0.05)
            spin = Int(Self.gauss(kind == "Serve" ? 2300 : 2700, 380))
            path = Self.gauss(kind == "Backhand" ? 14 : 18, 4)
        case .pickleball:
            let base: Double = kind == "Dink" ? 20 : kind == "Drive" ? 52 : 44
            speed = Self.gauss(base, 5) * tire
            ball = speed * Self.gauss(1.1, 0.05)
            spin = Int(Self.gauss(1000, 260))
            path = Self.gauss(kind == "Dink" ? 8 : 12, 3)
        case .padel:
            let base: Double = kind == "Smash" ? 70 : kind == "Bandeja" ? 38 : 48
            speed = Self.gauss(base, 6) * tire
            ball = speed * Self.gauss(1.15, 0.05)
            spin = Int(Self.gauss(kind == "Bandeja" ? 1800 : 1500, 300))
            path = Self.gauss(10, 4)
        case .golf:
            let base: Double = kind == "Driver" ? 98 : kind == "Iron" ? 82 : 66
            speed = Self.gauss(base, 5) * tire
            ball = speed * Self.gauss(1.45, 0.04)
            spin = Int(Self.gauss(kind == "Driver" ? 2600 : kind == "Iron" ? 6200 : 8800, 500))
            path = Self.gauss(kind == "Driver" ? -2 : 3, 2.5)
        case .boxing:
            let base: Double = kind == "Jab" ? 21 : kind == "Cross" ? 25 : kind == "Hook" ? 23 : 19
            speed = Self.gauss(base, 2.2) * tire
            ball = 0; spin = 0
            path = Self.gauss(0, 6)
            force = Self.gauss(kind == "Cross" ? 1450 : kind == "Hook" ? 1300 : 900, 160) * tire
        }

        // Where the ball met the face: tight cluster a little off centre.
        var ix = Self.gauss(0.04, 0.26), iy = Self.gauss(-0.05, 0.26)
        let r = (ix * ix + iy * iy).squareRoot()
        if r > 0.95 { ix *= 0.95 / r; iy *= 0.95 / r }

        return Swing(time: date, sport: sport, kind: kind, swingMph: max(speed, 5), ballMph: max(ball, 0), spinRpm: max(spin, 0),
                     pathDeg: path, faceDeg: Self.gauss(-2, 3), impactX: sport.hasFace ? ix : 0, impactY: sport.hasFace ? iy : 0,
                     tempo: Self.gauss(2.9, 0.25), forceN: max(force, 0))
    }
}

enum DemoData {
    /// A believable month of play so the app is not empty on first launch.
    static func history(days: Int) -> [Session] {
        let cal = Calendar.current
        var out: [Session] = []
        for back in 0..<days {
            guard Double.random(in: 0...1) < (back == 0 ? 1 : 0.62) else { continue }
            let day = cal.date(byAdding: .day, value: -back, to: Date())!
            let sessionsToday = back == 0 ? 2 : Int.random(in: 1...2)
            for n in 0..<sessionsToday {
                let sport: Sport = back == 0 ? (n == 0 ? .tennis : .golf) : Sport.allCases.randomElement()!
                let count = sport == .golf ? Int.random(in: 30...60) : sport == .boxing ? Int.random(in: 150...300) : Int.random(in: 120...260)
                var start = cal.date(bySettingHour: n == 0 ? 8 : 17, minute: Int.random(in: 0...40), second: 0, of: day)!
                if back == 0, start > Date() { start = Date().addingTimeInterval(-Double(count) * 14 - 600) }
                let gapRange: ClosedRange<Double> = sport == .golf ? 60...150 : 8...22
                var t = start
                var swings: [Swing] = []
                for i in 0..<count {
                    t = t.addingTimeInterval(.random(in: gapRange))
                    swings.append(SwingGenerator(fatigue: Double(i) / Double(count)).make(sport: sport, at: t))
                }
                out.append(Session(sport: sport, start: start, end: t, swings: swings))
            }
        }
        return out.sorted { $0.start > $1.start }
    }
}
