import Foundation

/// Everything the coach is allowed to reason about. The site's promise is that
/// the coach "knows your balances and your dates" — this is that knowledge,
/// passed explicitly so answers stay grounded in the member's real file.
struct CoachContext {
    var firstName: String
    var score: Int
    var changeSinceStart: Int
    var utilization: Double
    var previousUtilization: Double
    var onTimeStreakMonths: Int
    var builder: BuilderAccount
    var bills: [BillAccount]
    var fixes: [FixItem]
    var nextMove: NextMove?
    var subscription: Subscription

    var reportingBills: [BillAccount] { bills.filter { $0.state == .reporting } }
    var topFix: FixItem? { fixes.filter { $0.status != .done }.max(by: { $0.pointCost < $1.pointCost }) }
}

protocol CoachEngine {
    func reply(to question: String, context: CoachContext) async -> ChatMessage
}

// MARK: - Intent

enum CoachIntent: CaseIterable {
    case greeting
    case score
    case utilization
    case rentAndBills
    case builderAccount
    case nextMove
    case timeline
    case bureaus
    case billing
    case simulate
    case marketplace
    case hardInquiry
    case latePayment
    case collections
    case disputes
    case thanks
    case unknown

    /// Words that pull an utterance toward this intent. Longer phrases score
    /// higher than single words so "pay off my card" beats a bare "card".
    var keywords: [String] {
        switch self {
        case .greeting:       return ["hi", "hello", "hey", "good morning", "good evening", "what's up"]
        case .score:          return ["score", "my score", "points", "fico", "vantage", "how am i doing", "where do i stand", "credit score"]
        case .utilization:    return ["utilization", "utilisation", "balance", "balances", "credit card", "card", "maxed", "limit", "how much should i pay", "pay down", "pay off"]
        case .rentAndBills:   return ["rent", "bill", "bills", "phone bill", "utility", "utilities", "power", "internet", "backdate", "landlord", "lease"]
        case .builderAccount: return ["builder", "builder account", "tradeline", "credit line", "credit builder", "loan", "tier", "upgrade my tier"]
        case .nextMove:       return ["next", "next move", "what should i do", "what do i do", "todo", "to do", "this month", "my plan", "step"]
        case .timeline:       return ["how long", "when will", "how many months", "timeline", "how fast", "how soon", "by when"]
        case .bureaus:        return ["bureau", "bureaus", "experian", "equifax", "transunion", "report to", "reporting to"]
        case .billing:        return ["price", "cost", "charge", "billing", "subscription", "cancel", "refund", "how much is launch", "payment date", "free"]
        case .simulate:       return ["what if", "simulate", "simulator", "would happen", "if i pay", "if i open", "projection", "forecast"]
        case .marketplace:    return ["offer", "offers", "apply", "new card", "which card", "refinance", "auto loan", "mortgage", "approved"]
        case .hardInquiry:    return ["hard inquiry", "hard pull", "soft pull", "soft check", "inquiry", "inquiries", "does it hurt", "lower my score"]
        case .latePayment:    return ["late", "missed", "missed a payment", "past due", "behind", "delinquent", "30 days"]
        case .collections:    return ["collection", "collections", "charge off", "charge-off", "debt collector", "settle"]
        case .disputes:       return ["dispute", "error", "wrong", "not mine", "fraud", "identity theft", "remove"]
        case .thanks:         return ["thank", "thanks", "appreciate", "got it", "cool", "nice"]
        case .unknown:        return []
        }
    }

    static func classify(_ text: String) -> CoachIntent {
        let haystack = " " + text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) + " "

        var best: (intent: CoachIntent, score: Int) = (.unknown, 0)
        for intent in CoachIntent.allCases where intent != .unknown {
            var score = 0
            for keyword in intent.keywords where haystack.contains(" " + keyword) || haystack.contains(keyword + " ") {
                // Multi-word phrases are much stronger evidence than one word.
                score += keyword.contains(" ") ? 5 : 2
            }
            if score > best.score { best = (intent, score) }
        }
        return best.score > 0 ? best.intent : .unknown
    }
}

// MARK: - On-device coach

/// Answers from the member's own file. Deterministic, private, and available
/// with no network — the site promises the coach at 2am, and this delivers it
/// even when the phone is offline.
struct OnDeviceCoach: CoachEngine {

    /// A beat of thinking time so replies land like a conversation rather than
    /// a lookup table.
    var thinkingDelay: Duration = .milliseconds(650)

    func reply(to question: String, context c: CoachContext) async -> ChatMessage {
        try? await Task.sleep(for: thinkingDelay)
        return Self.answer(to: question, context: c)
    }

    /// Pure and synchronous, so it can be unit-tested and previewed directly.
    static func answer(to question: String, context c: CoachContext) -> ChatMessage {
        switch CoachIntent.classify(question) {

        case .greeting:
            return ChatMessage(
                role: .coach,
                text: "Hey \(c.firstName). You're at \(c.score) — \(signed(c.changeSinceStart)) since you started. What do you want to look at?",
                suggestions: ["What's my next move?", "Why is my score stuck?", "How's my rent reporting?"]
            )

        case .score:
            let band = creditBand(for: c.score)
            let nextBand = nextBandThreshold(from: c.score)
            var text = "You're at **\(c.score)** — that's \(band.lowercased()), and \(signed(c.changeSinceStart)) since day one."
            if let nextBand {
                text += " \(nextBand.points) more points puts you in \(nextBand.name)."
            }
            text += " The on-time streak on your builder account is \(c.builder.onTimePayments) months, and that's the part doing the quiet work."
            return ChatMessage(
                role: .coach,
                text: text,
                attachment: .init(title: "Your score", value: "\(c.score)", subtitle: "\(band) · \(signed(c.changeSinceStart)) since you joined"),
                suggestions: ["What's holding it back?", "How long to \(nextBand?.name ?? "the next band")?"]
            )

        case .utilization:
            let now = Int((c.utilization * 100).rounded())
            let was = Int((c.previousUtilization * 100).rounded())
            if c.utilization <= 0.30 {
                return ChatMessage(
                    role: .coach,
                    text: "Utilization is **\(now)%**, down from \(was)%. Under 30% is where you want it, so leave it there — don't close the card, just keep the balance low and let it report each month.",
                    suggestions: ["What should I fix next?", "Would paying it to zero help?"]
                )
            }
            return ChatMessage(
                role: .coach,
                text: "Utilization is **\(now)%** — that's the single loudest thing on your file right now. Getting one card under 30% before its statement date is usually worth about 8–12 points in the next cycle, and it moves faster than anything else you can do.",
                attachment: .init(title: "Utilization", value: "\(now)%", subtitle: "Was \(was)% · target is under 30%"),
                suggestions: ["How much do I need to pay?", "When does it report?"]
            )

        case .rentAndBills:
            let reporting = c.reportingBills
            if reporting.isEmpty {
                return ChatMessage(
                    role: .coach,
                    text: "You aren't getting credit for any of your bills yet — and you're already paying them. Add rent first: it's the biggest one, and we can backdate up to 24 months of it onto your report.",
                    suggestions: ["Which bills count?", "What's my next move?"]
                )
            }
            let names = reporting.map { $0.kind.label.lowercased() }.joined(separator: ", ")
            let backdated = reporting.map(\.backdatedMonths).max() ?? 0
            return ChatMessage(
                role: .coach,
                text: "You've got \(names) reporting to all three bureaus, with \(backdated) months backdated. That history counts the same as any other on-time account — it's why your file stopped reading as thin.",
                attachment: .init(
                    title: "Reported bills",
                    value: "\(reporting.count) live",
                    subtitle: "\(backdated) months backdated · all 3 bureaus"
                ),
                suggestions: ["Can I turn on another bill?", "What's my next move?"]
            )

        case .builderAccount:
            guard c.builder.isOpen else {
                return ChatMessage(
                    role: .coach,
                    text: "Your builder account isn't open yet — that's step one. It's a small reported line through our partner, no hard inquiry, and it starts building on-time history from the first month.",
                    suggestions: ["How much does it cost?", "What's my next move?"]
                )
            }
            let tier = c.builder.tier
            return ChatMessage(
                role: .coach,
                text: "Your \(tier.displayName) builder account is open — a \(money(tier.tradeline)) reported line at \(money(tier.monthlyFee))/mo, with \(c.builder.onTimePayments) on-time payments behind it. Next payment is \(dateText(c.builder.nextPaymentDate)); autopay has it.",
                attachment: .init(
                    title: "Builder account",
                    value: money(tier.tradeline),
                    subtitle: "\(c.builder.onTimePayments) on-time · all 3 bureaus"
                ),
                suggestions: ["When does it report?", "What's my next move?"]
            )

        case .nextMove:
            guard let move = c.nextMove, !move.isDone else {
                return ChatMessage(
                    role: .coach,
                    text: "Nothing needs you this week — everything on the plan is either done or running on its own. I'll ping you the moment that changes.",
                    suggestions: ["Show my fix list", "How's my score trending?"]
                )
            }
            return ChatMessage(
                role: .coach,
                text: "One thing: \(move.detail) Do it before \(dateText(move.dueDate)) and you should pick up about \(move.estimatedPoints) points this cycle.",
                attachment: .init(title: move.headline, value: "≈ +\(move.estimatedPoints) pts", subtitle: "By \(dateText(move.dueDate))"),
                suggestions: ["Mark it done", "Why that one first?"]
            )

        case .timeline:
            let horizon = c.score < 620 ? "6 to 9 months" : "3 to 6 months"
            return ChatMessage(
                role: .coach,
                text: "Honest answer: \(horizon) for the next real jump. Utilization moves in a cycle or two, but thin-file and history problems only fix with months of on-time payments — there's no shortcut, and anyone who tells you otherwise is selling one.",
                suggestions: ["What moves fastest?", "Run a what-if"]
            )

        case .bureaus:
            return ChatMessage(
                role: .coach,
                text: "Everything we do lands at Experian, Equifax and TransUnion — the builder account and your bills both. Scores differ a little between them because each bureau sees a slightly different file, so don't panic at a 10-point spread.",
                attachment: .init(title: "Reporting to", value: "All 3", subtitle: "Experian · Equifax · TransUnion"),
                suggestions: ["Show me each bureau", "Why are they different?"]
            )

        case .billing:
            return ChatMessage(
                role: .coach,
                text: "Launch is \(money(c.subscription.monthlyPrice))/mo, billed after each month of work, plus \(money(c.subscription.builderFee))/mo for the builder account — \(money(c.subscription.totalMonthly)) total. Next charge is \(dateText(c.subscription.renewsOn)). Cancel any time from Settings; no contract, no cancellation fee.",
                attachment: .init(title: "Your plan", value: money(c.subscription.totalMonthly) + "/mo", subtitle: "Next charge \(dateText(c.subscription.renewsOn))"),
                suggestions: ["What's included?", "How do I cancel?"]
            )

        case .simulate:
            return ChatMessage(
                role: .coach,
                text: "Let's test it before you do it. Open the What-if simulator and move the sliders — it'll show what a payment, a new account or an added bill does to your score before anything hits your report.",
                suggestions: ["Open the simulator", "What if I pay off my card?"]
            )

        case .marketplace:
            if c.score < 640 {
                return ChatMessage(
                    role: .coach,
                    text: "Not yet — and that's me protecting you. Applying now most likely means a denial and a hard inquiry you keep for two years. Give it a few more months of on-time history and I'll surface the offers that actually match your file.",
                    suggestions: ["What gets me there faster?", "How long until I'm ready?"]
                )
            }
            return ChatMessage(
                role: .coach,
                text: "Your file's ready for a look. I only surface products that match where you actually are — and I'll tell you outright when we earn a commission on one.",
                suggestions: ["Show me offers", "Will applying hurt my score?"]
            )

        case .hardInquiry:
            return ChatMessage(
                role: .coach,
                text: "Our check is a **soft** pull — it never touches your score, and you can run it as often as you like. A hard inquiry only happens when *you* apply for credit somewhere; that one costs a few points and sits on your file for two years.",
                suggestions: ["Am I ready to apply?", "What's my next move?"]
            )

        case .latePayment:
            return ChatMessage(
                role: .coach,
                text: "If it's under 30 days late, pay it now — most lenders don't report until day 30, so you may still be clear. If it already reported, it stays 7 years, but it fades: the damage is worst in the first few months and thins out from there. What we do next is stack on-time months around it.",
                suggestions: ["Set up autopay", "How much did it cost me?"]
            )

        case .collections:
            return ChatMessage(
                role: .coach,
                text: "Don't pay a collection before you've done two things: get it validated in writing, and get the payoff terms in writing. Paying an unvalidated account can restart the clock in some states. Send me the details and I'll walk you through it line by line.",
                suggestions: ["How do I request validation?", "Does paying it help my score?"]
            )

        case .disputes:
            return ChatMessage(
                role: .coach,
                text: "If something on your report isn't yours or isn't right, you can dispute it directly with the bureau and they have 30 days to investigate. Be clear that Launch is a credit-building service, not credit repair — we don't file disputes for you, but I'll help you get the facts straight before you file.",
                suggestions: ["What counts as an error?", "Show my report"]
            )

        case .thanks:
            return ChatMessage(
                role: .coach,
                text: "Any time. I'm here at 2am too — that's the whole point.",
                suggestions: ["What's my next move?"]
            )

        case .unknown:
            var text = "I want to make sure I answer the right thing. "
            if let fix = c.topFix {
                text += "The biggest thing on your file right now is **\(fix.title.lowercased())**, costing you about \(fix.pointCost) points. Want to start there?"
            } else {
                text += "Ask me about your score, your balances, your bills, or what to do next — I can see all of it."
            }
            return ChatMessage(
                role: .coach,
                text: text,
                suggestions: ["What's my next move?", "Why is my score stuck?", "How much is Launch?"]
            )
        }
    }

    // MARK: - Formatting helpers

    static func signed(_ value: Int) -> String { value >= 0 ? "+\(value)" : "\(value)" }

    static func money(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }

    static func money(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = value == value.rounded() ? 0 : 2
        return formatter.string(from: value as NSDecimalNumber) ?? "$\(value)"
    }

    static func dateText(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }

    static func nextBandThreshold(from score: Int) -> (name: String, points: Int)? {
        let bands: [(Int, String)] = [(580, "Fair"), (670, "Good"), (740, "Very good"), (800, "Excellent")]
        guard let next = bands.first(where: { $0.0 > score }) else { return nil }
        return (next.1, next.0 - score)
    }
}

private extension Decimal {
    func rounded() -> Decimal {
        var input = self
        var result = Decimal()
        NSDecimalRound(&result, &input, 0, .plain)
        return result
    }
}

// MARK: - Remote coach

/// Talks to the Launch coach API when one is configured, and falls back to the
/// on-device engine whenever the call fails — a member at 2am gets an answer
/// either way.
///
/// Configure by setting `LAUNCH_COACH_URL` in the app's Info.plist. The bearer
/// token is read from the keychain and is never compiled into the binary.
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

    func reply(to question: String, context: CoachContext) async -> ChatMessage {
        guard let endpoint = Self.endpoint, let token = Self.token else {
            return await fallback.reply(to: question, context: context)
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
                return await fallback.reply(to: question, context: context)
            }
            let body = try JSONDecoder().decode(ResponseBody.self, from: data)
            return ChatMessage(role: .coach, text: body.reply, suggestions: body.suggestions ?? [])
        } catch {
            return await fallback.reply(to: question, context: context)
        }
    }
}
