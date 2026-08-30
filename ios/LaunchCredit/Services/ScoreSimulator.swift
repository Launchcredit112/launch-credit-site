import Foundation

/// The what-if engine behind the simulator, the coach's arithmetic, and the
/// point estimate on this week's move — one model, so the three never disagree.
///
/// These are directional estimates, not a scoring model, and every surface that
/// shows a number from here says so.
enum ScoreSimulator {

    struct Inputs: Equatable {
        var startingScore: Int
        /// Balances over limits across every card, 0...1.
        var overallUtilization: Double
        var currentOverallUtilization: Double
        /// The single most strained card, which models weigh separately.
        var worstCardUtilization: Double
        var currentWorstCardUtilization: Double
        var billsReported: Int
        var backdatedMonths: Int
        var builderOpen: Bool
        var onTimeMonths: Int
        var newHardInquiries: Int
    }

    struct Result: Equatable {
        var projected: Int
        var delta: Int
        var contributions: [Contribution]
    }

    struct Contribution: Equatable, Identifiable {
        var id: String { label }
        var label: String
        var points: Int
    }

    /// Crossing this is where most of the utilization gain sits.
    static let healthyUtilization = 0.30

    static func project(_ inputs: Inputs) -> Result {
        var contributions: [Contribution] = []

        // Aggregate utilization: the number every model looks at first.
        let overallDelta = inputs.currentOverallUtilization - inputs.overallUtilization
        if abs(overallDelta) > 0.005 {
            var points = Int((overallDelta * 30).rounded())
            if crosses(healthyUtilization, from: inputs.currentOverallUtilization, to: inputs.overallUtilization) { points += 5 }
            if inputs.overallUtilization <= 0.10 && inputs.currentOverallUtilization > 0.10 { points += 3 }
            if points != 0 { contributions.append(Contribution(label: "Overall utilization", points: points)) }
        }

        // One strained card drags the file even when the total looks fine.
        let worstDelta = inputs.currentWorstCardUtilization - inputs.worstCardUtilization
        if abs(worstDelta) > 0.005 {
            var points = Int((worstDelta * 15).rounded())
            if crosses(healthyUtilization, from: inputs.currentWorstCardUtilization, to: inputs.worstCardUtilization) { points += 5 }
            if points != 0 { contributions.append(Contribution(label: "Highest card", points: points)) }
        }

        // Reported bills thicken a thin file. The first two matter most.
        if inputs.billsReported > 0 {
            contributions.append(Contribution(label: "Bills reported", points: min(24, 9 + (inputs.billsReported - 1) * 5)))
        }

        // Backdated history counts as seasoned on-time months.
        if inputs.backdatedMonths > 0 {
            contributions.append(Contribution(label: "Backdated history", points: min(18, Int((Double(inputs.backdatedMonths) * 0.65).rounded()))))
        }

        if inputs.builderOpen {
            contributions.append(Contribution(label: "Builder account", points: 12))
        }

        // On-time months compound, with diminishing returns after a year.
        if inputs.onTimeMonths > 0 {
            let months = Double(min(inputs.onTimeMonths, 24))
            let points = Int((14 * (1 - exp(-months / 7))).rounded())
            if points > 0 { contributions.append(Contribution(label: "On-time streak", points: points)) }
        }

        if inputs.newHardInquiries > 0 {
            contributions.append(Contribution(label: "New hard inquiries", points: -inputs.newHardInquiries * 5))
        }

        let raw = inputs.startingScore + contributions.reduce(0) { $0 + $1.points }
        let projected = min(850, max(300, raw))
        return Result(
            projected: projected,
            delta: projected - inputs.startingScore,
            contributions: contributions.sorted { abs($0.points) > abs($1.points) }
        )
    }

    private static func crosses(_ threshold: Double, from before: Double, to after: Double) -> Bool {
        before > threshold && after <= threshold
    }

    // MARK: - Card arithmetic

    static func utilization(of cards: [CreditCard]) -> Double {
        let limit = cards.reduce(Decimal(0)) { $0 + $1.limit }
        guard limit > 0 else { return 0 }
        let balance = cards.reduce(Decimal(0)) { $0 + $1.balance }
        return min(1, NSDecimalNumber(decimal: balance).doubleValue / NSDecimalNumber(decimal: limit).doubleValue)
    }

    /// What paying `amount` off `card` is worth, holding everything else still.
    /// This is what the coach quotes and what this week's move promises.
    static func pointsForPayingDown(cards: [CreditCard], amount: Decimal, on card: CreditCard) -> Int {
        var after = cards
        guard let index = after.firstIndex(where: { $0.id == card.id }) else { return 0 }
        after[index].balance = max(0, after[index].balance - amount)

        let result = project(
            Inputs(
                startingScore: 0,
                overallUtilization: utilization(of: after),
                currentOverallUtilization: utilization(of: cards),
                worstCardUtilization: worstUtilization(of: after),
                currentWorstCardUtilization: worstUtilization(of: cards),
                billsReported: 0,
                backdatedMonths: 0,
                builderOpen: false,
                onTimeMonths: 0,
                newHardInquiries: 0
            )
        )
        return max(0, result.delta)
    }

    static func worstUtilization(of cards: [CreditCard]) -> Double {
        cards.map(\.utilization).max() ?? 0
    }

    /// A plain-spoken estimate of how long the current trend takes to reach a
    /// target, or nil when the trend gives no basis for an answer.
    static func monthsToReach(_ target: Int, from history: [ScorePoint]) -> Int? {
        guard let latest = history.last?.score, target > latest else { return nil }
        let recent = history.suffix(7)
        guard recent.count >= 2, let first = recent.first?.score, let last = recent.last?.score else { return nil }

        let perMonth = Double(last - first) / Double(recent.count - 1)
        // Below about a point a month there is no honest projection to give.
        guard perMonth >= 1 else { return nil }
        return max(1, Int((Double(target - latest) / perMonth).rounded(.up)))
    }
}
