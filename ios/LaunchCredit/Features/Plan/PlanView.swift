import SwiftUI

/// "Ranked by what it costs you." — the diagnosis, hardest-hitting first, with
/// the one move that fixes each.
struct PlanView: View {
    @EnvironmentObject private var state: AppState
    @State private var expanded: Set<UUID> = []
    @State private var showingGoal = false
    @State private var showingMatches = false

    private var openFixes: [FixItem] {
        state.fixes.filter { $0.status != .done }.sorted { $0.pointCost > $1.pointCost }
    }

    private var doneFixes: [FixItem] {
        state.fixes.filter { $0.status == .done }
    }

    private var totalCost: Int {
        openFixes.reduce(0) { $0 + $1.pointCost }
    }

    /// Where the member lands if they clear the whole list.
    private var projectedScore: Int {
        min(850, state.profile.score + totalCost)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: Metrics.sectionGap) {
                        SectionHeader(
                            eyebrow: "Your plan",
                            plain: "Ranked by what it",
                            italic: "costs you.",
                            sub: "Not a wall of numbers. A short list, hardest-hitting first, with the exact move that fixes each one."
                        )
                        .padding(.top, 14)

                        goalCard
                        summaryCard

                        if !openFixes.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Still costing you")
                                    .font(BrandFont.heading(17))
                                    .foregroundStyle(Brand.ink)

                                ForEach(openFixes) { fix in
                                    FixCard(
                                        fix: fix,
                                        isExpanded: expanded.contains(fix.id),
                                        onToggle: { toggle(fix) },
                                        onDone: { Haptics.success(); state.setFixStatus(fix, to: .done) },
                                        onStart: { state.setFixStatus(fix, to: .inProgress) }
                                    )
                                }
                            }
                        }

                        if !doneFixes.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Handled")
                                    .font(BrandFont.heading(17))
                                    .foregroundStyle(Brand.ink)

                                ForEach(doneFixes) { fix in
                                    DoneFixRow(fix: fix)
                                }
                            }
                        }

                        Text("Point estimates are directional, based on how scoring models weigh each factor. They are not a guarantee.")
                            .font(BrandFont.body(12))
                            .foregroundStyle(Brand.faint)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, Metrics.gutter)
                    .padding(.bottom, 30)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingGoal) { GoalSetupView() }
            .sheet(isPresented: $showingMatches) { CardMatchesView() }
        }
    }

    // MARK: - Goal

    /// The plan reads better backwards: what you're aiming at, then what stands
    /// between you and it.
    @ViewBuilder
    private var goalCard: some View {
        if let plan = state.goalPlan {
            Button { showingGoal = true } label: {
                Card(padding: 20, background: Brand.ink) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 8) {
                            Image(systemName: plan.goal.kind.symbol)
                                .font(.system(size: 12, weight: .bold))
                            Text("YOUR GOAL")
                                .font(BrandFont.heading(11, weight: .bold))
                                .tracking(1.8)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .opacity(0.5)
                        }
                        .foregroundStyle(Brand.greenLt)

                        Text(plan.goal.title)
                            .font(BrandFont.heading(22))
                            .tracking(-0.5)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)

                        HStack(alignment: .top, spacing: 0) {
                            GoalStat(label: "Now", value: "\(plan.currentScore)")
                            GoalStat(label: "Need", value: "\(plan.targetScore)", tint: Brand.greenLt)
                            GoalStat(
                                label: plan.isReadyToday ? "Status" : "About",
                                value: plan.isReadyToday ? "Ready" : (plan.monthsToTarget.map { "\($0) mo" } ?? "—")
                            )
                        }

                        if let today = plan.todayTerms, let target = plan.targetTerms, let saving = plan.lifetimeSaving {
                            Text("At \(plan.currentScore) that's \(money(today.monthlyPayment))/mo at \(today.aprText). At \(plan.targetScore) it's \(money(target.monthlyPayment))/mo — **\(money(saving)) less** over the loan.")
                                .font(BrandFont.body(13.5))
                                .foregroundStyle(Color.white.opacity(0.75))
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if !plan.isReadyToday {
                            GoalProgressTrack(current: plan.currentScore, target: plan.targetScore, projected: plan.projectedScore)
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            if !state.cardMatches.isEmpty {
                ToolCard(
                    icon: "creditcard.fill",
                    title: "Card matches",
                    subtitle: "\(state.cardMatches.count) that fit your file, and why.",
                    tint: Brand.wash,
                    iconTint: Brand.greenDk
                ) { showingMatches = true }
            }
        } else {
            Button { showingGoal = true } label: {
                Card(padding: 18) {
                    HStack(spacing: 13) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Brand.iris)
                            .frame(width: 42, height: 42)
                            .background(Brand.irisWash, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("What are you building toward?")
                                .font(BrandFont.heading(16))
                                .foregroundStyle(Brand.ink)
                            Text("A car, a house, an apartment. I'll work the plan backwards from it.")
                                .font(BrandFont.body(13))
                                .foregroundStyle(Brand.dim)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 6)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Brand.faint)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var summaryCard: some View {
        Card(padding: 20) {
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("COSTING YOU")
                        .font(BrandFont.heading(10.5, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(Brand.faint)
                    Text("−\(totalCost) pts")
                        .font(BrandFont.number(30))
                        .tracking(-1)
                        .foregroundStyle(Brand.orange)
                    Text("across \(openFixes.count) open \(openFixes.count == 1 ? "issue" : "issues")")
                        .font(BrandFont.body(13))
                        .foregroundStyle(Brand.dim)
                }

                Rectangle().fill(Brand.line).frame(width: 1, height: 62)

                VStack(alignment: .leading, spacing: 5) {
                    Text("IF YOU FIX IT ALL")
                        .font(BrandFont.heading(10.5, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(Brand.faint)
                    Text("\(projectedScore)")
                        .font(BrandFont.number(30))
                        .tracking(-1)
                        .foregroundStyle(Brand.greenDk)
                    Text("\(creditBand(for: projectedScore)), from \(creditBand(for: state.profile.score).lowercased())")
                        .font(BrandFont.body(13))
                        .foregroundStyle(Brand.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func toggle(_ fix: FixItem) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            if expanded.contains(fix.id) { expanded.remove(fix.id) } else { expanded.insert(fix.id) }
        }
    }
}

// MARK: - Fix card

struct FixCard: View {
    let fix: FixItem
    let isExpanded: Bool
    let onToggle: () -> Void
    let onDone: () -> Void
    let onStart: () -> Void

    var body: some View {
        Card(padding: 18) {
            VStack(alignment: .leading, spacing: 13) {
                Button(action: onToggle) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 7) {
                            if fix.isBiggestWin {
                                Chip(text: "Biggest win", tone: .wash)
                            }
                            Text(fix.title)
                                .font(BrandFont.heading(17))
                                .tracking(-0.3)
                                .foregroundStyle(Brand.ink)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: 8) {
                                Chip(text: "−\(fix.pointCost) pts", tone: .cost)
                                Text("≈ \(fix.dollarCost.formatted(.currency(code: "USD").precision(.fractionLength(0))))/yr in interest")
                                    .font(BrandFont.body(12.5, weight: .medium))
                                    .foregroundStyle(Brand.faint)
                            }
                        }

                        Spacer(minLength: 6)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Brand.faint)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(alignment: .leading, spacing: 13) {
                        Text(fix.detail)
                            .font(BrandFont.body(14.5))
                            .foregroundStyle(Brand.dim)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("THE MOVE")
                                .font(BrandFont.heading(10.5, weight: .bold))
                                .tracking(1.5)
                                .foregroundStyle(Brand.greenDk)
                            Text(fix.move)
                                .font(BrandFont.body(14.5, weight: .semibold))
                                .foregroundStyle(Brand.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Brand.wash, in: RoundedRectangle(cornerRadius: Metrics.radiusTile, style: .continuous))

                        HStack(spacing: 10) {
                            Button("Mark done", action: onDone)
                                .buttonStyle(PrimaryButtonStyle(fullWidth: false))
                            if fix.status == .todo {
                                Button("Start it", action: onStart)
                                    .buttonStyle(LineButtonStyle(fullWidth: false))
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                } else if fix.status == .inProgress {
                    HStack(spacing: 7) {
                        Circle().fill(Brand.greenBr).frame(width: 6, height: 6)
                        Text("In progress")
                            .font(BrandFont.body(12.5, weight: .semibold))
                            .foregroundStyle(Brand.greenDk)
                    }
                }
            }
        }
    }
}

struct DoneFixRow: View {
    let fix: FixItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 19))
                .foregroundStyle(Brand.greenBr)
            Text(fix.title)
                .font(BrandFont.body(14.5, weight: .medium))
                .foregroundStyle(Brand.dim)
                .strikethrough(color: Brand.faint)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.s1, in: RoundedRectangle(cornerRadius: Metrics.radiusTile, style: .continuous))
    }
}

/// One of the three figures across the goal card.
struct GoalStat: View {
    let label: String
    let value: String
    var tint: Color = .white

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(BrandFont.heading(9.5, weight: .bold))
                .tracking(1.3)
                .foregroundStyle(Color.white.opacity(0.5))
            Text(value)
                .font(BrandFont.number(22))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Where the score sits between today and the goal, with the ghost of where
/// the plan would put it.
struct GoalProgressTrack: View {
    let current: Int
    let target: Int
    let projected: Int

    private var floor: Int { max(300, min(current, target) - 40) }

    private func fraction(_ score: Int) -> Double {
        let span = Double(max(1, target - floor))
        return min(1, max(0, Double(score - floor) / span))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.16))
                    Capsule()
                        .fill(Color.white.opacity(0.28))
                        .frame(width: fraction(projected) * geo.size.width)
                    Capsule()
                        .fill(Brand.grad)
                        .frame(width: fraction(current) * geo.size.width)
                }
            }
            .frame(height: 8)

            Text(projected >= target
                 ? "The steps below are enough to get you there."
                 : "The steps below get you to about \(projected). The rest is time.")
                .font(BrandFont.body(12))
                .foregroundStyle(Color.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Score \(current) of \(target) needed, projected \(projected)")
    }
}

#Preview {
    PlanView().environmentObject(AppState())
}
