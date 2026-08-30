import Foundation
import UserNotifications

/// Payment reminders, derived from the file rather than typed in by the member.
/// The dates are already on their accounts — the app just has to not let them
/// pass quietly.
@MainActor
final class ReminderService: ObservableObject {

    @Published private(set) var isAuthorized = false

    private let center = UNUserNotificationCenter.current()
    private let identifierPrefix = "launch.reminder."

    /// Everything worth a nudge in the next few weeks, soonest first.
    static func upcoming(cards: [CreditCard], builder: BuilderAccount, bills: [BillAccount], goal: Goal?) -> [Reminder] {
        var reminders: [Reminder] = []

        // Statement dates: paying after one closes wastes the whole month.
        for card in cards where card.utilization > 0.10 {
            let statement = card.nextStatementDate()
            reminders.append(
                Reminder(
                    id: "statement-\(card.id)",
                    kind: .statement,
                    title: "\(card.name) reports soon",
                    detail: card.utilization > ScoreSimulator.healthyUtilization
                        ? "Pay it under \(money(card.limit * Decimal(0.29))) before this date and the lower balance is what the bureaus see."
                        : "Whatever the balance is on this date is what gets reported.",
                    date: reminderDate(before: statement, days: 3)
                )
            )
        }

        if builder.isOpen {
            reminders.append(
                Reminder(
                    id: "builder-payment",
                    kind: .builderPayment,
                    title: "Builder payment due",
                    detail: "Autopay has it. \(builder.onTimePayments) months on-time so far — this is the streak doing the quiet work.",
                    date: reminderDate(before: builder.nextPaymentDate, days: 2)
                )
            )
        }

        // A bill stuck verifying is usually a bill nobody chased.
        for bill in bills where bill.state == .pending {
            reminders.append(
                Reminder(
                    id: "bill-\(bill.id)",
                    kind: .billCheck,
                    title: "\(bill.kind.label) verification",
                    detail: "We're verifying \(bill.provider). If it hasn't cleared by this date, I'll look into it.",
                    date: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
                )
            )
        }

        if let goal {
            reminders.append(
                Reminder(
                    id: "goal-\(goal.id)",
                    kind: .goalCheckIn,
                    title: "Goal check-in",
                    detail: "Monthly look at where \(goal.title.lowercased()) stands and what changed.",
                    date: Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
                )
            )
        }

        return reminders.sorted { $0.date < $1.date }
    }

    /// A few days ahead, so there is time to actually do something about it.
    private static func reminderDate(before date: Date, days: Int) -> Date {
        let target = Calendar.current.date(byAdding: .day, value: -days, to: date) ?? date
        return target > Date() ? target : date
    }

    // MARK: - Notifications

    func refreshAuthorization() async {
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    /// Asks once, then schedules. Returns whether reminders are on.
    @discardableResult
    func enable(reminders: [Reminder]) async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted
            if granted { await schedule(reminders) }
            return granted
        } catch {
            isAuthorized = false
            return false
        }
    }

    /// Replaces everything we scheduled, so the queue always matches the file.
    func schedule(_ reminders: [Reminder]) async {
        let existing = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: existing)

        guard isAuthorized else { return }

        for reminder in reminders where reminder.date > Date() {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.detail
            content.sound = .default

            var components = Calendar.current.dateComponents([.year, .month, .day], from: reminder.date)
            components.hour = 9
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            try? await center.add(
                UNNotificationRequest(identifier: identifierPrefix + reminder.id, content: content, trigger: trigger)
            )
        }
    }

    func disable() async {
        let existing = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: existing)
    }
}
