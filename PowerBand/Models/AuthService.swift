import Foundation
import Observation
import AuthenticationServices
import CryptoKit
#if canImport(FirebaseAuth)
import FirebaseAuth
import FirebaseCore
#endif

enum AuthMethod: String, Codable {
    case local, apple, google, email
    var title: String {
        switch self { case .local: "On this phone"; case .apple: "Apple"; case .google: "Google"; case .email: "Email and password" }
    }
    var symbol: String {
        switch self { case .local: "iphone"; case .apple: "apple.logo"; case .google: "globe"; case .email: "envelope.fill" }
    }
}

struct AuthUser: Equatable {
    var uid: String
    var name: String
    var email: String
    var method: AuthMethod
}

enum ReauthMethod {
    case password(String)
    case apple(Result<ASAuthorization, Error>)
    case google
}

/// Sign in with Apple, Google and email/password through Firebase Authentication.
/// When `GoogleService-Info.plist` isn't bundled the service reports `isConfigured == false` and the app uses the on-device profile only.
@Observable
@MainActor
final class AuthService: NSObject {
    private(set) var user: AuthUser?
    var busy = false
    var message: String?
    var info: String?

    @ObservationIgnored private var nonce: String?

    static var hasConfigFile: Bool { Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil }

    var isConfigured: Bool {
        #if canImport(FirebaseAuth)
        return FirebaseApp.app() != nil
        #else
        return false
        #endif
    }

    override init() {
        super.init()
        #if canImport(FirebaseAuth)
        if Self.hasConfigFile, FirebaseApp.app() == nil { FirebaseApp.configure() }
        if isConfigured, let u = Auth.auth().currentUser { user = Self.map(u) }
        #endif
    }

    // MARK: Email and password

    nonisolated static func isValidEmail(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespaces)
        return t.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]{2,}$"#, options: .regularExpression) != nil
    }

    func signIn(email: String, password: String) async -> Bool {
        guard validate(email: email, password: password, creating: false) else { return false }
        return await run { [self] in
            #if canImport(FirebaseAuth)
            let r = try await Auth.auth().signIn(withEmail: email.trimmingCharacters(in: .whitespaces), password: password)
            user = Self.map(r.user)
            #endif
        }
    }

    func createAccount(name: String, email: String, password: String) async -> Bool {
        guard validate(email: email, password: password, creating: true) else { return false }
        return await run { [self] in
            #if canImport(FirebaseAuth)
            let r = try await Auth.auth().createUser(withEmail: email.trimmingCharacters(in: .whitespaces), password: password)
            let n = name.trimmingCharacters(in: .whitespaces)
            if !n.isEmpty { let c = r.user.createProfileChangeRequest(); c.displayName = n; try await c.commitChanges() }
            try? await r.user.sendEmailVerification()
            user = Self.map(Auth.auth().currentUser ?? r.user)
            info = "We sent a verification link to \(email.trimmingCharacters(in: .whitespaces))."
            #endif
        }
    }

    func sendPasswordReset(email: String) async {
        guard Self.isValidEmail(email) else { message = "Enter your email above first."; return }
        _ = await run { [self] in
            #if canImport(FirebaseAuth)
            try await Auth.auth().sendPasswordReset(withEmail: email.trimmingCharacters(in: .whitespaces))
            info = "If an account exists for that email, a reset link is on its way."
            #endif
        }
    }

    private func validate(email: String, password: String, creating: Bool) -> Bool {
        message = nil
        guard Self.isValidEmail(email) else { message = "Enter a valid email address."; return false }
        guard password.count >= (creating ? 8 : 1) else { message = creating ? "Use at least 8 characters for your password." : "Enter your password."; return false }
        guard isConfigured else { message = Self.notConfigured; return false }
        return true
    }

    // MARK: Apple

    nonisolated static func randomNonce(length: Int = 32) -> String {
        let chars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String((0..<length).map { _ in chars.randomElement()! })
    }

    nonisolated static func sha256(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    func prepareApple(_ request: ASAuthorizationAppleIDRequest) {
        let n = Self.randomNonce(); nonce = n
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(n)
    }

    func completeApple(_ result: Result<ASAuthorization, Error>) async -> Bool {
        message = nil
        guard isConfigured else { message = Self.notConfigured; return false }
        return await run { [self] in
            #if canImport(FirebaseAuth)
            let cred = try await Self.appleCredential(from: result, nonce: nonce)
            let r = try await Auth.auth().signIn(with: cred)
            user = Self.map(r.user)
            #endif
        }
    }

    #if canImport(FirebaseAuth)
    private static func appleCredential(from result: Result<ASAuthorization, Error>, nonce: String?) async throws -> AuthCredential {
        let auth = try result.get()
        guard let c = auth.credential as? ASAuthorizationAppleIDCredential, let tokenData = c.identityToken,
              let token = String(data: tokenData, encoding: .utf8), let nonce else { throw NSError(domain: "PowerBand", code: 1, userInfo: [NSLocalizedDescriptionKey: "Apple didn't return a sign-in token."]) }
        return OAuthProvider.appleCredential(withIDToken: token, rawNonce: nonce, fullName: c.fullName)
    }
    #endif

    // MARK: Google

    func signInWithGoogle() async -> Bool {
        message = nil
        guard isConfigured else { message = Self.notConfigured; return false }
        return await run { [self] in
            #if canImport(FirebaseAuth)
            let cred = try await Self.googleCredential()
            let r = try await Auth.auth().signIn(with: cred)
            user = Self.map(r.user)
            #endif
        }
    }

    #if canImport(FirebaseAuth)
    private static func googleCredential() async throws -> AuthCredential {
        let provider = OAuthProvider(providerID: "google.com")
        provider.scopes = ["email", "profile"]
        provider.customParameters = ["prompt": "select_account"]
        return try await provider.credential(with: nil)
    }
    #endif

    // MARK: Sign out and delete

    func signOut() {
        #if canImport(FirebaseAuth)
        if isConfigured { try? Auth.auth().signOut() }
        #endif
        user = nil; message = nil; info = nil
    }

    /// Deletes the cloud account. Re-authenticates first (Firebase requires a recent sign-in) and revokes the Apple token when needed.
    func deleteAccount(reauth: ReauthMethod?) async -> Bool {
        message = nil
        #if canImport(FirebaseAuth)
        guard isConfigured, let u = Auth.auth().currentUser else { return true }   // nothing in the cloud to delete
        return await run { [self] in
            switch reauth {
            case .password(let p)?:
                try await u.reauthenticate(with: EmailAuthProvider.credential(withEmail: u.email ?? "", password: p))
            case .apple(let result)?:
                let cred = try await Self.appleCredential(from: result, nonce: nonce)
                try await u.reauthenticate(with: cred)
                if case .success(let a) = result, let c = a.credential as? ASAuthorizationAppleIDCredential, let code = c.authorizationCode.flatMap({ String(data: $0, encoding: .utf8) }) {
                    try await Auth.auth().revokeToken(withAuthorizationCode: code)
                }
            case .google?:
                try await u.reauthenticate(with: try await Self.googleCredential())
            case nil: break
            }
            try await u.delete()
            user = nil
        }
        #else
        return true
        #endif
    }

    // MARK: Helpers

    nonisolated static let notConfigured = "Sign-in isn't set up in this build yet. Continue without an account for now."

    private func run(_ work: @escaping () async throws -> Void) async -> Bool {
        busy = true; defer { busy = false }
        do { try await work(); return true }
        catch { message = Self.friendly(error); return false }
    }

    nonisolated static func friendly(_ error: Error) -> String {
        let ns = error as NSError
        #if canImport(FirebaseAuth)
        if ns.domain == AuthErrorDomain, let code = AuthErrorCode(rawValue: ns.code) {
            switch code {
            case .wrongPassword, .invalidCredential, .userNotFound: return "That email and password don't match an account."
            case .emailAlreadyInUse: return "An account with that email already exists. Try signing in."
            case .weakPassword: return "Choose a stronger password (at least 8 characters)."
            case .invalidEmail: return "That email address doesn't look right."
            case .networkError: return "No connection. Check your internet and try again."
            case .tooManyRequests: return "Too many attempts. Wait a moment and try again."
            case .requiresRecentLogin: return "For your security, confirm it's you and try again."
            case .webContextCancelled: return "Sign-in was cancelled."
            case .userDisabled: return "This account has been disabled. Contact support."
            default: break
            }
        }
        #endif
        if ns.domain == ASAuthorizationError.errorDomain, ns.code == ASAuthorizationError.canceled.rawValue { return "Sign-in was cancelled." }
        return ns.localizedDescription
    }

    #if canImport(FirebaseAuth)
    private static func map(_ u: User) -> AuthUser {
        let provider = u.providerData.first?.providerID ?? "password"
        let method: AuthMethod = provider == "apple.com" ? .apple : provider == "google.com" ? .google : .email
        return AuthUser(uid: u.uid, name: u.displayName ?? "", email: u.email ?? "", method: method)
    }
    #endif
}
