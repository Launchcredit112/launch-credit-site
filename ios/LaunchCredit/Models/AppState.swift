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
    @Published var cards: [CreditCard] = CreditCard.seed
    @Published var fixes: [FixItem] = FixItem.seed
    @Published var nextMove: NextMove? = NextMove.thisWeek(cards: CreditCard.seed)
    @Published var builder: BuilderAccount = .seed
    @Published var bills: [BillAccount] = BillAccount.seed
    @Published var goal: Goal?
    @Published var remindersOn = false
    @Published var subscription: Subscription = .seed

    // MARK: - Coach

    @Published var messages: [ChatMessage] = []
    @Published var coachIsTyping = false
    /// What the last question was about, so "how much?" knows what it follows.
    private var lastIntent: CoachIntent?

    // MARK: - Derived

    /// Balances over limits, computed rather than stored — every screen and
    /// every coach answer reads the same number.
    var utilization: Double { ScoreSimulator.utilization(of: cards) }

    var worstCard: CreditCard? { cards.max(by: { $0.utilization < $1.utilization }) }

    /// The plan behind the member's goal, recomputed from the live file.
    var goalPlan: GoalPlan? { goal.map { GoalEngine.plan(for: $0, context: coachContext) } }

    var cardMatches: [CardRecommendation] { CardAdvisor.recommendations(for: coachContext) }

    var upcomingReminders: [Reminder] {
        ReminderService.upcoming(cards: cards, builder: builder, bills: bills, goal: goal)
    }

    private let auth: AuthServicing
    private let coach: CoachEngine
    private let store = LocalStore()
    private let reminders = ReminderService()

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
            cards = saved.cards
            fixes = saved.fixes
            nextMove = saved.nextMove
            builder = saved.builder
            bills = saved.bills
            goal = saved.goal
            remindersOn = saved.remindersOn
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
                cards: cards,
                fixes: fixes,
                nextMove: nextMove,
                builder: builder,
                bills: bills,
                goal: goal,
                remindersOn: remindersOn,
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
            previousUtilization: profile.previousUtilization,
            onTimeStreakMonths: profile.onTimeStreakMonths,
            history: profile.history,
            cards: cards,
            builder: builder,
            bills: bills,
            fixes: fixes,
            nextMove: nextMove,
            goal: goal,
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
        let previous = lastIntent
        lastIntent = CoachIntent.classify(CoachQuery(question), previous: previous)
        let reply = await coach.reply(to: question, context: coachContext, previousIntent: previous)
        coachIsTyping = false
        messages.append(reply)
        persistMemberData()
    }

    /// Runs an action the coach offered, then says what happened — the member
    /// never has to go find the screen it lives on.
    func perform(_ action: CoachAction) {
        switch action {
        case .markMoveDone:
            completeNextMove()
            let confirmation = nextMove.map { "Done. Next up: \($0.headline.lowercased())." }
                ?? "Done — and that clears your plan for now. I'll tell you when something needs you."
            messages.append(ChatMessage(role: .coach, text: confirmation, suggestions: ["Show me my score"]))

        case .turnOnBill(let kind):
            guard let bill = bills.first(where: { $0.kind == kind }) else { return }
            toggleBill(bill)
            messages.append(
                ChatMessage(
                    role: .coach,
                    text: "Switched on. We'll verify your \(kind.label.lowercased()) with \(bill.provider) — usually a few days — then it starts reporting to all three bureaus.",
                    suggestions: ["What's my next move?"]
                )
            )

        case .setGoal(let kind, let amount):
            setGoal(Goal(kind: kind, amount: amount))
            if let plan = goalPlan {
                let line = plan.isReadyToday
                    ? "Tracking it. You're already at the score for this — nothing to wait for."
                    : "Tracking it. You'll see it at the top of your plan, with the \(plan.steps.filter { !$0.isDone }.count) steps that get you there."
                messages.append(ChatMessage(role: .coach, text: line, suggestions: ["What's hurting my credit?"]))
            }

        case .enableReminders:
            Task { await enableReminders() }

        case .openSimulator, .showCardMatches:
            break  // presented by the view; nothing to change in state
        }
        persistMemberData()
    }

    // MARK: - Goal

    func setGoal(_ newGoal: Goal?) {
        goal = newGoal
        persistMemberData()
        if remindersOn { Task { await rescheduleReminders() } }
    }

    // MARK: - Reminders

    func enableReminders() async {
        let granted = await reminders.enable(reminders: upcomingReminders)
        remindersOn = granted
        messages.append(
            ChatMessage(
                role: .coach,
                text: granted
                    ? "Done. I'll nudge you a few days before each statement closes and before your builder payment — early enough to actually do something about it."
                    : "Notifications are switched off for Launch in iOS Settings, so I can't send them. Turn them on there and ask me again.",
                suggestions: ["What's my next move?"]
            )
        )
        persistMemberData()
    }

    func disableReminders() async {
        await reminders.disable()
        remindersOn = false
        persistMemberData()
    }

    private func rescheduleReminders() async {
        await reminders.schedule(upcomingReminders)
    }

    /// Lets any screen hand a question to the coach — tapping "Ask why" on
    /// this week's move opens the coach with the answer already arriving.
    func askCoach(_ question: String) {
        guard !coachIsTyping else { return }
        Task { await send(question) }
    }

    func clearConversation() {
        messages = []
        lastIntent = nil
        seedConversation()
        persistMemberData()
    }

    // MARK: - Member actions

    /// "Mark it done" on this week's move. The payment lands on the card, so
    /// utilization, the score and the *next* move all move together — the file
    /// stays true instead of the checkbox drifting away from it.
    func completeNextMove() {
        guard let move = nextMove, !move.isDone else { return }
        defer { if remindersOn { Task { await rescheduleReminders() } } }

        if let payment = move.payment,
           let cardID = move.cardID,
           let index = cards.firstIndex(where: { $0.id == cardID }) {
            cards[index].balance = max(0, cards[index].balance - payment)
        }

        applyScoreChange(move.estimatedPoints)
        nextMove = NextMove.thisWeek(cards: cards)
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
    var cards: [CreditCard]
    var fixes: [FixItem]
    var nextMove: NextMove?
    var builder: BuilderAccount
    var bills: [BillAccount]
    var goal: Goal?
    var remindersOn: Bool
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
