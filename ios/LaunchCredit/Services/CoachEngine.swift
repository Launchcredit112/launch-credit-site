import Foundation

// MARK: - What the coach is allowed to know

/// The member's file, passed in whole. The site's promise is a coach that
/// "knows your balances and your dates" — this is that knowledge, handed over
/// explicitly so no answer is ever guessed.
struct CoachContext {
    var firstName: String
    var score: Int
    var changeSinceStart: Int
    var previousUtilization: Double
    var onTimeStreakMonths: Int
    var history: [ScorePoint]
    var cards: [CreditCard]
    var builder: BuilderAccount
    var bills: [BillAccount]
    var fixes: [FixItem]
    var nextMove: NextMove?
    var subscription: Subscription

    var utilization: Double { ScoreSimulator.utilization(of: cards) }
    var worstCard: CreditCard? { cards.max(by: { $0.utilization < $1.utilization }) }
    var reportingBills: [BillAccount] { bills.filter { $0.state == .reporting } }
    var offBills: [BillAccount] { bills.filter { $0.state == .off } }
    var topFix: FixItem? { fixes.filter { $0.status != .done }.max(by: { $0.pointCost < $1.pointCost }) }
    var maxBackdated: Int { reportingBills.map(\.backdatedMonths).max() ?? 0 }

    /// What paying `amount` off the most strained card would be worth.
    func pointsForPaying(_ amount: Decimal) -> (points: Int, card: CreditCard, newUtilization: Double)? {
        guard let card = worstCard else { return nil }
        let points = ScoreSimulator.pointsForPayingDown(cards: cards, amount: amount, on: card)
        var after = cards
        if let index = after.firstIndex(where: { $0.id == card.id }) {
            after[index].balance = max(0, after[index].balance - amount)
        }
        return (points, card, ScoreSimulator.utilization(of: after))
    }
}

protocol CoachEngine {
    func reply(to question: String, context: CoachContext, previousIntent: CoachIntent?) async -> ChatMessage
}

// MARK: - Reading the question

/// A question broken into the parts the coach reasons about: the words, any
/// dollar figure, and any target score.
struct CoachQuery {
    let text: String
    let tokens: [String]
    let amount: Decimal?
    let targetScore: Int?

    init(_ raw: String) {
        let lowered = raw.lowercased()
        let cleaned = String(lowered.map { $0.isLetter || $0.isNumber || $0 == "$" || $0 == "'" ? $0 : " " })
        text = " " + cleaned.split(separator: " ").joined(separator: " ") + " "
        tokens = cleaned.split(separator: " ").map(String.init)

        // A figure written with a dollar sign is always money. Without one, the
        // surrounding words decide: you pay an amount, you reach a score.
        let numbers = Self.numbers(in: lowered)
        let saysMoney = ["pay", "paid", "paying", "payment", "put", "spend", "afford", "$"].contains { lowered.contains($0) }
        let saysScore = ["score", "reach", "get to", "hit", "until", "till", "up to"].contains { lowered.contains($0) }

        var foundAmount: Decimal?
        var foundTarget: Int?
        for number in numbers {
            if number.hadDollarSign {
                foundAmount = foundAmount ?? Decimal(number.value)
            } else if saysScore, (300...850).contains(number.value) {
                foundTarget = foundTarget ?? number.value
            } else if saysMoney {
                foundAmount = foundAmount ?? Decimal(number.value)
            } else if (300...850).contains(number.value) {
                foundTarget = foundTarget ?? number.value
            }
        }
        amount = foundAmount
        targetScore = foundTarget
    }

    private struct Number { let value: Int; let hadDollarSign: Bool }

    private static func numbers(in text: String) -> [Number] {
        var results: [Number] = []
        var digits = ""
        var dollar = false
        var pendingDollar = false

        for character in text {
            if character == "$" {
                pendingDollar = true
                continue
            }
            if character.isNumber {
                if digits.isEmpty { dollar = pendingDollar }
                digits.append(character)
                continue
            }
            // Commas inside a figure are separators, not terminators.
            if character == "," && !digits.isEmpty { continue }
            if !digits.isEmpty {
                if let value = Int(digits) { results.append(Number(value: value, hadDollarSign: dollar)) }
                digits = ""
            }
            if !character.isWhitespace { pendingDollar = false }
        }
        if !digits.isEmpty, let value = Int(digits) {
            results.append(Number(value: value, hadDollarSign: dollar))
        }
        return results
    }

    /// Short questions like "how much?" or "why?" carry no topic of their own —
    /// they mean whatever the last answer was about.
    var isFollowUp: Bool {
        guard tokens.count <= 4 else { return false }
        let openers = ["why", "how", "when", "what", "really", "and", "so", "ok", "okay", "then", "which", "who"]
        return tokens.first.map(openers.contains) ?? false
    }
}

// MARK: - Intent

enum CoachIntent: String, CaseIterable {
    case greeting
    case score
    case utilization
    case payoff
    case bills
    case builder
    case nextMove
    case timeline
    case bureaus
    case billing
    case simulate
    case applying
    case inquiries
    case latePayment
    case collections
    case disputes
    case thanks
    case unknown

    /// Phrases carry far more signal than single words, so they score higher.
    var phrases: [String] {
        switch self {
        case .greeting:     return ["good morning", "good evening", "good afternoon", "what's up", "whats up"]
        case .score:        return ["my score", "credit score", "where do i stand", "how am i doing", "how's my credit", "hows my credit"]
        case .utilization:  return ["credit utilization", "my balance", "my balances", "credit card", "maxed out", "my limit", "too high"]
        case .payoff:       return ["how much should i pay", "how much do i need", "how much to pay", "what if i pay", "if i pay", "pay off", "pay down", "pay it down"]
        case .bills:        return ["my rent", "phone bill", "power bill", "electric bill", "internet bill", "add a bill", "turn on", "which bills", "report my rent", "back date", "backdate"]
        case .builder:      return ["builder account", "credit builder", "my tradeline", "reported line"]
        case .nextMove:     return ["next move", "next step", "what should i do", "what do i do", "this week", "this month", "my plan", "one move", "why that one", "why that first", "why this one", "what's after that", "whats after that"]
        case .timeline:     return ["how long", "how many months", "how soon", "how fast", "by when", "when will i"]
        case .bureaus:      return ["all three", "all 3", "the bureaus", "which bureau", "reporting to"]
        case .billing:      return ["how much is launch", "my subscription", "cancel my", "next charge", "what am i paying", "billed"]
        case .simulate:     return ["what if", "what would happen", "run a simulation", "the simulator"]
        case .applying:     return ["should i apply", "am i ready", "ready to apply", "new card", "which card should", "get approved", "auto loan", "refinance"]
        case .inquiries:    return ["hard inquiry", "hard pull", "soft pull", "soft check", "hurt my score", "lower my score", "does it hurt"]
        case .latePayment:  return ["missed a payment", "paid late", "past due", "30 days late", "behind on"]
        case .collections:  return ["in collections", "charge off", "charged off", "debt collector", "settle a debt"]
        case .disputes:     return ["not mine", "identity theft", "file a dispute", "wrong on my report", "an error on"]
        case .thanks:       return ["thank you", "thanks", "appreciate it", "got it"]
        case .unknown:      return []
        }
    }

    var words: [String] {
        switch self {
        case .greeting:     return ["hi", "hello", "hey", "yo"]
        case .score:        return ["score", "points", "fico", "vantage", "band"]
        case .utilization:  return ["utilization", "utilisation", "balance", "balances", "card", "cards", "limit", "visa", "amex", "mastercard"]
        case .payoff:       return ["payoff", "afford"]
        case .bills:        return ["rent", "bill", "bills", "utility", "utilities", "landlord", "lease", "internet", "power"]
        case .builder:      return ["builder", "tradeline", "partner"]
        case .nextMove:     return ["next", "todo", "step", "plan"]
        case .timeline:     return ["long", "soon", "months", "timeline"]
        case .bureaus:      return ["bureau", "bureaus", "experian", "equifax", "transunion"]
        case .billing:      return ["price", "cost", "charge", "billing", "subscription", "cancel", "refund", "free"]
        case .simulate:     return ["simulate", "simulator", "projection", "forecast"]
        case .applying:     return ["apply", "applying", "approved", "mortgage"]
        case .inquiries:    return ["inquiry", "inquiries"]
        case .latePayment:  return ["late", "missed", "delinquent"]
        case .collections:  return ["collection", "collections"]
        case .disputes:     return ["dispute", "fraud"]
        case .thanks:       return ["cheers"]
        case .unknown:      return []
        }
    }

    /// Scores every intent against the question, then falls back to whatever
    /// the conversation was already about when the question is a bare follow-up.
    static func classify(_ query: CoachQuery, previous: CoachIntent?) -> CoachIntent {
        var best: (intent: CoachIntent, score: Int) = (.unknown, 0)

        for intent in allCases where intent != .unknown {
            var score = 0
            for phrase in intent.phrases where query.text.contains(" " + phrase) { score += 6 }
            for word in intent.words where query.tokens.contains(word) { score += 2 }
            if score > best.score { best = (intent, score) }
        }

        // A dollar figure in the question is nearly always a payoff question.
        if query.amount != nil && best.score <= 6 { return .payoff }
        // A target score with no other signal is a timeline question.
        if query.targetScore != nil && best.score == 0 { return .timeline }

        if best.score > 0 { return best.intent }
        if query.isFollowUp, let previous, previous != .unknown { return previous }
        return .unknown
    }
}

// MARK: - On-device coach

/// Answers from the member's own numbers. Deterministic, private, and available
/// with no network — which is what makes "ask me at 2am" true.
struct OnDeviceCoach: CoachEngine {

    /// A beat of thinking time, so replies land like a conversation.
    var thinkingDelay: Duration = .milliseconds(600)

    func reply(to question: String, context: CoachContext, previousIntent: CoachIntent?) async -> ChatMessage {
        try? await Task.sleep(for: thinkingDelay)
        return Self.answer(to: question, context: context, previousIntent: previousIntent)
    }

    /// Pure and synchronous, so it can be tested and previewed directly.
    static func answer(to question: String, context c: CoachContext, previousIntent: CoachIntent? = nil) -> ChatMessage {
        let query = CoachQuery(question)
        let intent = CoachIntent.classify(query, previous: previousIntent)

        switch intent {

        case .greeting:
            return reply(
                "Hey \(c.firstName). You're at \(c.score) — \(signed(c.changeSinceStart)) since you started. What do you want to look at?",
                suggestions: ["What's my next move?", "How much should I pay?", "How long to 700?"]
            )

        case .score:
            let band = creditBand(for: c.score)
            var text = "**\(c.score)** — \(band.lowercased()), and \(signed(c.changeSinceStart)) since day one."
            if let next = nextBand(from: c.score) {
                let months = ScoreSimulator.monthsToReach(next.threshold, from: c.history)
                text += " \(next.threshold - c.score) more points puts you in \(next.name.lowercased())"
                text += months.map { ", about \($0) months at the pace you're going." } ?? "."
            }
            text += " The \(c.builder.onTimePayments)-month on-time streak is the part doing the quiet work."
            return reply(
                text,
                attachment: .init(title: "Your score", value: "\(c.score)", subtitle: "\(band) · \(signed(c.changeSinceStart)) since you joined"),
                suggestions: ["What's holding it back?", "What's my next move?"]
            )

        case .utilization:
            let now = c.utilization
            guard let worst = c.worstCard else {
                return reply("I can't see a revolving account on your file right now, so utilization isn't what's holding you back. Your thin file is.", suggestions: ["What's my next move?"])
            }
            if worst.utilization <= ScoreSimulator.healthyUtilization {
                return reply(
                    "You're clean: **\(percent(now))** overall, and your highest card is \(percent(worst.utilization)). Under 30% is where you want it — leave the cards open and keep letting them report.",
                    suggestions: ["What should I fix next?", "What's my next move?"]
                )
            }
            return reply(
                "Overall you're at **\(percent(now))**, which is fine. The problem is your \(worst.name): \(money(worst.balance)) against a \(money(worst.limit)) limit, so **\(percent(worst.utilization))** on one card. Models read that as strain even when the total looks healthy.",
                attachment: .init(
                    title: worst.name,
                    value: percent(worst.utilization),
                    subtitle: "\(money(worst.balance)) of \(money(worst.limit)) · reports on the \(ordinal(worst.statementDay))"
                ),
                suggestions: ["How much should I pay?", "When does it report?"]
            )

        case .payoff:
            guard let worst = c.worstCard else {
                return reply("Nothing to pay down — there's no revolving balance on your file.", suggestions: ["What's my next move?"])
            }
            // "What if I pay $300?" — answer the amount they actually named.
            if let amount = query.amount, let outcome = c.pointsForPaying(amount) {
                let card = outcome.card
                var after = card
                after.balance = max(0, card.balance - amount)
                var text = "Paying **\(money(amount))** off your \(card.name) takes it from \(percent(card.utilization)) to \(percent(after.utilization)), and your overall to \(percent(outcome.newUtilization))."
                text += outcome.points > 0
                    ? " That's worth roughly **\(outcome.points) points** once it reports."
                    : " That barely moves the needle, though — the gain comes from crossing under 30% on that card."
                let target = card.payoff(toReach: 0.29).roundedUpToNearest(5)
                if amount < target {
                    text += " \(money(target)) is the number that gets you under 30%."
                }
                return reply(
                    text,
                    attachment: .init(title: "Paying \(money(amount))", value: outcome.points > 0 ? "≈ +\(outcome.points) pts" : "≈ 0 pts", subtitle: "\(card.name) → \(percent(after.utilization))"),
                    suggestions: ["What if I pay it all off?", "When does it report?"],
                    action: .openSimulator
                )
            }
            // Otherwise: the number that actually clears the threshold.
            let target = worst.payoff(toReach: 0.29).roundedUpToNearest(5)
            guard target > 0 else {
                return reply("Nothing needed — your \(worst.name) is already under 30%.", suggestions: ["What's my next move?"])
            }
            let points = ScoreSimulator.pointsForPayingDown(cards: c.cards, amount: target, on: worst)
            return reply(
                "**\(money(target))** on your \(worst.name), before it reports on the \(ordinal(worst.statementDay)). That drops it from \(percent(worst.utilization)) to just under 30% and should be worth about **\(points) points** next cycle. Anything more than that is good for your wallet but barely moves the score.",
                attachment: .init(title: "Pay \(money(target))", value: "≈ +\(points) pts", subtitle: "\(worst.name) · by the \(ordinal(worst.statementDay))"),
                suggestions: ["What if I pay \(money(target / 2))?", "What's after that?"]
            )

        case .bills:
            let reporting = c.reportingBills
            // If they named a bill, that's the one they mean.
            let named = c.offBills.first { query.tokens.contains($0.kind.label.lowercased()) }
            if let next = named ?? c.offBills.first {
                let names = reporting.isEmpty ? "nothing yet" : reporting.map { $0.kind.label.lowercased() }.joined(separator: " and ")
                return reply(
                    "You've got \(names) reporting. Your \(next.kind.label.lowercased()) isn't on yet — that's \(money(next.monthlyAmount)) a month you're already paying and getting no credit for. Want me to switch it on?",
                    suggestions: ["Which bills count?", "How far back does it go?"],
                    action: .turnOnBill(next.kind)
                )
            }
            guard !reporting.isEmpty else {
                return reply("None of your bills are reporting yet — and you're already paying them. Rent first: it's the biggest, and we can backdate up to 24 months of it.", suggestions: ["Which bills count?"])
            }
            let names = reporting.map { $0.kind.label.lowercased() }.joined(separator: ", ")
            return reply(
                "\(names.capitalizedFirst) are all reporting to the three bureaus, with \(c.maxBackdated) months backdated. That history counts the same as any other on-time account — it's why your file stopped reading as thin.",
                attachment: .init(title: "Reported bills", value: "\(reporting.count) live", subtitle: "\(c.maxBackdated) months backdated · all 3 bureaus"),
                suggestions: ["What's my next move?", "How's my builder account?"]
            )

        case .builder:
            guard c.builder.isOpen else {
                return reply("Your builder account isn't open yet — that's step one. A small reported line through our partner, no hard inquiry, building on-time history from month one.", suggestions: ["How much does it cost?"])
            }
            let tier = c.builder.tier
            return reply(
                "\(tier.displayName): a \(money(Decimal(tier.tradeline))) reported line at \(money(tier.monthlyFee))/mo, with **\(c.builder.onTimePayments) on-time payments** behind it. Next one is \(dateText(c.builder.nextPaymentDate)) and autopay has it. Nothing for you to do here.",
                attachment: .init(title: "Builder account", value: money(Decimal(tier.tradeline)), subtitle: "\(c.builder.onTimePayments) on-time · all 3 bureaus"),
                suggestions: ["When does it report?", "What's my next move?"]
            )

        case .nextMove where query.tokens.contains("why"):
            guard let worst = c.worstCard, c.nextMove?.isDone == false else {
                return reply("Because everything else on your file only moves with time. There's nothing to rush right now — the streak is doing the work.", suggestions: ["Show me my score"])
            }
            return reply(
                "Because it's the fastest thing you own. Utilization re-scores the month you change it — your \(worst.name) drops off \(percent(worst.utilization)) and the bureaus see it next cycle. Everything else on your list, thin file and account age, only fixes with months. So we take the one that pays this month and let the slow ones run underneath.",
                suggestions: ["How much should I pay?", "What's after that?"]
            )

        case .nextMove:
            guard let move = c.nextMove, !move.isDone else {
                return reply("Nothing needs you this week — everything on the plan is either done or running on its own. I'll ping you the moment that changes.", suggestions: ["Show me my score", "How's my rent reporting?"])
            }
            return reply(
                "\(move.detail) Worth about **\(move.estimatedPoints) points** this cycle.",
                attachment: .init(title: move.headline, value: "≈ +\(move.estimatedPoints) pts", subtitle: "By \(dateText(move.dueDate))"),
                suggestions: ["Why that one first?", "What's after that?"],
                action: .markMoveDone
            )

        case .timeline:
            let target = query.targetScore ?? nextBand(from: c.score)?.threshold
            guard let target, target > c.score else {
                return reply("You're already there. From here it's about holding the streak — the score keeps drifting up on its own as the history seasons.", suggestions: ["What's my next move?"])
            }
            guard let months = ScoreSimulator.monthsToReach(target, from: c.history) else {
                return reply("Your last few months have been flat, so I'd be making up a date. Get the plan moving again and I'll have a real answer within a cycle or two.", suggestions: ["What's my next move?"])
            }
            return reply(
                "About **\(months) months** to \(target), at the pace of your last six. That assumes the streak holds — one late payment resets it, and there's no shortcut around that.",
                attachment: .init(title: "To \(target)", value: "≈ \(months) mo", subtitle: "At your current pace, from \(c.score)"),
                suggestions: ["What would speed it up?", "What's my next move?"],
                action: .openSimulator
            )

        case .bureaus:
            return reply(
                "Everything we do lands at Experian, Equifax and TransUnion — the builder account and your bills both. The three differ by a few points because each sees a slightly different file, so don't read anything into a 10-point spread.",
                attachment: .init(title: "Reporting to", value: "All 3", subtitle: "Experian · Equifax · TransUnion"),
                suggestions: ["Show me my score", "What's my next move?"]
            )

        case .billing:
            return reply(
                "\(money(c.subscription.monthlyPrice))/mo for Launch, billed after each month of work, plus \(money(c.subscription.builderFee))/mo for the builder account — **\(money(c.subscription.totalMonthly)) total**. Next charge is \(dateText(c.subscription.renewsOn)). Cancel any time from your account; no contract, no cancellation fee.",
                attachment: .init(title: "Your plan", value: money(c.subscription.totalMonthly) + "/mo", subtitle: "Next charge \(dateText(c.subscription.renewsOn))"),
                suggestions: ["What's included?", "What's my next move?"]
            )

        case .simulate:
            return reply(
                "Let's test it before you do it. The simulator moves utilization, bills and the streak and shows exactly which factor each point came from.",
                suggestions: ["How much should I pay?", "How long to 700?"],
                action: .openSimulator
            )

        case .applying:
            if c.score < 640 {
                return reply(
                    "Not yet — and that's me protecting you. Applying now most likely means a denial plus a hard inquiry you keep for two years. Give it a few more months of on-time history first.",
                    suggestions: ["What would speed it up?", "How long until I'm ready?"]
                )
            }
            return reply(
                "Your file can carry an application now. Keep it to one — every application is a hard inquiry, and three in a month reads as strain no matter how clean the rest looks.",
                suggestions: ["Will applying hurt my score?", "What's my next move?"]
            )

        case .inquiries:
            return reply(
                "Ours is a **soft** pull — it never touches your score, and you can run it as often as you like. A hard inquiry only happens when *you* apply somewhere; that one costs a few points and sits on your file for two years.",
                suggestions: ["Am I ready to apply?", "What's my next move?"]
            )

        case .latePayment:
            return reply(
                "Under 30 days late: pay it now. Most lenders don't report until day 30, so you may still be clear. If it already reported it stays seven years, but it fades — the damage is worst in the first few months. Either way, what we do next is stack on-time months around it.",
                suggestions: ["What's my next move?", "How much should I pay?"]
            )

        case .collections:
            return reply(
                "Two things before you pay a collection: get it validated in writing, and get the payoff terms in writing. Paying an unvalidated account can restart the clock in some states. Send me the details and I'll walk you through it.",
                suggestions: ["How do I request validation?", "Does paying it help my score?"]
            )

        case .disputes:
            return reply(
                "If something isn't yours or isn't right, you dispute it with the bureau directly and they have 30 days to investigate. Straight answer: Launch is a credit-building service, not credit repair — we don't file disputes for you, but I'll help you get the facts straight before you do.",
                suggestions: ["What counts as an error?", "What's my next move?"]
            )

        case .thanks:
            return reply("Any time. I'm here at 2am too — that's the whole point.", suggestions: ["What's my next move?"])

        case .unknown:
            guard let fix = c.topFix else {
                return reply(
                    "Ask me anything about your file — your score, your balances, your bills, what to do next. I can see all of it.",
                    suggestions: ["What's my next move?", "How much should I pay?", "How much is Launch?"]
                )
            }
            return reply(
                "Not sure I follow — say it another way and I'll get it. If it helps, the biggest thing on your file right now is **\(fix.title.lowercased())**, costing you about \(fix.pointCost) points.",
                suggestions: ["What's my next move?", "How much should I pay?", "How long to 700?"]
            )
        }
    }

    // MARK: - Building a reply

    private static func reply(
        _ text: String,
        attachment: ChatMessage.Attachment? = nil,
        suggestions: [String] = [],
        action: CoachAction? = nil
    ) -> ChatMessage {
        ChatMessage(role: .coach, text: text, attachment: attachment, suggestions: suggestions, action: action)
    }

    // MARK: - Formatting

    static func signed(_ value: Int) -> String { value >= 0 ? "+\(value)" : "\(value)" }

    static func dateText(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }

    static func ordinal(_ day: Int) -> String {
        let suffix: String
        switch day {
        case 11, 12, 13: suffix = "th"
        default:
            switch day % 10 {
            case 1:  suffix = "st"
            case 2:  suffix = "nd"
            case 3:  suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(day)\(suffix)"
    }

    static func nextBand(from score: Int) -> (name: String, threshold: Int)? {
        let bands: [(Int, String)] = [(580, "Fair"), (670, "Good"), (740, "Very good"), (800, "Excellent")]
        guard let next = bands.first(where: { $0.0 > score }) else { return nil }
        return (next.1, next.0)
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

// MARK: - Remote coach

/// Posts to the Launch coach API when one is configured, and falls back to the
/// on-device engine on any failure — a member at 2am gets an answer either way.
///
/// Set `LAUNCH_COACH_URL` in Info.plist and store the bearer token in the
/// keychain under `coach.token`. No key is ever compiled into the binary.
struct RemoteCoach: CoachEngine {

    var fallback: CoachEngine = OnDeviceCoach()
    var session: URLSession = .shared

    private struct RequestBody: Encodable {
        var message: String
        var score: Int
        var utilization: Double
        var onTimeStreakMonths: Int
        var openFixes: [String]
    }

    private struct ResponseBody: Decodable {
        var reply: String
        var suggestions: [String]?
    }

    static var endpoint: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "LAUNCH_COACH_URL") as? String,
              !raw.isEmpty,
              let url = URL(string: raw),
              url.scheme == "https"
        else { return nil }
        return url
    }

    static var token: String? {
        Keychain.data(for: "coach.token").flatMap { String(data: $0, encoding: .utf8) }
    }

    func reply(to question: String, context: CoachContext, previousIntent: CoachIntent?) async -> ChatMessage {
        guard let endpoint = Self.endpoint, let token = Self.token else {
            return await fallback.reply(to: question, context: context, previousIntent: previousIntent)
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONEncoder().encode(
            RequestBody(
                message: question,
                score: context.score,
                utilization: context.utilization,
                onTimeStreakMonths: context.onTimeStreakMonths,
                openFixes: context.fixes.filter { $0.status != .done }.map(\.title)
            )
        )

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return await fallback.reply(to: question, context: context, previousIntent: previousIntent)
            }
            let body = try JSONDecoder().decode(ResponseBody.self, from: data)
            return ChatMessage(role: .coach, text: body.reply, suggestions: body.suggestions ?? [])
        } catch {
            return await fallback.reply(to: question, context: context, previousIntent: previousIntent)
        }
    }
}
