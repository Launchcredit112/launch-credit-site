import Foundation
import CryptoKit
import LocalAuthentication

enum AuthError: LocalizedError, Equatable {
    case invalidEmail
    case weakPassword
    case wrongCredentials
    case accountExists
    case noAccount
    case biometricsUnavailable
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .invalidEmail:          return "Enter a valid email address."
        case .weakPassword:          return "Use at least 8 characters, including a number."
        case .wrongCredentials:      return "That email and password don't match."
        case .accountExists:         return "There's already an account with that email."
        case .noAccount:             return "No account on this device yet — create one to get started."
        case .biometricsUnavailable: return "Face ID isn't available on this device."
        case .failed(let message):   return message
        }
    }
}

protocol AuthServicing {
    func signIn(email: String, password: String) async throws -> User
    func signUp(firstName: String, lastName: String, email: String, password: String) async throws -> User
    func signInWithBiometrics() async throws -> User
    func restoreSession() -> User?
    func signOut()
    var hasStoredAccount: Bool { get }
    var storedEmail: String? { get }
}

// MARK: - Validation, shared by sign-in, sign-up and onboarding

enum Validate {
    static func email(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard !trimmed.contains(" "), let at = trimmed.firstIndex(of: "@"), at != trimmed.startIndex else { return false }
        let domain = trimmed[trimmed.index(after: at)...]
        guard !domain.contains("@"), let dot = domain.lastIndex(of: "."), dot != domain.startIndex else { return false }
        return domain[domain.index(after: dot)...].count >= 2
    }

    static func password(_ value: String) -> Bool {
        value.count >= 8 && value.rangeOfCharacter(from: .decimalDigits) != nil
    }

    static func name(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespaces).count >= 2
    }
}

// MARK: - Local account store

/// Signs members in against a device-local account.
///
/// The password itself is never stored — only a salted, stretched SHA-256
/// digest, held in the keychain. Point every call site at `AuthServicing`, so
/// this can be swapped for the real Launch API without touching the views.
final class LocalAuthService: AuthServicing {

    private struct StoredAccount: Codable {
        var user: User
        var salt: Data
        var digest: Data
    }

    private let accountKey = "account.v1"

    var hasStoredAccount: Bool { storedAccount != nil }

    var storedEmail: String? { storedAccount?.user.email }

    private var storedAccount: StoredAccount? { Keychain.load(StoredAccount.self, for: accountKey) }

    func signUp(firstName: String, lastName: String, email: String, password: String) async throws -> User {
        let email = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard Validate.email(email) else { throw AuthError.invalidEmail }
        guard Validate.password(password) else { throw AuthError.weakPassword }
        if let existing = storedAccount, existing.user.email == email { throw AuthError.accountExists }

        let salt = Self.randomSalt()
        let digest = await Self.digest(password: password, salt: salt)
        let user = User(
            id: UUID().uuidString,
            firstName: firstName.trimmingCharacters(in: .whitespaces),
            lastName: lastName.trimmingCharacters(in: .whitespaces),
            email: email,
            phone: nil,
            joinedAt: Date()
        )
        Keychain.store(StoredAccount(user: user, salt: salt, digest: digest), for: accountKey)
        Session.markSignedIn(true)
        return user
    }

    func signIn(email: String, password: String) async throws -> User {
        let email = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard Validate.email(email) else { throw AuthError.invalidEmail }
        guard let account = storedAccount else { throw AuthError.noAccount }

        let candidate = await Self.digest(password: password, salt: account.salt)
        // Constant-time comparison: never leak how much of the digest matched.
        let digestsMatch = candidate.count == account.digest.count
            && zip(candidate, account.digest).reduce(UInt8(0)) { $0 | ($1.0 ^ $1.1) } == 0

        guard account.user.email == email, digestsMatch else { throw AuthError.wrongCredentials }
        Session.markSignedIn(true)
        return account.user
    }

    func signInWithBiometrics() async throws -> User {
        guard let account = storedAccount else { throw AuthError.noAccount }

        let context = LAContext()
        context.localizedFallbackTitle = "Use password"
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            throw AuthError.biometricsUnavailable
        }

        let approved: Bool = try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlock Launch") { success, error in
                if success {
                    continuation.resume(returning: true)
                } else if let error {
                    continuation.resume(throwing: AuthError.failed(error.localizedDescription))
                } else {
                    continuation.resume(returning: false)
                }
            }
        }
        guard approved else { throw AuthError.wrongCredentials }
        Session.markSignedIn(true)
        return account.user
    }

    func restoreSession() -> User? {
        guard Session.isSignedIn else { return nil }
        return storedAccount?.user
    }

    func signOut() {
        Session.markSignedIn(false)
    }

    /// Wipes the account entirely — backs "Delete account" in Settings.
    func eraseAccount() {
        Keychain.remove(accountKey)
        Session.markSignedIn(false)
    }

    // MARK: - Hashing

    private static func randomSalt() -> Data {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }

    /// Salted SHA-256, stretched so a stolen keychain item is not trivially
    /// brute-forced. Runs off the main actor — the stretch takes real time.
    private static func digest(password: String, salt: Data) async -> Data {
        await Task.detached(priority: .userInitiated) {
            var input = salt
            input.append(Data(password.utf8))
            var out = Data(SHA256.hash(data: input))
            for _ in 0..<50_000 {
                var round = salt
                round.append(out)
                out = Data(SHA256.hash(data: round))
            }
            return out
        }.value
    }
}

/// Whether a session is open. Not sensitive by itself, so defaults is fine —
/// the account it points at still lives behind the keychain.
enum Session {
    private static let key = "launch.session.signedIn"
    static var isSignedIn: Bool { UserDefaults.standard.bool(forKey: key) }
    static func markSignedIn(_ value: Bool) { UserDefaults.standard.set(value, forKey: key) }
}
