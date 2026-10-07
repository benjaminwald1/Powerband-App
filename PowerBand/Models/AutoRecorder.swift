import Foundation
import Observation

extension Sport {
    /// The sport a swing most likely belongs to, from where the sensor is mounted.
    static func guess(for mount: Mount) -> Sport {
        switch mount { case .racquet: .tennis; case .paddle: .pickleball; case .grip: .golf; case .wristBand: .boxing }
    }
}

/// Records sessions with no button press. While a real sensor is connected it listens for swings,
/// starts a session on the first one and saves it after a quiet spell. The Live tab pauses it while
/// the user records manually.
@MainActor @Observable
final class AutoRecorder {
    private(set) var isRecording = false
    /// Set by the Live tab while the user records by hand, so auto-recording leaves the stream alone.
    var manualActive = false
    private(set) var swingCount = 0
    private(set) var lastSaved: Session?
    private var swings: [Swing] = []
    private var idleTask: Task<Void, Never>?
    private weak var store: Store?
    static let quietGap: TimeInterval = 240      // four minutes without a swing ends the session
    static let minimumSwings = 5

    func start(sensor: SensorManager, store: Store, enabled: Bool) {
        self.store = store
        guard enabled, !manualActive, sensor.isConnected, !sensor.usingDemo else { return }
        let sport = Sport.guess(for: sensor.mount)
        sensor.startStream(sport: sport) { [weak self] swing in
            Task { @MainActor in self?.receive(swing) }
        }
    }

    func stop(sensor: SensorManager) {
        finish()
        sensor.stopStream()
    }

    private func receive(_ swing: Swing) {
        swings.append(swing); swingCount = swings.count; isRecording = true
        idleTask?.cancel()
        idleTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.quietGap))
            guard !Task.isCancelled else { return }
            self?.finish()
        }
    }

    /// Saves what has been heard so far, if it adds up to a real session.
    func finish() {
        idleTask?.cancel(); idleTask = nil
        defer { swings = []; swingCount = 0; isRecording = false }
        guard swings.count >= Self.minimumSwings, let first = swings.first, let last = swings.last, let store else { return }
        let s = Session(sport: first.sport, start: first.time, end: max(last.time, first.time.addingTimeInterval(60)), swings: swings)
        store.add(s); lastSaved = s
    }
}
