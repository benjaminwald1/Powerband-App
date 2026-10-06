import Foundation
import Observation

struct Profile: Codable, Equatable {
    var id = UUID()
    var name: String
    var email: String
    var createdAt = Date()
    var initial: String { String(name.trimmingCharacters(in: .whitespaces).first ?? "A").uppercased() }
}

/// The on-device account. There is no server: the profile, sign-in state and all data live on this phone.
@Observable
final class Account {
    private(set) var profile: Profile?
    private(set) var signedIn: Bool

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let domain: String
    private enum Keys { static let profile = "account.profile", signedIn = "account.signedIn" }

    init(defaults: UserDefaults = .standard, domain: String = Bundle.main.bundleIdentifier ?? "com.benjaminwald.powerband") {
        self.defaults = defaults
        self.domain = domain
        if let data = defaults.data(forKey: Keys.profile), let p = try? JSONDecoder().decode(Profile.self, from: data) {
            profile = p
            signedIn = defaults.bool(forKey: Keys.signedIn)
        } else {
            profile = nil
            signedIn = false
        }
    }

    func create(name: String, email: String) {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        profile = Profile(name: n.isEmpty ? "Athlete" : n, email: email.trimmingCharacters(in: .whitespacesAndNewlines))
        signedIn = true
        persist()
    }

    func update(name: String, email: String) {
        guard var p = profile else { return }
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !n.isEmpty { p.name = n }
        p.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        profile = p
        persist()
    }

    /// Returns to the sign-in screen. Sessions stay on the phone and are there again after signing back in.
    func signOut() { signedIn = false; persist() }
    func signIn() { guard profile != nil else { return }; signedIn = true; persist() }

    /// Permanently removes the profile, every session and every setting from this phone.
    @MainActor func deleteAccount(store: Store, sensor: SensorManager) {
        sensor.disconnect(forget: true)
        store.deleteAll()
        defaults.removePersistentDomain(forName: domain)
        profile = nil
        signedIn = false
    }

    private func persist() {
        if let p = profile, let data = try? JSONEncoder().encode(p) { defaults.set(data, forKey: Keys.profile) }
        defaults.set(signedIn, forKey: Keys.signedIn)
    }
}
