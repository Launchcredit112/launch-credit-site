import Foundation

// MARK: - Account

struct User: Codable, Equatable, Identifiable {
    var id: String
    var firstName: String
    var lastName: String
    var email: String
    var phone: String?
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
    var isReporting: Bool

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
    var utilization: Double          // 0...1
    var previousUtilization: Double  // 0...1
    var onTimeStreakMonths: Int
    var openAccounts: Int
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
    var reportsTo: [Bureau]
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

// MARK: - Marketplace

struct Offer: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var category: String
    var name: String
    var detail: String
    var highlight: String
    /// The site promises: "We tell you when we earn a commission."
    var paysCommission: Bool
    /// Minimum score before we surface it — "when your file is ready, not before".
    var unlocksAtScore: Int
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
    var sentAt: Date = Date()
    /// Suggested follow-ups the member can tap instead of typing.
    var suggestions: [String] = []
}
