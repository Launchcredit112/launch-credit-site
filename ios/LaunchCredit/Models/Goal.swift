import Foundation

// MARK: - Goal

/// What the member is actually trying to do. A score is not a goal — financing
/// a car is, and the score is just the toll on the way there.
struct Goal: Codable, Equatable, Identifiable {

    enum Kind: String, Codable, CaseIterable, Identifiable {
        case auto, mortgage, personal, rental, card

        var id: String { rawValue }

        var title: String {
            switch self {
            case .auto:     return "Finance a car"
            case .mortgage: return "Buy a home"
            case .personal: return "Personal loan"
            case .rental:   return "Rent a place"
            case .card:     return "Get a real credit card"
            }
        }

        var symbol: String {
            switch self {
            case .auto:     return "car.fill"
            case .mortgage: return "house.fill"
            case .personal: return "banknote.fill"
            case .rental:   return "key.fill"
            case .card:     return "creditcard.fill"
            }
        }

        var needsAmount: Bool {
            switch self {
            case .auto, .mortgage, .personal: return true
            case .rental, .card:              return false
            }
        }

        /// Typical loan length, in months, used for the payment maths.
        var termMonths: Int {
            switch self {
            case .auto:     return 60
            case .mortgage: return 360
            case .personal: return 48
            case .rental, .card: return 0
            }
        }

        var defaultAmount: Decimal {
            switch self {
            case .auto:     return 30_000
            case .mortgage: return 320_000
            case .personal: return 10_000
            case .rental, .card: return 0
            }
        }

        /// The score where terms stop punishing you. Below it you can often
        /// still be approved — you just pay for it.
        var goodTermsScore: Int {
            switch self {
            case .auto:     return 660
            case .mortgage: return 700
            case .personal: return 660
            case .rental:   return 620
            case .card:     return 670
            }
        }

        /// Below this, approval itself is the problem.
        var approvalFloor: Int {
            switch self {
            case .auto:     return 580
            case .mortgage: return 620
            case .personal: return 600
            case .rental:   return 580
            case .card:     return 620
            }
        }
    }

    var id: UUID = UUID()
    var kind: Kind
    var amount: Decimal
    var createdAt: Date = Date()

    var title: String {
        guard kind.needsAmount else { return kind.title }
        return "\(kind.title) — \(money(amount))"
    }
}

// MARK: - The plan to get there

/// One thing to do on the way to the goal, with what it is worth and how long
/// it takes. Ordered fastest-payoff-first.
struct GoalStep: Identifiable, Equatable {
    var id: String { title }
    var title: String
    var detail: String
    var points: Int
    var months: Int
    var isDone: Bool
}

/// Everything the app can say about a goal: where the member stands, what it
/// costs them today, what the steps are, and when they get there.
struct GoalPlan: Equatable {
    var goal: Goal
    var currentScore: Int
    var targetScore: Int
    var projectedScore: Int
    var steps: [GoalStep]
    /// Months to `targetScore` at the pace the plan implies, nil when the
    /// steps alone do not get there.
    var monthsToTarget: Int?

    /// What the loan looks like today versus at the target score.
    var todayTerms: LoanTerms?
    var targetTerms: LoanTerms?

    var isReadyToday: Bool { currentScore >= targetScore }
    var pointsNeeded: Int { max(0, targetScore - currentScore) }

    /// Whether the steps in hand are enough to clear the bar.
    var stepsAreEnough: Bool { projectedScore >= targetScore }

    var monthlySaving: Decimal? {
        guard let today = todayTerms, let target = targetTerms else { return nil }
        let saving = today.monthlyPayment - target.monthlyPayment
        return saving > 0 ? saving : nil
    }

    var lifetimeSaving: Decimal? {
        guard let today = todayTerms, let target = targetTerms else { return nil }
        let saving = today.totalCost - target.totalCost
        return saving > 0 ? saving : nil
    }
}

struct LoanTerms: Equatable {
    var apr: Double
    var monthlyPayment: Decimal
    var totalCost: Decimal
    var termMonths: Int

    var aprText: String { String(format: "%.1f%%", apr * 100) }
}

// MARK: - Card recommendations

/// A card matched to the file, with the reason it was matched. Never a shelf of
/// everything — only what this member could actually get and would benefit from.
struct CardRecommendation: Identifiable, Equatable {
    enum Kind: String {
        case secured, starter, rewards, balanceTransfer

        var label: String {
            switch self {
            case .secured:         return "Secured"
            case .starter:         return "Starter"
            case .rewards:         return "Rewards"
            case .balanceTransfer: return "Balance transfer"
            }
        }
    }

    var id: String { name }
    var name: String
    var kind: Kind
    var minScore: Int
    var highlight: String
    /// Why this one, for this file, right now.
    var why: String
    var paysCommission: Bool
}

// MARK: - Reminders

/// Something with a date attached that the member would rather not miss.
struct Reminder: Identifiable, Equatable {
    enum Kind: String, Codable {
        case statement, builderPayment, billCheck, goalCheckIn

        var symbol: String {
            switch self {
            case .statement:      return "creditcard"
            case .builderPayment: return "building.columns"
            case .billCheck:      return "doc.text.magnifyingglass"
            case .goalCheckIn:    return "flag"
            }
        }
    }

    var id: String
    var kind: Kind
    var title: String
    var detail: String
    var date: Date

    var daysAway: Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: date)).day ?? 0
    }
}
