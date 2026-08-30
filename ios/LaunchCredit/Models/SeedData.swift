import Foundation

/// Demo data that lets the app run end to end with no backend. The numbers are
/// the same ones the marketing site uses, so a member who signed up from the
/// web sees the story they were shown continue in the app.
///
/// Replace these with API responses; nothing outside this file assumes them.

private func daysFromNow(_ days: Int) -> Date {
    Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
}

private func monthsAgo(_ months: Int) -> Date {
    Calendar.current.date(byAdding: .month, value: -months, to: Date()) ?? Date()
}

extension CreditProfile {
    static var seed: CreditProfile {
        // Twelve months climbing from 612 to 648 — the site's hero trend.
        let path = [612, 615, 618, 617, 622, 627, 631, 630, 636, 641, 645, 648]
        let history = path.enumerated().map { index, score in
            ScorePoint(date: monthsAgo(path.count - 1 - index), score: score)
        }
        return CreditProfile(
            score: 648,
            changeSinceStart: 36,
            utilization: 0.28,
            previousUtilization: 0.87,
            onTimeStreakMonths: 6,
            openAccounts: 4,
            history: history,
            bureaus: [
                BureauScore(bureau: .experian, score: 651, change: 8, isReporting: true),
                BureauScore(bureau: .equifax, score: 648, change: 6, isReporting: true),
                BureauScore(bureau: .transUnion, score: 644, change: 7, isReporting: true)
            ],
            lastRefreshed: daysFromNow(-1)
        )
    }
}

extension FixItem {
    /// Ranked hardest-hitting first, exactly as the site's fix list is.
    static var seed: [FixItem] {
        [
            FixItem(
                title: "Utilization at 87% on one card",
                pointCost: 48,
                dollarCost: 1_240,
                detail: "One card is carrying almost its whole limit. Scoring models read that as strain, and it is the fastest thing on your file to undo.",
                move: "Pay $420 before the statement closes on the 18th to land under 30%.",
                status: .inProgress
            ),
            FixItem(
                title: "Thin file — only 4 accounts",
                pointCost: 32,
                dollarCost: 860,
                detail: "Lenders cannot price what they cannot see. With few accounts, one bad month swings your score much harder than it should.",
                move: "Keep the builder account reporting and add two more bills.",
                status: .inProgress,
                isBiggestWin: true
            ),
            FixItem(
                title: "No rent history on file",
                pointCost: 21,
                dollarCost: 540,
                detail: "You have paid rent on time for years and none of it counted. We can backdate up to 24 months of it.",
                move: "Add your rent in Build — 24 months backdate onto all three bureaus.",
                status: .done
            ),
            FixItem(
                title: "Short average account age",
                pointCost: 14,
                dollarCost: 310,
                detail: "Your oldest line is 3 years old. Age only fixes with time, so the move is to stop closing things.",
                move: "Leave your oldest card open, even unused.",
                status: .todo
            ),
            FixItem(
                title: "Two hard inquiries in 12 months",
                pointCost: 9,
                dollarCost: 180,
                detail: "Recent applications still show. They fade after a year and drop off entirely at two.",
                move: "No new applications until your file is ready — I will tell you when.",
                status: .todo
            )
        ]
    }
}

extension NextMove {
    static var seed: NextMove {
        NextMove(
            headline: "Pay $420 on your Visa",
            detail: "Pay $420 on your Visa before the statement closes. Utilization drops under 30% and the change lands on your report next cycle.",
            dueDate: daysFromNow(9),
            estimatedPoints: 11
        )
    }
}

extension BuilderAccount {
    static var seed: BuilderAccount {
        BuilderAccount(
            isOpen: true,
            tier: .basic,
            openedAt: monthsAgo(6),
            onTimePayments: 6,
            nextPaymentDate: daysFromNow(12),
            reportsTo: Bureau.allCases
        )
    }
}

extension BillAccount {
    static var seed: [BillAccount] {
        [
            BillAccount(kind: .rent, provider: "Oakview Apartments", monthlyAmount: 1_450, state: .reporting, backdatedMonths: 24),
            BillAccount(kind: .phone, provider: "Verizon", monthlyAmount: 85, state: .reporting, backdatedMonths: 18),
            BillAccount(kind: .power, provider: "City Power & Light", monthlyAmount: 112, state: .pending, backdatedMonths: 0),
            BillAccount(kind: .internet, provider: "Spectrum", monthlyAmount: 70, state: .off, backdatedMonths: 0)
        ]
    }
}

extension Subscription {
    static var seed: Subscription {
        Subscription(
            planName: "Launch",
            monthlyPrice: 39.99,
            isActive: true,
            renewsOn: daysFromNow(17),
            builderFee: BuilderTier.basic.monthlyFee
        )
    }
}

/// What the Launch plan includes — mirrors the pricing card on the site.
enum PlanBenefits {
    static let all: [String] = [
        "All 3 bureaus read and scored",
        "Full AI diagnosis — ranked by dollar impact",
        "Your step-by-step plan, updated monthly",
        "Credit builder account via our partner",
        "Rent + bills reported, 24mo backdated",
        "What-if simulator — test a move first",
        "AI coach, 24/7 — unlimited questions",
        "The app — iPhone, Android, web"
    ]
}
