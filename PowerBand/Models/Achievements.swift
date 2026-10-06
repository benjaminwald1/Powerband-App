import Foundation

struct Achievement: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let unlocked: (Store) -> Bool
}

enum Achievements {
    static let all: [Achievement] = [
        Achievement(id: "first", title: "First shot", detail: "Record your first shot.", symbol: "sparkles") { $0.totalShots >= 1 },
        Achievement(id: "100", title: "Warmed up", detail: "100 total shots.", symbol: "flame") { $0.totalShots >= 100 },
        Achievement(id: "1k", title: "Grinder", detail: "1,000 total shots.", symbol: "flame.fill") { $0.totalShots >= 1_000 },
        Achievement(id: "5k", title: "Machine", detail: "5,000 total shots.", symbol: "bolt.fill") { $0.totalShots >= 5_000 },
        Achievement(id: "multi", title: "Multi-sport", detail: "Play 3 different sports.", symbol: "square.grid.3x3.fill") { Set($0.sessions.map(\.sport)).count >= 3 },
        Achievement(id: "streak3", title: "On a roll", detail: "Play 3 days in a row.", symbol: "calendar") { $0.streak >= 3 || $0.bestStreak >= 3 },
        Achievement(id: "streak7", title: "Locked in", detail: "Play 7 days in a row.", symbol: "calendar.badge.checkmark") { $0.bestStreak >= 7 },
        Achievement(id: "sweet", title: "Sweet-spot sniper", detail: "80% sweet-spot contact over 30+ shots.", symbol: "scope") { $0.sessions.contains { $0.count >= 30 && $0.sport.hasFace && $0.sweetSpotRate >= 0.8 } },
        Achievement(id: "100mph", title: "100 mph club", detail: "A ball speed of 100 mph or more.", symbol: "speedometer") { $0.bestBall >= 100 },
        Achievement(id: "spin", title: "Spin doctor", detail: "3,000 rpm or more of spin.", symbol: "tornado") { $0.bestSpin >= 3_000 },
        Achievement(id: "heavy", title: "Heavy hitter", detail: "A punch of 1,500 N or more.", symbol: "figure.boxing") { $0.bestForce >= 1_500 },
        Achievement(id: "marathon", title: "Marathon", detail: "A session of an hour or longer.", symbol: "timer") { $0.sessions.contains { $0.duration >= 3_600 } },
    ]
}
