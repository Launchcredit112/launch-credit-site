import SwiftUI

/// Where you stand, and the one thing to do about it. Everything else on this
/// screen is a way into the four things Launch does.
struct HomeView: View {
    @EnvironmentObject private var state: AppState
    @Binding var selection: MainTabView.Tab

    @State private var showingAccount = false
    @State private var showingSimulator = false

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackground()

                ScrollView {
                    VStack(spacing: Metrics.sectionGap) {
                        greeting
                        scoreCard
                        nextMoveCard
                        VStack(spacing: 12) {
                            snapshotCard
                            bureausCard
                        }
                        simulatorCard
                        disclosure
                    }
                    .padding(.horizontal, Metrics.gutter)
                    .padding(.bottom, 30)
                }
                .refreshable { await refresh() }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingAccount) { AccountView() }
            .sheet(isPresented: $showingSimulator) { SimulatorView() }
        }
    }

    // MARK: - Greeting

    private var greeting: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                (
                    Text(timeGreeting + ", ").foregroundStyle(Brand.dim)
                    + Text(state.user?.firstName ?? "there").foregroundStyle(Brand.ink)
                )
                .font(BrandFont.heading(19, weight: .semibold))
                .tracking(-0.4)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

                HStack(spacing: 6) {
                    Circle()
                        .fill(Brand.greenBr)
                        .frame(width: 6, height: 6)
                    Text("Synced \(state.profile.lastRefreshed.formatted(.relative(presentation: .named)))")
                        .font(BrandFont.body(12.5, weight: .medium))
                        .foregroundStyle(Brand.faint)
                }
            }

            Spacer(minLength: 8)

            AccountAvatar(
                initials: state.user?.initials ?? "L",
                // A quiet nudge toward the one setting that actually helps.
                showsBadge: !state.remindersOn
            ) {
                Haptics.tap()
                showingAccount = true
            }
        }
        .padding(.top, 8)
    }

    private var timeGreeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 0..<12:  return "Good morning"
        case 12..<18: return "Good afternoon"
        default:      return "Good evening"
        }
    }

    // MARK: - Score

    /// Score, trend and the three numbers that explain it, in one card — the
    /// whole picture without a scroll.
    private var scoreCard: some View {
        Card(padding: 22) {
            VStack(spacing: 14) {
                ScoreDial(score: state.profile.score, change: state.profile.changeSinceStart)
                ScoreTrendChart(points: state.profile.history)
                Text("Last 12 months")
                    .font(BrandFont.body(12.5, weight: .semibold))
                    .foregroundStyle(Brand.faint)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// The three numbers that explain the score, sitting directly above the
    /// bureaus they are reported to.
    private var snapshotCard: some View {
        Card(padding: 18) {
            HStack(alignment: .top, spacing: 10) {
                SnapshotStat(
                    key: "Utilization",
                    value: "\(Int((state.utilization * 100).rounded()))%",
                    note: "Down from \(Int((state.profile.previousUtilization * 100).rounded()))%"
                )
                SnapshotStat(
                    key: "Builder",
                    value: state.builder.isOpen ? "Open" : "Opening",
                    note: state.builder.isOpen ? "Reporting" : "Setting up"
                )
                SnapshotStat(
                    key: "Rent",
                    value: rentValue,
                    note: "\(maxBackdate) mo back"
                )
            }
        }
    }

    private var rentValue: String {
        guard let rent = state.bills.first(where: { $0.kind == .rent && $0.state == .reporting }) else { return "—" }
        return rent.monthlyAmount.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }

    private var maxBackdate: Int {
        state.bills.filter { $0.state == .reporting }.map(\.backdatedMonths).max() ?? 0
    }

    // MARK: - This week's move

    @ViewBuilder
    private var nextMoveCard: some View {
        if let move = state.nextMove, !move.isDone {
            Card(padding: 20, background: Brand.ink) {
                VStack(alignment: .leading, spacing: 13) {
                    HStack(spacing: 8) {
                        Circle().fill(Brand.greenLt).frame(width: 7, height: 7)
                        Text("YOUR NEXT STEP")
                            .font(BrandFont.heading(11, weight: .bold))
                            .tracking(1.8)
                            .foregroundStyle(Brand.greenLt)
                        Spacer()
                        Text(move.dueDate.formatted(.dateTime.month(.abbreviated).day()))
                            .font(BrandFont.number(13))
                            .foregroundStyle(Color.white.opacity(0.6))
                    }

                    Text(move.headline)
                        .font(BrandFont.heading(22))
                        .tracking(-0.5)
                        .foregroundStyle(.white)

                    Text(move.detail)
                        .font(BrandFont.body(15))
                        .foregroundStyle(Color.white.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        Button("Mark it done") {
                            Haptics.success()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                state.completeNextMove()
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle(fullWidth: false))

                        Button("Ask why") {
                            Haptics.tap()
                            state.askCoach("Why that one first?")
                            selection = .coach
                        }
                        .font(BrandFont.heading(15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.vertical, 15)
                        .padding(.horizontal, 20)
                        .background(Color.white.opacity(0.12), in: Capsule())
                    }
                    .padding(.top, 3)
                }
            }
        } else {
            Card(padding: 20) {
                HStack(spacing: 14) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Brand.greenBr)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("You're clear this week")
                            .font(BrandFont.heading(17))
                            .foregroundStyle(Brand.ink)
                        Text("Everything on the plan is running. We'll tell you the moment something needs you.")
                            .font(BrandFont.body(14))
                            .foregroundStyle(Brand.dim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: - Bureaus

    private var bureausCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 9) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Brand.greenDk)
                    Text("Reporting to all three bureaus")
                        .font(BrandFont.heading(16))
                        .foregroundStyle(Brand.ink)
                }

                HStack(spacing: 9) {
                    ForEach(state.profile.bureaus) { bureau in
                        VStack(spacing: 4) {
                            Text(bureau.bureau.shortName)
                                .font(BrandFont.heading(10.5, weight: .bold))
                                .tracking(1.2)
                                .foregroundStyle(Brand.faint)
                            Text("\(bureau.score)")
                                .font(BrandFont.number(23))
                                .foregroundStyle(Brand.ink)
                            Text("\(bureau.change >= 0 ? "+" : "")\(bureau.change)")
                                .font(BrandFont.body(12, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(bureau.change >= 0 ? Brand.greenDk : Brand.red)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Brand.s1, in: RoundedRectangle(cornerRadius: Metrics.radiusTile, style: .continuous))
                    }
                }
            }
        }
    }

    // MARK: - Tools

    private var simulatorCard: some View {
        ToolCard(
            icon: "slider.horizontal.below.rectangle",
            title: "What-if simulator",
            subtitle: "Test a move before you make it.",
            tint: Brand.irisWash,
            iconTint: Brand.iris
        ) { showingSimulator = true }
    }

    private var disclosure: some View {
        Text("Launch is a credit-building service — not credit repair. Individual results vary, and late payments can lower your score.")
            .font(BrandFont.body(12))
            .foregroundStyle(Brand.faint)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
    }

    private func refresh() async {
        try? await Task.sleep(for: .milliseconds(900))
        state.profile.lastRefreshed = Date()
    }
}

// MARK: - Pieces

/// One of the three numbers under the score: what it is, and which way it moved.
struct SnapshotStat: View {
    let key: String
    let value: String
    let note: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(key.uppercased())
                .font(BrandFont.heading(9.5, weight: .bold))
                .tracking(1.3)
                .foregroundStyle(Brand.faint)
            Text(value)
                .font(BrandFont.number(20))
                .tracking(-0.6)
                .foregroundStyle(Brand.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(note)
                .font(BrandFont.body(11.5, weight: .medium))
                .foregroundStyle(Brand.greenDk)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ToolCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color
    let iconTint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(iconTint)
                    .frame(width: 42, height: 42)
                    .background(tint, in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(BrandFont.heading(16))
                        .foregroundStyle(Brand.ink)
                    Text(subtitle)
                        .font(BrandFont.body(13))
                        .foregroundStyle(Brand.dim)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Brand.faint)
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Brand.s2, in: RoundedRectangle(cornerRadius: Metrics.radiusCard, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Metrics.radiusCard, style: .continuous).stroke(Brand.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView(selection: .constant(.home)).environmentObject(AppState())
}
