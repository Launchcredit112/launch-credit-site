import Foundation
import SwiftUI

/// The single source of truth for a signed-in member.
///
/// Everything here is seeded locally so the app runs end to end with no
/// backend. When the Launch API lands, replace the seed with a fetch and keep
/// the published surface identical — the views never touch storage directly.
@MainActor
final class AppState: ObservableObject {

    // MARK: - Session

    @Published private(set) var user: User?
    @Published private(set) var isRestoring = true
    @Published var authError: String?

    var isSignedIn: Bool { user != nil }

    // MARK: - Member data

    @Published var profile: CreditProfile = .seed
    @Published var fixes: [FixItem] = FixItem.seed
    @Published var nextMove: NextMove? = .seed
    @Published var builder: BuilderAccount = .seed
    @Published var bills: [BillAccount] = BillAccount.seed
    @Published var subscription: Subscription = .seed

    // MARK: - Coach

    @Published var messages: [ChatMessage] = []
    @Published var coachIsTyping = false

    private let auth: AuthServicing
    private let coach: CoachEngine
    private let store = LocalStore()

    init(auth: AuthServicing = LocalAuthService(), coach: CoachEngine = RemoteCoach()) {
        self.auth = auth
        self.coach = coach
    }

    var storedEmail: String? { auth.storedEmail }

    // MARK: - Auth

    func restore() {
        if let user = auth.restoreSession() {
            self.user = user
            loadMemberData()
        }
        isRestoring = false
    }

    func signIn(email: String, password: String) async -> Bool {
        authError = nil
        do {
            user = try await auth.signIn(email: email, password: password)
            loadMemberData()
            return true
        } catch {
            authError = (error as? AuthError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    func signOut() {
        persistMemberData()
        auth.signOut()
        user = nil
        messages = []
    }

    // MARK: - Persistence

    private func loadMemberData() {
        if let saved = store.load() {
            profile = saved.profile
            fixes = saved.fixes
            nextMove = saved.nextMove
            builder = saved.builder
            bills = saved.bills
            subscription = saved.subscription
            messages = saved.messages
        }
        if messages.isEmpty { seedConversation() }
    }

    func persistMemberData() {
        guard isSignedIn else { return }
        store.save(
            .init(
                profile: profile,
                fixes: fixes,
                nextMove: nextMove,
                builder: builder,
                bills: bills,
                subscription: subscription,
                // Keep the transcript bounded; the coach only needs recent context.
                messages: Array(messages.suffix(80))
            )
        )
    }

    // MARK: - Coach

    var coachContext: CoachContext {
        CoachContext(
            firstName: user?.firstName ?? "there",
            score: profile.score,
            changeSinceStart: profile.changeSinceStart,
            utilization: profile.utilization,
            previousUtilization: profile.previousUtilization,
            onTimeStreakMonths: profile.onTimeStreakMonths,
            builder: builder,
            bills: bills,
            fixes: fixes,
            nextMove: nextMove,
            subscription: subscription
        )
    }

    private func seedConversation() {
        let name = user?.firstName ?? "there"
        messages = [
            ChatMessage(
                role: .coach,
                text: "Hey \(name) — I'm your Launch coach. I can see your file, your balances and your dates, so ask me anything.",
                suggestions: ["What's my next move?", "Why is my score stuck?", "How much is Launch?"]
            )
        ]
    }

    func send(_ text: String) async {
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }

        messages.append(ChatMessage(role: .member, text: question))
        coachIsTyping = true
        let reply = await coach.reply(to: question, context: coachContext)
        coachIsTyping = false
        messages.append(reply)
        persistMemberData()
    }

    /// Lets any screen hand a question to the coach — tapping "Ask why" on
    /// this week's move opens the coach with the answer already arriving.
    func askCoach(_ question: String) {
        guard !coachIsTyping else { return }
        Task { await send(question) }
    }

    func clearConversation() {
        messages = []
        seedConversation()
        persistMemberData()
    }

    // MARK: - Member actions

    /// "Mark it done" on this week's move.
    func completeNextMove() {
        guard var move = nextMove, !move.isDone else { return }
        move.isDone = true
        nextMove = move
        applyScoreChange(move.estimatedPoints)
        persistMemberData()
    }

    func setFixStatus(_ fix: FixItem, to status: FixItem.Status) {
        guard let index = fixes.firstIndex(where: { $0.id == fix.id }) else { return }
        let wasDone = fixes[index].status == .done
        fixes[index].status = status
        if status == .done && !wasDone { applyScoreChange(fixes[index].pointCost) }
        persistMemberData()
    }

    /// The site's promise is "add them in the app and they start landing on
    /// your report" — so switching a bill on is the whole interaction.
    func toggleBill(_ bill: BillAccount) {
        guard let index = bills.firstIndex(where: { $0.id == bill.id }) else { return }
        bills[index].state = bills[index].state == .off ? .pending : .off
        persistMemberData()
    }

    /// Applies a projected gain and records it on the trend line, clamped to the
    /// scoring range so a long session cannot walk the score off the scale.
    private func applyScoreChange(_ points: Int) {
        let updated = min(850, max(300, profile.score + points))
        let applied = updated - profile.score
        guard applied != 0 else { return }
        profile.score = updated
        profile.changeSinceStart += applied
        profile.history.append(ScorePoint(date: Date(), score: updated))
        if profile.history.count > 24 { profile.history.removeFirst(profile.history.count - 24) }
    }
}

// MARK: - Local persistence

/// Member data cached on device. Nothing here is a credential — those live in
/// the keychain (`Keychain.swift`).
private struct MemberSnapshot: Codable {
    var profile: CreditProfile
    var fixes: [FixItem]
    var nextMove: NextMove?
    var builder: BuilderAccount
    var bills: [BillAccount]
    var subscription: Subscription
    var messages: [ChatMessage]
}

private struct LocalStore {
    private let key = "launch.member.v1"

    func save(_ snapshot: MemberSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    func load() -> MemberSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(MemberSnapshot.self, from: data)
    }
}
