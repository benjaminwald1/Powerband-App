import XCTest
@testable import PowerBand

final class PowerBandTests: XCTestCase {
    func testPacketRoundTrip() throws {
        let p = SwingPacket(sport: .tennis, kindIndex: 2, swingMph: 78.4, ballMph: 112.0, spin: 2840, path: 17.5, face: -3.2,
                            impactX: 0.2, impactY: -0.3, tempo: 2.9, force: 0)
        let data = p.encode(timestampMs: 123_456)
        XCTAssertEqual(data.count, SwingPacket.length)
        let back = try XCTUnwrap(SwingPacket.parse(data))
        XCTAssertEqual(back.sport, .tennis)
        XCTAssertEqual(back.kindIndex, 2)
        XCTAssertEqual(back.swingMph, 78.4, accuracy: 0.05)
        XCTAssertEqual(back.ballMph, 112.0, accuracy: 0.05)
        XCTAssertEqual(back.spin, 2840)
        XCTAssertEqual(back.path, 17.5, accuracy: 0.05)
        XCTAssertEqual(back.face, -3.2, accuracy: 0.05)
        XCTAssertEqual(back.impactX, 0.2, accuracy: 0.02)
        XCTAssertEqual(back.impactY, -0.3, accuracy: 0.02)
        XCTAssertEqual(back.tempo, 2.9, accuracy: 0.05)
    }

    func testPacketRejectsShortAndUnknownSport() {
        XCTAssertNil(SwingPacket.parse(Data([1, 2, 3])))
        var d = SwingPacket(sport: .golf, kindIndex: 0, swingMph: 90, ballMph: 130, spin: 2600, path: 0, face: 0, impactX: 0, impactY: 0, tempo: 3, force: 0).encode()
        d[4] = 99
        XCTAssertNil(SwingPacket.parse(d))
    }

    func testGeneratorRanges() {
        let g = SwingGenerator()
        for sport in Sport.allCases {
            for _ in 0..<50 {
                let s = g.make(sport: sport, at: Date())
                XCTAssertGreaterThan(s.swingMph, 0)
                XCTAssertTrue(sport.kinds.contains(s.kind))
                XCTAssertLessThanOrEqual((s.impactX * s.impactX + s.impactY * s.impactY).squareRoot(), 1.0001)
                if sport == .boxing { XCTAssertGreaterThan(s.forceN, 0) }
            }
        }
    }

    func testStoreAggregatesAndPersistence() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("pb-test-\(UUID().uuidString).json")
        let store = Store(url: url, seedDemoData: false)
        XCTAssertEqual(store.totalShots, 0)
        let swings = (0..<40).map { SwingGenerator().make(sport: .tennis, at: Date().addingTimeInterval(Double($0))) }
        store.add(Session(sport: .tennis, start: Date().addingTimeInterval(-60), end: Date(), swings: swings))
        XCTAssertEqual(store.totalShots, 40)
        XCTAssertEqual(store.shotsToday, 40)
        XCTAssertTrue(store.csv().split(separator: "\n").count == 41)
        let reloaded = Store(url: url, seedDemoData: false)
        XCTAssertEqual(reloaded.totalShots, 40)
        reloaded.deleteAll()
        XCTAssertEqual(Store(url: url, seedDemoData: false).totalShots, 0)
    }

    func testStreakInsightsAndAchievements() {
        let store = Store(url: FileManager.default.temporaryDirectory.appendingPathComponent("pb-\(UUID().uuidString).json"), seedDemoData: false)
        XCTAssertEqual(store.streak, 0)
        let cal = Calendar.current
        for back in 0..<4 {
            let day = cal.date(byAdding: .day, value: -back, to: Date())!
            let swings = (0..<60).map { SwingGenerator().make(sport: .tennis, at: day.addingTimeInterval(Double($0))) }
            store.add(Session(sport: .tennis, start: day.addingTimeInterval(-300), end: day, swings: swings))
        }
        XCTAssertEqual(store.streak, 4)
        XCTAssertGreaterThanOrEqual(store.bestStreak, 4)
        let unlocked = Achievements.all.filter { $0.unlocked(store) }.map(\.id)
        XCTAssertTrue(unlocked.contains("first") && unlocked.contains("100") && unlocked.contains("streak3"))
        XCTAssertFalse(unlocked.contains("1k"))
        let tips = InsightEngine.forSession(store.sessions[0], store: store)
        XCTAssertFalse(tips.isEmpty)
        let metric = store.daily(.shots, days: 7, sport: .tennis).compactMap(\.value).reduce(0, +)
        XCTAssertEqual(Int(metric), 240)
    }
}
