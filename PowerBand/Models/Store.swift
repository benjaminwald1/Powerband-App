import Foundation
import Observation

/// App-wide data store. Sessions live in a JSON file on the device and are never uploaded anywhere.
@Observable
final class Store {
    var sessions: [Session] = []
    private let url: URL

    init(url: URL? = nil, seedDemoData: Bool = true) {
        self.url = url ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("sessions.json")
        if let data = try? Data(contentsOf: self.url), let decoded = try? JSONDecoder.iso.decode([Session].self, from: data) {
            sessions = decoded
        } else if seedDemoData {
            sessions = DemoData.history(days: 30)
            save()
        }
    }

    func add(_ session: Session) {
        guard session.count > 0 else { return }
        sessions.insert(session, at: 0)
        sessions.sort { $0.start > $1.start }
        save()
    }

    func delete(_ session: Session) {
        sessions.removeAll { $0.id == session.id }
        save()
    }

    func deleteAll() {
        sessions = []
        save()
    }

    func loadDemoData() {
        sessions = DemoData.history(days: 30)
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder.iso.encode(sessions) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: Aggregates

    private var cal: Calendar { .current }
    var todaySessions: [Session] { sessions.filter { cal.isDateInToday($0.start) } }
    var shotsToday: Int { todaySessions.map(\.count).reduce(0, +) }
    var totalShots: Int { sessions.map(\.count).reduce(0, +) }
    var shotsYesterday: Int { sessions.filter { cal.isDateInYesterday($0.start) }.map(\.count).reduce(0, +) }
    var averageDailyShots: Int {
        let days = Set(sessions.map { cal.startOfDay(for: $0.start) }).count
        return days == 0 ? 0 : totalShots / days
    }

    var bestSwing: Double { sessions.map(\.maxSpeed).max() ?? 0 }
    var bestBall: Double { sessions.map(\.maxBall).max() ?? 0 }
    var bestSpin: Int { sessions.flatMap(\.swings).map(\.spinRpm).max() ?? 0 }
    var bestForce: Double { sessions.map(\.maxForce).max() ?? 0 }

    var lastSession: Session? { sessions.first }
    /// Sessions shown on the overview: today's, or the latest if nothing has been played today.
    var featured: [Session] { todaySessions.isEmpty ? Array(sessions.prefix(2)) : todaySessions }

    /// Today's speed vs your personal best, 0...1.
    var power: Double {
        guard let s = featured.first, bestSwing > 0 else { return 0 }
        return min(1, s.avgSpeed / bestSwing * 1.18)
    }
    var load: Double { min(21, featured.map(\.load).reduce(0, +)) }
    var form: Double { featured.first?.consistency ?? 0 }

    func dailyShots(days: Int) -> [(date: Date, count: Int)] {
        let today = cal.startOfDay(for: Date())
        return (0..<days).reversed().map { offset in
            let d = cal.date(byAdding: .day, value: -offset, to: today)!
            let c = sessions.filter { cal.isDate($0.start, inSameDayAs: d) }.map(\.count).reduce(0, +)
            return (d, c)
        }
    }

    func recentSpeeds(for sport: Sport? = nil, limit: Int = 24) -> [(index: Int, mph: Double)] {
        let pool = sport.map { s in sessions.filter { $0.sport == s } } ?? sessions
        let swings = pool.prefix(4).reversed().flatMap { $0.swings.sorted { $0.time < $1.time } }
        let tail = Array(swings.suffix(limit * 10))
        let step = max(1, tail.count / limit)
        var out: [(Int, Double)] = []
        var i = 0
        var idx = 0
        while i < tail.count {
            let chunk = tail[i..<min(i + step, tail.count)]
            out.append((idx, chunk.map(\.swingMph).reduce(0, +) / Double(chunk.count)))
            idx += 1; i += step
        }
        return out
    }

    func sportBreakdown() -> [(sport: Sport, shots: Int)] {
        Sport.allCases.map { s in (s, sessions.filter { $0.sport == s }.map(\.count).reduce(0, +)) }.filter { $0.1 > 0 }
    }

    func csv() -> String {
        var rows = ["time,sport,kind,swing_mph,ball_mph,spin_rpm,path_deg,face_deg,impact_x,impact_y,tempo,force_n"]
        let f = ISO8601DateFormatter()
        for s in sessions.reversed() {
            for w in s.swings.sorted(by: { $0.time < $1.time }) {
                rows.append([f.string(from: w.time), w.sport.rawValue, w.kind, String(format: "%.1f", w.swingMph), String(format: "%.1f", w.ballMph), "\(w.spinRpm)", String(format: "%.1f", w.pathDeg), String(format: "%.1f", w.faceDeg), String(format: "%.2f", w.impactX), String(format: "%.2f", w.impactY), String(format: "%.2f", w.tempo), String(format: "%.0f", w.forceN)].joined(separator: ","))
            }
        }
        return rows.joined(separator: "\n")
    }
}

extension JSONEncoder {
    static var iso: JSONEncoder { let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e }
}
extension JSONDecoder {
    static var iso: JSONDecoder { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }
}
