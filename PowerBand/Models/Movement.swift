import Foundation
import CoreMotion
import Observation

struct DayStat: Identifiable, Hashable {
    let date: Date
    let steps: Int
    var id: Date { date }
}

/// All-day movement from the iPhone's motion coprocessor (steps, distance, active hours).
/// Nothing leaves the device.
@MainActor @Observable
final class MovementStore {
    private let pedometer = CMPedometer()
    private(set) var steps = 0
    private(set) var distanceMeters = 0.0
    private(set) var activeHours = 0
    private(set) var week: [DayStat] = []
    private(set) var lastMovedAt: Date?
    private(set) var loaded = false

    var available: Bool { CMPedometer.isStepCountingAvailable() }
    var denied: Bool { [.denied, .restricted].contains(CMPedometer.authorizationStatus()) }

    nonisolated static func score(steps: Int, goal: Int, activeHours: Int) -> Int {
        let s = min(1, Double(steps) / Double(max(goal, 1)))
        let a = min(1, Double(activeHours) / 8)
        return Int((s * 70 + a * 30).rounded())
    }

    /// Walking energy, about 0.9 kcal per kg per km. Uses the phone's distance, or steps at 0.75 m each.
    func walkingCalories(weightKg: Double) -> Double {
        let km = distanceMeters > 0 ? distanceMeters / 1000 : Double(steps) * 0.00075
        return km * weightKg * 0.9
    }

    func score(goal: Int) -> Int { Self.score(steps: steps, goal: goal, activeHours: activeHours) }

    /// Minutes since the last step, or nil when unknown.
    var minutesStill: Int? {
        guard let t = lastMovedAt else { return nil }
        return max(0, Int(Date().timeIntervalSince(t) / 60))
    }

    func refresh() async {
        guard available, !denied else { loaded = true; return }
        let cal = Calendar.current, now = Date()
        let start = cal.startOfDay(for: now)
        if let d = await query(start, now) { steps = d.numberOfSteps.intValue; distanceMeters = d.distance?.doubleValue ?? 0 }

        var hours = 0, last: Date?
        let hourNow = cal.component(.hour, from: now)
        for h in 0...hourNow {
            guard let a = cal.date(byAdding: .hour, value: h, to: start) else { continue }
            let b = min(now, cal.date(byAdding: .hour, value: h + 1, to: start) ?? now)
            if let n = (await query(a, b))?.numberOfSteps.intValue {
                if n >= 250 { hours += 1 }
                if n > 0 { last = b }
            }
        }
        activeHours = hours; lastMovedAt = last

        var days: [DayStat] = []
        for i in (0..<7).reversed() {
            guard let d0 = cal.date(byAdding: .day, value: -i, to: start), let d1 = cal.date(byAdding: .day, value: 1, to: d0) else { continue }
            let n = (await query(d0, min(d1, now)))?.numberOfSteps.intValue ?? 0
            days.append(DayStat(date: d0, steps: n))
        }
        week = days
        loaded = true
    }

    private func query(_ a: Date, _ b: Date) async -> CMPedometerData? {
        guard a < b else { return nil }
        return await withCheckedContinuation { c in
            pedometer.queryPedometerData(from: a, to: b) { data, _ in c.resume(returning: data) }
        }
    }
}
