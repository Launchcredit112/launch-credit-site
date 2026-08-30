import Foundation

/// Turns "I want to finance a $30,000 car" into a score to hit, a set of steps,
/// a date, and — the part that actually moves people — what waiting costs.
enum GoalEngine {

    // MARK: - Rates

    /// Indicative APRs by score band. Directional, not quotes; every surface
    /// that shows a payment from these says so.
    static func apr(for kind: Goal.Kind, score: Int) -> Double? {
        switch kind {
        case .auto:
            switch score {
            case 780...: return 0.052
            case 720...: return 0.061
            case 660...: return 0.084
            case 620...: return 0.117
            case 580...: return 0.154
            default:     return nil
            }
        case .mortgage:
            switch score {
            case 760...: return 0.063
            case 700...: return 0.066
            case 680...: return 0.069
            case 660...: return 0.072
            case 640...: return 0.076
            case 620...: return 0.081
            default:     return nil
            }
        case .personal:
            switch score {
            case 720...: return 0.109
            case 660...: return 0.155
            case 600...: return 0.219
            default:     return nil
            }
        case .rental, .card:
            return nil
        }
    }

    /// Standard amortising payment. `amount * r / (1 - (1 + r)^-n)`.
    static func monthlyPayment(amount: Decimal, apr: Double, months: Int) -> Decimal {
        guard months > 0, amount > 0 else { return 0 }
        let principal = NSDecimalNumber(decimal: amount).doubleValue
        let rate = apr / 12
        let payment: Double
        if rate <= 0 {
            payment = principal / Double(months)
        } else {
            payment = principal * rate / (1 - pow(1 + rate, -Double(months)))
        }
        return Decimal(Int(payment.rounded()))
    }

    static func terms(for goal: Goal, at score: Int) -> LoanTerms? {
        guard goal.kind.needsAmount, let apr = apr(for: goal.kind, score: score) else { return nil }
        let months = goal.kind.termMonths
        let payment = monthlyPayment(amount: goal.amount, apr: apr, months: months)
        return LoanTerms(
            apr: apr,
            monthlyPayment: payment,
            totalCost: payment * Decimal(months),
            termMonths: months
        )
    }

    // MARK: - The plan

    static func plan(for goal: Goal, context c: CoachContext) -> GoalPlan {
        let target = goal.kind.goodTermsScore
        let steps = buildSteps(for: c)
        let projected = min(850, c.score + steps.filter { !$0.isDone }.reduce(0) { $0 + $1.points })

        // How long the steps themselves imply, floored by how long the slowest
        // one takes — you cannot season history faster by wanting it more.
        var months: Int?
        if c.score >= target {
            months = 0
        } else if projected >= target {
            months = monthsForSteps(steps, toGain: target - c.score)
        } else {
            // The steps alone fall short, so fall back to the trend.
            months = ScoreSimulator.monthsToReach(target, from: c.history)
        }

        return GoalPlan(
            goal: goal,
            currentScore: c.score,
            targetScore: target,
            projectedScore: projected,
            steps: steps,
            monthsToTarget: months,
            todayTerms: terms(for: goal, at: c.score),
            targetTerms: terms(for: goal, at: target)
        )
    }

    /// The real, specific things on this file — not generic advice.
    private static func buildSteps(for c: CoachContext) -> [GoalStep] {
        var steps: [GoalStep] = []

        // 1. Utilization, because it re-scores within a cycle.
        if let worst = c.worstCard, worst.utilization > ScoreSimulator.healthyUtilization {
            let payoff = worst.payoff(toReach: 0.29).roundedUpToNearest(5)
            let points = ScoreSimulator.pointsForPayingDown(cards: c.cards, amount: payoff, on: worst)
            steps.append(
                GoalStep(
                    title: "Pay \(money(payoff)) on your \(worst.name)",
                    detail: "Takes it from \(percent(worst.utilization)) to just under 30%. Lands on your report next cycle.",
                    points: points,
                    months: 1,
                    isDone: false
                )
            )
        }

        // 2. Bills you already pay that are not counting.
        for bill in c.bills where bill.state == .off {
            steps.append(
                GoalStep(
                    title: "Switch on \(bill.kind.label.lowercased()) reporting",
                    detail: "\(money(bill.monthlyAmount)) a month you already pay, plus whatever history we can verify.",
                    points: 6,
                    months: 2,
                    isDone: false
                )
            )
        }

        // 3. The builder account, if it is not already running.
        if !c.builder.isOpen {
            steps.append(
                GoalStep(
                    title: "Open your builder account",
                    detail: "A reported line with no hard inquiry, building on-time history from month one.",
                    points: 12,
                    months: 3,
                    isDone: false
                )
            )
        }

        // 4. Time. Always last, always honest.
        let seasoning = min(14, max(4, 14 - c.builder.onTimePayments))
        steps.append(
            GoalStep(
                title: "Keep the streak running",
                detail: "\(c.builder.onTimePayments) months of on-time history so far. This is the part with no shortcut — it just has to accrue.",
                points: seasoning,
                months: 6,
                isDone: false
            )
        )

        // 5. Don't undo it.
        steps.append(
            GoalStep(
                title: "No new applications until then",
                detail: "Every application is a hard inquiry. Applying while you build is the most common way people lose the points they just earned.",
                points: 0,
                months: 0,
                isDone: true
            )
        )

        return steps
    }

    /// Walks the steps fastest-first until the gain is covered, and returns how
    /// long that took.
    private static func monthsForSteps(_ steps: [GoalStep], toGain needed: Int) -> Int {
        var gained = 0
        var months = 0
        for step in steps.filter({ !$0.isDone }).sorted(by: { $0.months < $1.months }) {
            gained += step.points
            months = max(months, step.months)
            if gained >= needed { break }
        }
        return max(1, months)
    }
}
