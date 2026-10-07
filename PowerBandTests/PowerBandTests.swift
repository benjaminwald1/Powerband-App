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

    @MainActor func testAccountSignOutAndDelete() throws {
        let suite = "pb-account-test-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let account = Account(defaults: defaults, domain: suite)
        XCTAssertNil(account.profile)
        account.create(name: "  Sam ", email: "sam@example.com")
        XCTAssertEqual(account.profile?.name, "Sam")
        XCTAssertTrue(account.signedIn)
        defaults.set(321, forKey: "dailyGoal")

        account.signOut()
        XCTAssertFalse(account.signedIn)
        let reloaded = Account(defaults: defaults, domain: suite)
        XCTAssertEqual(reloaded.profile?.email, "sam@example.com")
        XCTAssertFalse(reloaded.signedIn)
        reloaded.signIn()
        XCTAssertTrue(Account(defaults: defaults, domain: suite).signedIn)

        let store = Store(url: FileManager.default.temporaryDirectory.appendingPathComponent("pb-\(UUID().uuidString).json"), seedDemoData: false)
        store.add(Session(sport: .tennis, start: Date().addingTimeInterval(-60), end: Date(), swings: [SwingGenerator().make(sport: .tennis, at: Date())]))
        XCTAssertEqual(store.totalShots, 1)
        reloaded.deleteAccount(store: store, sensor: SensorManager())
        XCTAssertNil(reloaded.profile)
        XCTAssertEqual(store.totalShots, 0)
        XCTAssertEqual(defaults.integer(forKey: "dailyGoal"), 0)
        XCTAssertNil(Account(defaults: defaults, domain: suite).profile)
    }

    func testAuthHelpers() {
        XCTAssertTrue(AuthService.isValidEmail("sam@example.com"))
        XCTAssertTrue(AuthService.isValidEmail(" sam.c+x@mail.co.uk "))
        XCTAssertFalse(AuthService.isValidEmail("sam@"))
        XCTAssertFalse(AuthService.isValidEmail("sam example.com"))
        XCTAssertFalse(AuthService.isValidEmail(""))
        let n = AuthService.randomNonce()
        XCTAssertEqual(n.count, 32)
        XCTAssertNotEqual(n, AuthService.randomNonce())
        // SHA-256 of "abc"
        XCTAssertEqual(AuthService.sha256("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @MainActor func testAuthValidationAndNotConfiguredBehavior() async throws {
        let auth = AuthService()
        // Validation happens before any network call, so this holds whether or not Firebase is configured.
        let bad = await auth.createAccount(name: "S", email: "nope", password: "x")
        XCTAssertFalse(bad)
        XCTAssertEqual(auth.message, "Enter a valid email address.")
        let short = await auth.createAccount(name: "S", email: "sam@example.com", password: "short")
        XCTAssertFalse(short)
        XCTAssertEqual(auth.message, "Use at least 8 characters for your password.")
        // The "not set up" path only exists when no GoogleService-Info.plist is bundled (a developer machine with Firebase set up skips it).
        try XCTSkipIf(auth.isConfigured, "Firebase is configured in this build")
        let ok = await auth.signIn(email: "sam@example.com", password: "password1")
        XCTAssertFalse(ok)
        XCTAssertEqual(auth.message, AuthService.notConfigured)
    }

    @MainActor func testAccountAdoptsCloudUser() throws {
        let suite = "pb-adopt-\(UUID().uuidString)"
        let d = try XCTUnwrap(UserDefaults(suiteName: suite))
        let account = Account(defaults: d, domain: suite)
        account.create(name: "Local Sam", email: "")
        account.signOut()
        account.adopt(AuthUser(uid: "abc123", name: "Sam Carter", email: "sam@example.com", method: .apple))
        XCTAssertTrue(account.signedIn)
        XCTAssertEqual(account.profile?.authMethod, .apple)
        XCTAssertEqual(account.profile?.uid, "abc123")
        XCTAssertEqual(account.profile?.email, "sam@example.com")
        XCTAssertEqual(Account(defaults: d, domain: suite).profile?.authMethod, .apple)
    }

    func testMovementScore() {
        XCTAssertEqual(MovementStore.score(steps: 0, goal: 8000, activeHours: 0), 0)
        XCTAssertEqual(MovementStore.score(steps: 8000, goal: 8000, activeHours: 8), 100)
        XCTAssertEqual(MovementStore.score(steps: 4000, goal: 8000, activeHours: 4), 50)
        XCTAssertEqual(MovementStore.score(steps: 99999, goal: 8000, activeHours: 20), 100)
    }
}
