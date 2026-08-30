import Foundation

/// Matches cards to the file in front of it. Not a shelf of everything — only
/// what this member could plausibly be approved for and would actually benefit
/// from, each with the reason it was picked.
enum CardAdvisor {

    /// Ordered best-fit first. Empty when the honest answer is "not yet".
    static func recommendations(for c: CoachContext) -> [CardRecommendation] {
        var matches: [CardRecommendation] = []
        let score = c.score
        let strained = (c.worstCard?.utilization ?? 0) > ScoreSimulator.healthyUtilization
        let thinFile = c.cards.count < 3

        // Carrying a balance at a rate? That beats chasing points.
        if strained, score >= 640 {
            matches.append(
                CardRecommendation(
                    name: "Balance Transfer Card",
                    kind: .balanceTransfer,
                    minScore: 640,
                    highlight: "0% for 15 months",
                    why: "Your \(c.worstCard?.name ?? "card") is at \(percent(c.worstCard?.utilization ?? 0)). Moving that balance stops the interest while you pay it down — the transfer fee is usually less than two months of it.",
                    paysCommission: true
                )
            )
        }

        if score < 620 {
            matches.append(
                CardRecommendation(
                    name: "Secured Card",
                    kind: .secured,
                    minScore: 0,
                    highlight: "Deposit becomes your limit",
                    why: "At \(score) an unsecured card means a denial and a hard inquiry. A secured card approves on the deposit, not the score, and reports the same way.",
                    paysCommission: false
                )
            )
            return matches
        }

        if score >= 620 && thinFile {
            matches.append(
                CardRecommendation(
                    name: "Starter Rewards Card",
                    kind: .starter,
                    minScore: 620,
                    highlight: "Graduates after 7 on-time months",
                    why: "You have \(c.cards.count) revolving \(c.cards.count == 1 ? "account" : "accounts"). One more, kept nearly unused, widens your total limit and drops utilization without you paying anything down.",
                    paysCommission: true
                )
            )
        }

        if score >= 690 {
            matches.append(
                CardRecommendation(
                    name: "Everyday Cashback Card",
                    kind: .rewards,
                    minScore: 690,
                    highlight: "1.5% back on everything",
                    why: "Your file can carry an unsecured rewards card now. Put a recurring bill on it, autopay it in full, and it builds history without costing you anything.",
                    paysCommission: true
                )
            )
        }

        return matches
    }

    /// What to tell someone the answer is "not yet" for, and when to come back.
    static func readinessNote(for c: CoachContext) -> String {
        let score = c.score
        if score < 620 {
            return "A secured card is the only one worth applying for at \(score) — anything else is a denial plus a hard inquiry you keep for two years."
        }
        if let months = ScoreSimulator.monthsToReach(690, from: c.history), score < 690 {
            return "At \(score) you're in starter-card range. Unsecured rewards cards want about 690 — roughly \(months) months at your current pace."
        }
        return "Your file can carry an application. Keep it to one — three in a month reads as strain no matter how clean the rest looks."
    }
}
