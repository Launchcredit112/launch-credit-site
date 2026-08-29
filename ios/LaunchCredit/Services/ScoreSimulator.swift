import Foundation

/// The what-if engine behind the simulator tab and the site's score calculator.
///
/// These are directional estimates, not a scoring model — the copy in the UI
/// says so plainly, the same way the site's disclosure does.
enum ScoreSimulator {

    struct Inputs: Equatable {
        var startingScore: Int
        /// Utilization after the move, 0...1.
        var utilization: Double
        var currentUtilization: Double
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

    /// Twelve-month lift the site quotes by starting band — "+61 is the average
    /// first year for people starting around 500–599".
    static func averageFirstYearLift(startingScore: Int) -> Int {
        switch startingScore {
        case ..<500:  return 68
        case ..<600:  return 61
        case ..<650:  return 47
        case ..<700:  return 32
        case ..<750:  return 19
        default:      return 9
        }
    }

    static func project(_ inputs: Inputs) -> Result {
        var contributions: [Contribution] = []

        // Utilization: the fastest-moving factor. Crossing under 30% is where
        // most of the gain sits; below 10% adds a little more.
        let utilizationDelta = inputs.currentUtilization - inputs.utilization
        if abs(utilizationDelta) > 0.001 {
            var points = Int((utilizationDelta * 55).rounded())
            if inputs.currentUtilization > 0.30 && inputs.utilization <= 0.30 { points += 6 }
            if inputs.utilization <= 0.10 { points += 3 }
            if points != 0 {
                contributions.append(Contribution(label: "Utilization", points: points))
            }
        }

        // Reported bills thicken a thin file. The first two matter most.
        if inputs.billsReported > 0 {
            let points = min(24, 9 + (inputs.billsReported - 1) * 5)
            contributions.append(Contribution(label: "Bills reported", points: points))
        }

        // Backdated history counts as seasoned on-time months.
        if inputs.backdatedMonths > 0 {
            let points = min(18, Int((Double(inputs.backdatedMonths) * 0.65).rounded()))
            contributions.append(Contribution(label: "Backdated history", points: points))
        }

        if inputs.builderOpen {
            contributions.append(Contribution(label: "Builder account", points: 12))
        }

        // On-time months compound, with diminishing returns after a year.
        if inputs.onTimeMonths > 0 {
            let months = Double(min(inputs.onTimeMonths, 24))
            let points = Int((14 * (1 - exp(-months / 7))).rounded())
            if points > 0 {
                contributions.append(Contribution(label: "On-time streak", points: points))
            }
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
}
