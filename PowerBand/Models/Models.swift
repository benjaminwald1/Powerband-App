import Foundation

enum Sport: String, Codable, CaseIterable, Identifiable {
    case tennis, pickleball, padel, golf, boxing
    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .tennis: return "tennisball.fill"
        case .pickleball: return "figure.pickleball"
        case .padel: return "figure.racquetball"
        case .golf: return "figure.golf"
        case .boxing: return "figure.boxing"
        }
    }
    var speedLabel: String {
        switch self {
        case .golf: return "Club speed"
        case .boxing: return "Hand speed"
        default: return "Swing speed"
        }
    }
    /// Metabolic equivalent (MET) of the sport, from the Compendium of Physical Activities.
    var met: Double {
        switch self { case .tennis: 7.3; case .pickleball: 6.0; case .padel: 6.0; case .golf: 4.8; case .boxing: 7.8 }
    }
    var mount: Mount {
        switch self {
        case .tennis: return .racquet
        case .pickleball, .padel: return .paddle
        case .golf: return .grip
        case .boxing: return .wristBand
        }
    }
    /// Racquet and paddle sports measure where the ball met the face.
    var hasFace: Bool { self == .tennis || self == .pickleball || self == .padel }
    var kinds: [String] {
        switch self {
        case .tennis: return ["Forehand", "Backhand", "Serve", "Volley"]
        case .pickleball: return ["Drive", "Dink", "Serve", "Volley"]
        case .padel: return ["Bandeja", "Vibora", "Smash", "Forehand"]
        case .golf: return ["Driver", "Iron", "Wedge"]
        case .boxing: return ["Jab", "Cross", "Hook", "Uppercut"]
        }
    }
}

enum Mount: String, Codable, CaseIterable, Identifiable {
    case racquet = "Racquet strings", paddle = "Paddle grip band", grip = "Club grip", wristBand = "Wrist band"
    var id: String { rawValue }
}

struct Swing: Codable, Identifiable, Hashable {
    var id = UUID()
    var time: Date
    var sport: Sport
    var kind: String
    var swingMph: Double          // racquet / club / hand speed
    var ballMph: Double           // ball speed (0 for boxing)
    var spinRpm: Int
    var pathDeg: Double           // low-to-high swing path angle
    var faceDeg: Double           // face angle at contact, negative = closed
    var impactX: Double           // -1...1 across the face
    var impactY: Double           // -1...1 along the face
    var tempo: Double             // backswing : downswing ratio
    var forceN: Double            // punch force in newtons (boxing)

    var isSweetSpot: Bool { (impactX * impactX + impactY * impactY).squareRoot() < 0.32 }
}

struct Session: Codable, Identifiable, Hashable {
    var id = UUID()
    var sport: Sport
    var start: Date
    var end: Date
    var swings: [Swing]

    var count: Int { swings.count }
    var duration: TimeInterval { max(end.timeIntervalSince(start), 1) }
    var avgSpeed: Double { swings.isEmpty ? 0 : swings.map(\.swingMph).reduce(0, +) / Double(count) }
    var maxSpeed: Double { swings.map(\.swingMph).max() ?? 0 }
    var maxBall: Double { swings.map(\.ballMph).max() ?? 0 }
    var avgSpin: Int { swings.isEmpty ? 0 : swings.map(\.spinRpm).reduce(0, +) / count }
    var avgPath: Double { swings.isEmpty ? 0 : swings.map(\.pathDeg).reduce(0, +) / Double(count) }
    var avgFace: Double { swings.isEmpty ? 0 : swings.map(\.faceDeg).reduce(0, +) / Double(count) }
    var avgTempo: Double { swings.isEmpty ? 0 : swings.map(\.tempo).reduce(0, +) / Double(count) }
    var maxForce: Double { swings.map(\.forceN).max() ?? 0 }
    var sweetSpotRate: Double { swings.isEmpty ? 0 : Double(swings.filter(\.isSweetSpot).count) / Double(count) }
    /// Calories burned above gentle walking, which the all-day step count already covers,
    /// so a day's sport and lifestyle totals add up without double counting.
    func extraCalories(weightKg: Double) -> Double {
        max(0, (sport.met - 3.0) * weightKg * duration / 3600)
    }
    /// Calories for the whole session including the walking-level baseline.
    func totalCalories(weightKg: Double) -> Double { sport.met * weightKg * duration / 3600 }
    /// 0...21 workload score, like a daily strain number.
    var load: Double { 21 * (1 - exp(-Double(count) / 150)) }

    /// 0...1: how repeatable the speed was (lower variance is better).
    var consistency: Double {
        guard count > 2 else { return 0.8 }
        let m = avgSpeed
        let v = swings.map { pow($0.swingMph - m, 2) }.reduce(0, +) / Double(count)
        return max(0.4, min(0.99, 1 - v.squareRoot() / max(m, 1) * 1.6))
    }
}
