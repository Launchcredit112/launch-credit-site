import Foundation

// MARK: - Account

struct User: Codable, Equatable, Identifiable {
    var id: String
    var firstName: String
    var lastName: String
    var email: String
    var joinedAt: Date

    var fullName: String { [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ") }

    var initials: String {
        let f = firstName.first.map(String.init) ?? ""
        let l = lastName.first.map(String.init) ?? ""
        let joined = (f + l).uppercased()
        return joined.isEmpty ? "L" : joined
    }
}

// MARK: - Score

enum Bureau: String, Codable, CaseIterable, Identifiable {
    case experian = "Experian"
    case equifax = "Equifax"
    case transUnion = "TransUnion"

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .experian:   return "EXP"
        case .equifax:    return "EFX"
        case .transUnion: return "TU"
        }
    }
}

struct BureauScore: Codable, Equatable, Identifiable {
    var bureau: Bureau
    var score: Int
    var change: Int

    var id: String { bureau.rawValue }
}

struct ScorePoint: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var date: Date
    var score: Int
}

/// Everything the dashboard needs about where the member stands right now.
struct CreditProfile: Codable, Equatable {
    var score: Int
    var changeSinceStart: Int
    /// Where utilization stood when the member joined, kept as history. What it
    /// is *now* is derived from `cards` — see `AppState.utilization`.
    var previousUtilization: Double  // 0...1
    var onTimeStreakMonths: Int
    var history: [ScorePoint]
    var bureaus: [BureauScore]
    var lastRefreshed: Date

    var band: String { creditBand(for: score) }
}

/// Free function so the model layer does not need to import SwiftUI.
func creditBand(for score: Int) -> String {
    switch score {
    case ..<580: return "Poor"
    case ..<670: return "Fair"
    case ..<740: return "Good"
    case ..<800: return "Very good"
    default:     return "Excellent"
    }
}

// MARK: - Revolving accounts

/// A card on the file. The coach needs balances and limits to answer "how much
/// should I pay" with a number instead of a platitude.
struct CreditCard: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    /// How the member recognises it, e.g. "Visa ···4021".
    var name: String
    var balance: Decimal
    var limit: Decimal
    /// Day of the month the balance reports to the bureaus.
    var statementDay: Int

    var utilization: Double {
        guard limit > 0 else { return 0 }
        return min(1, NSDecimalNumber(decimal: balance).doubleValue / NSDecimalNumber(decimal: limit).doubleValue)
    }

    /// What it would take to land at `target` utilization on this card.
    /// Negative means already there.
    func payoff(toReach target: Double) -> Decimal {
        let ceiling = limit * Decimal(target)
        return balance - ceiling
    }

    /// The next date this balance reports, so advice can name a real deadline.
    func nextStatementDate(from now: Date = Date(), calendar: Calendar = .current) -> Date {
        var components = calendar.dateComponents([.year, .month], from: now)
        components.day = statementDay
        let thisMonth = calendar.date(from: components) ?? now
        if thisMonth > now { return thisMonth }
        return calendar.date(byAdding: .month, value: 1, to: thisMonth) ?? thisMonth
    }
}

// MARK: - Diagnosis / fix list

/// A single ranked problem on the file. The site ranks these by dollar impact
/// and shows "the one move that fixes each".
struct FixItem: Codable, Equatable, Identifiable {
    enum Status: String, Codable {
        case todo, inProgress, done

        var label: String {
            switch self {
            case .todo:       return "Not started"
            case .inProgress: return "In progress"
            case .done:       return "Done"
            }
        }
    }

    var id: UUID = UUID()
    var title: String
    /// Points this issue is currently costing the score.
    var pointCost: Int
    /// Estimated annual dollar cost of carrying the issue.
    var dollarCost: Int
    var detail: String
    /// The one move that fixes it.
    var move: String
    var status: Status
    var isBiggestWin: Bool = false
}

// MARK: - Next move

struct NextMove: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var headline: String
    var detail: String
    var dueDate: Date
    var estimatedPoints: Int
    var isDone: Bool = false
    /// What the move actually asks for, so marking it done can apply it to the
    /// file instead of just ticking a box.
    var payment: Decimal? = nil
    var cardID: UUID? = nil
}

// MARK: - Builder account

enum BuilderTier: String, Codable, CaseIterable, Identifiable {
    case basic, premium, ultimate

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .basic:    return "Basic"
        case .premium:  return "Premium"
        case .ultimate: return "Ultimate"
        }
    }

    /// Reported tradeline amount, matching `checkout.html`.
    var tradeline: Int {
        switch self {
        case .basic:    return 750
        case .premium:  return 2_500
        case .ultimate: return 3_500
        }
    }

    /// Partner fee per month, matching `checkout.html`.
    var monthlyFee: Decimal {
        switch self {
        case .basic:    return 5
        case .premium:  return 20
        case .ultimate: return 35
        }
    }
}

struct BuilderAccount: Codable, Equatable {
    var isOpen: Bool
    var tier: BuilderTier
    var openedAt: Date?
    var onTimePayments: Int
    var nextPaymentDate: Date
}

// MARK: - Reported bills

struct BillAccount: Codable, Equatable, Identifiable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case rent, phone, power, internet

        var id: String { rawValue }

        var label: String {
            switch self {
            case .rent:     return "Rent"
            case .phone:    return "Phone"
            case .power:    return "Power"
            case .internet: return "Internet"
            }
        }

        var symbol: String {
            switch self {
            case .rent:     return "house.fill"
            case .phone:    return "iphone"
            case .power:    return "bolt.fill"
            case .internet: return "wifi"
            }
        }
    }

    enum State: String, Codable {
        case reporting, pending, off

        var label: String {
            switch self {
            case .reporting: return "Reporting"
            case .pending:   return "Verifying"
            case .off:       return "Not added"
            }
        }
    }

    var id: UUID = UUID()
    var kind: Kind
    var provider: String
    var monthlyAmount: Decimal
    var state: State
    /// Months of history backdated onto the file (up to 24 on the Launch plan).
    var backdatedMonths: Int
}

// MARK: - Subscription

struct Subscription: Codable, Equatable {
    var planName: String = "Launch"
    var monthlyPrice: Decimal = 39.99
    var isActive: Bool = true
    var renewsOn: Date
    var builderFee: Decimal

    var totalMonthly: Decimal { monthlyPrice + builderFee }
}

// MARK: - Coach

struct ChatMessage: Codable, Equatable, Identifiable {
    enum Role: String, Codable { case coach, member }

    /// An optional structured card attached to a coach reply, mirroring the
    /// `.cm-card` bubbles in the site's phone mock.
    struct Attachment: Codable, Equatable {
        var title: String
        var value: String
        var subtitle: String
    }

    var id: UUID = UUID()
    var role: Role
    var text: String
    var attachment: Attachment? = nil
    /// Suggested follow-ups the member can tap instead of typing.
    var suggestions: [String] = []
    /// Some answers end in something the member can just do. The coach offers
    /// it inline rather than sending them off to find the screen.
    var action: CoachAction? = nil
}

/// Something the coach can do on the member's behalf, offered as one button
/// under the reply that suggested it.
enum CoachAction: Codable, Equatable {
    case markMoveDone
    case turnOnBill(BillAccount.Kind)
    case openSimulator

    var label: String {
        switch self {
        case .markMoveDone:        return "Mark it done"
        case .turnOnBill(let kind): return "Turn on \(kind.label.lowercased())"
        case .openSimulator:       return "Open the simulator"
        }
    }
}
