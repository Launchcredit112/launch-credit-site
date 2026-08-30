import Foundation
import CryptoKit

enum AuthError: LocalizedError, Equatable {
    case invalidEmail
    case weakPassword
    case wrongCredentials
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .invalidEmail:        return "Enter a valid email address."
        case .weakPassword:        return "Use at least 8 characters, including a number."
        case .wrongCredentials:    return "That email and password don't match."
        case .failed(let message): return message
        }
    }
}

protocol AuthServicing {
    func signIn(email: String, password: String) async throws -> User
    func restoreSession() -> User?
    func signOut()
    var storedEmail: String? { get }
}

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
}

/// Signs members in against a device-local account.
///
/// Accounts are created on the web, where the checkout collects the identity
/// and consents the credit partner needs — so the app only ever signs in. This
/// is a stand-in for that API: the first sign-in on a device provisions the
/// member from the email given, and every sign-in after that is checked
/// against it. Point `AuthServicing` at the real endpoint and no view changes.
///
/// The password itself is never stored — only a salted, stretched SHA-256
/// digest, held in the keychain and compared in constant time.
final class LocalAuthService: AuthServicing {

    private struct StoredAccount: Codable {
        var user: User
        var salt: Data
        var digest: Data
    }

    private let accountKey = "account.v1"

    var storedEmail: String? { storedAccount?.user.email }

    private var storedAccount: StoredAccount? { Keychain.load(StoredAccount.self, for: accountKey) }

    func signIn(email: String, password: String) async throws -> User {
        let email = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard Validate.email(email) else { throw AuthError.invalidEmail }
        guard Validate.password(password) else { throw AuthError.weakPassword }

        if let account = storedAccount, account.user.email == email {
            let candidate = await Self.digest(password: password, salt: account.salt)
            guard Self.constantTimeEquals(candidate, account.digest) else { throw AuthError.wrongCredentials }
            Session.markSignedIn(true)
            return account.user
        }

        return try await provision(email: email, password: password)
    }

    func restoreSession() -> User? {
        guard Session.isSignedIn else { return nil }
        return storedAccount?.user
    }

    func signOut() {
        Session.markSignedIn(false)
    }

    // MARK: - Provisioning

    private func provision(email: String, password: String) async throws -> User {
        let salt = Self.randomSalt()
        let user = User(
            id: UUID().uuidString,
            firstName: Self.displayName(from: email),
            lastName: "",
            email: email,
            joinedAt: Date()
        )
        let digest = await Self.digest(password: password, salt: salt)
        Keychain.store(StoredAccount(user: user, salt: salt, digest: digest), for: accountKey)
        Session.markSignedIn(true)
        return user
    }

    /// "maya.ellison@example.com" reads back as "Maya" until the API supplies
    /// the real name.
    private static func displayName(from email: String) -> String {
        let local = email.split(separator: "@").first.map(String.init) ?? email
        let first = local.split(whereSeparator: { ".-_+".contains($0) }).first.map(String.init) ?? local
        return first.prefix(1).uppercased() + first.dropFirst()
    }

    // MARK: - Hashing

    private static func randomSalt() -> Data {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }

    private static func constantTimeEquals(_ a: Data, _ b: Data) -> Bool {
        a.count == b.count && zip(a, b).reduce(UInt8(0)) { $0 | ($1.0 ^ $1.1) } == 0
    }

    /// Stretched so a stolen keychain item is not trivially brute-forced. Runs
    /// off the main actor — the stretch takes real time.
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
