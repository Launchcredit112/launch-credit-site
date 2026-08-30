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
            previousUtilization: 0.87,
            onTimeStreakMonths: 6,
            history: history,
            bureaus: [
                BureauScore(bureau: .experian, score: 651, change: 8),
                BureauScore(bureau: .equifax, score: 648, change: 6),
                BureauScore(bureau: .transUnion, score: 644, change: 7)
            ],
            lastRefreshed: daysFromNow(-1)
        )
    }
}

extension CreditCard {
    /// $1,050 against $3,750 of limit — 28% overall, but one card is carrying
    /// almost all of it, which is what the coach keeps pointing at.
    static var seed: [CreditCard] {
        [
            CreditCard(name: "Visa ···4021", balance: 855, limit: 1_500, statementDay: 18),
            CreditCard(name: "Amex ···1009", balance: 195, limit: 2_250, statementDay: 26)
        ]
    }
}

extension FixItem {
    /// Ranked hardest-hitting first, exactly as the site's fix list is.
    static var seed: [FixItem] {
        [
            FixItem(
                title: "One card carrying most of the balance",
                pointCost: 48,
                dollarCost: 1_240,
                detail: "Your Visa is at 57% while the rest of your file is nearly clear. Scoring models read a single strained card as strain overall, and it is the fastest thing here to undo.",
                move: "Pay it down under 30% of its limit before the statement closes.",
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
    /// Derived from the file rather than written down, so the amount, the card
    /// and the deadline are always the ones actually on the account.
    static func thisWeek(cards: [CreditCard]) -> NextMove? {
        guard let worst = cards.max(by: { $0.utilization < $1.utilization }),
              worst.utilization > 0.30
        else { return nil }

        let payoff = worst.payoff(toReach: 0.29)
        guard payoff > 0 else { return nil }

        let rounded = payoff.roundedUpToNearest(5)
        let due = worst.nextStatementDate()
        let points = ScoreSimulator.pointsForPayingDown(cards: cards, amount: rounded, on: worst)

        return NextMove(
            headline: "Pay \(money(rounded)) on your \(worst.name)",
            detail: "Your \(worst.name) is at \(percent(worst.utilization)) of its limit. Pay \(money(rounded)) before it reports and it lands under 30%, which shows up on your next cycle.",
            dueDate: due,
            estimatedPoints: points,
            payment: rounded,
            cardID: worst.id
        )
    }
}

// MARK: - Small formatters shared by the seeded copy

func money(_ value: Decimal) -> String {
    value.formatted(.currency(code: "USD").precision(.fractionLength(0)))
}

func percent(_ value: Double) -> String {
    "\(Int((value * 100).rounded()))%"
}

extension Decimal {
    /// Advice reads better in round numbers than to the cent.
    func roundedUpToNearest(_ step: Int) -> Decimal {
        let stepValue = Decimal(step)
        guard stepValue > 0 else { return self }
        let quotient = NSDecimalNumber(decimal: self / stepValue).doubleValue
        return Decimal(Int(quotient.rounded(.up))) * stepValue
    }
}

extension BuilderAccount {
    static var seed: BuilderAccount {
        BuilderAccount(
            isOpen: true,
            tier: .basic,
            openedAt: monthsAgo(6),
            onTimePayments: 6,
            nextPaymentDate: daysFromNow(12)
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
