import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var state: AppState
    @Binding var selection: MainTabView.Tab

    @State private var showingSimulator = false
    @State private var showingMarketplace = false

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackground()

                ScrollView {
                    VStack(spacing: Metrics.sectionGap) {
                        greeting
                        scoreCard
                        nextMoveCard
                        widgets
                        bureausCard
                        toolsRow
                        disclosure
                    }
                    .padding(.horizontal, Metrics.gutter)
                    .padding(.bottom, 30)
                }
                .refreshable { await refresh() }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingSimulator) { SimulatorView() }
            .sheet(isPresented: $showingMarketplace) { MarketplaceView() }
        }
    }

    // MARK: - Greeting

    private var greeting: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(timeGreeting)
                    .font(BrandFont.body(14, weight: .semibold))
                    .foregroundStyle(Brand.faint)
                Text(state.user?.firstName ?? "Welcome")
                    .font(BrandFont.heading(26))
                    .tracking(-0.7)
                    .foregroundStyle(Brand.ink)
            }
            Spacer()
            BrandMark(size: 44)
        }
        .padding(.top, 12)
    }

    private var timeGreeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 0..<12:  return "Good morning"
        case 12..<18: return "Good afternoon"
        default:      return "Good evening"
        }
    }

    // MARK: - Score

    private var scoreCard: some View {
        Card(padding: 24) {
            VStack(spacing: 18) {
                ScoreDial(score: state.profile.score, change: state.profile.changeSinceStart)

                ScoreTrendChart(points: state.profile.history)

                HStack {
                    Text("Last 12 months")
                        .font(BrandFont.body(13, weight: .semibold))
                        .foregroundStyle(Brand.faint)
                    Spacer()
                    Text("Updated \(state.profile.lastRefreshed.formatted(.dateTime.month(.abbreviated).day()))")
                        .font(BrandFont.body(13))
                        .foregroundStyle(Brand.faint)
                }
            }
        }
    }

    // MARK: - Next move

    @ViewBuilder
    private var nextMoveCard: some View {
        if let move = state.nextMove, !move.isDone {
            Card(padding: 20, background: Brand.ink) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Circle().fill(Brand.greenLt).frame(width: 7, height: 7)
                        Text("TODAY · COACH")
                            .font(BrandFont.heading(11, weight: .bold))
                            .tracking(1.8)
                            .foregroundStyle(Brand.greenLt)
                    }

                    Text("One move, this week.")
                        .font(BrandFont.heading(22))
                        .tracking(-0.5)
                        .foregroundStyle(.white)

                    Text(move.detail)
                        .font(BrandFont.body(15))
                        .foregroundStyle(Color.white.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        Chip(text: "≈ +\(move.estimatedPoints) pts", tone: .good)
                        Chip(text: "By \(move.dueDate.formatted(.dateTime.month(.abbreviated).day()))", tone: .neutral)
                    }

                    HStack(spacing: 10) {
                        Button("Mark it done") {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                state.completeNextMove()
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle(fullWidth: false))

                        Button("Ask why") { selection = .coach }
                            .font(BrandFont.heading(15, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.vertical, 15)
                            .padding(.horizontal, 20)
                            .background(Color.white.opacity(0.12), in: Capsule())
                    }
                    .padding(.top, 2)
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

    // MARK: - Widgets

    /// The four floating cards from the site's hero, as a grid.
    private var widgets: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            WidgetTile(
                key: "Utilization",
                value: "\(Int((state.profile.utilization * 100).rounded()))%",
                note: "Down from \(Int((state.profile.previousUtilization * 100).rounded()))%",
                emphasised: true
            )
            WidgetTile(
                key: "Builder account",
                value: state.builder.isOpen ? "Open" : "Not open",
                note: state.builder.isOpen ? "Reporting to all 3 bureaus" : "Open it to start building",
                emphasised: state.builder.isOpen
            )
            WidgetTile(
                key: "Rent reported",
                value: rentValue,
                note: "\(maxBackdate) months backdated",
                emphasised: true
            )
            WidgetTile(
                key: "On-time streak",
                value: "\(state.profile.onTimeStreakMonths) mo",
                note: "Every month stacks",
                emphasised: true
            )
        }
    }

    private var rentValue: String {
        guard let rent = state.bills.first(where: { $0.kind == .rent && $0.state == .reporting }) else { return "Not added" }
        return rent.monthlyAmount.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }

    private var maxBackdate: Int {
        state.bills.filter { $0.state == .reporting }.map(\.backdatedMonths).max() ?? 0
    }

    // MARK: - Bureaus

    private var bureausCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(Brand.greenDk)
                    Text("Reporting to all three bureaus")
                        .font(BrandFont.heading(17))
                        .foregroundStyle(Brand.ink)
                }

                HStack(spacing: 10) {
                    ForEach(state.profile.bureaus) { bureau in
                        VStack(spacing: 5) {
                            Text(bureau.bureau.shortName)
                                .font(BrandFont.heading(11, weight: .bold))
                                .tracking(1.2)
                                .foregroundStyle(Brand.faint)
                            Text("\(bureau.score)")
                                .font(BrandFont.number(24))
                                .foregroundStyle(Brand.ink)
                            Text("\(bureau.change >= 0 ? "+" : "")\(bureau.change)")
                                .font(BrandFont.body(12, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(bureau.change >= 0 ? Brand.greenDk : Brand.red)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Brand.s1, in: RoundedRectangle(cornerRadius: Metrics.radiusTile, style: .continuous))
                    }
                }

                Text("Scores differ a little between bureaus — each one sees a slightly different file.")
                    .font(BrandFont.body(13))
                    .foregroundStyle(Brand.faint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Tools

    private var toolsRow: some View {
        VStack(spacing: 14) {
            ToolCard(
                icon: "slider.horizontal.below.rectangle",
                title: "What-if simulator",
                subtitle: "Test a move before you make it.",
                tint: Brand.irisWash,
                iconTint: Brand.iris
            ) { showingSimulator = true }

            ToolCard(
                icon: "sparkles",
                title: "Marketplace",
                subtitle: "Offers picked for your file — not before it's ready.",
                tint: Brand.wash,
                iconTint: Brand.greenDk
            ) { showingMarketplace = true }
        }
    }

    // MARK: - Disclosure

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

/// `.wg-i` — the small stat card from the hero.
struct WidgetTile: View {
    let key: String
    let value: String
    let note: String
    var emphasised: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(key.uppercased())
                .font(BrandFont.heading(10.5, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(Brand.faint)
            Text(value)
                .font(BrandFont.number(26))
                .tracking(-0.8)
                .foregroundStyle(Brand.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(note)
                .font(BrandFont.body(12.5, weight: .medium))
                .foregroundStyle(emphasised ? Brand.greenDk : Brand.dim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Brand.s2, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Brand.line, lineWidth: 1))
        .shadow(color: Color(hex: 0x0B0D10, alpha: 0.05), radius: 10, x: 0, y: 3)
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
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(iconTint)
                    .frame(width: 44, height: 44)
                    .background(tint, in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(BrandFont.heading(16))
                        .foregroundStyle(Brand.ink)
                    Text(subtitle)
                        .font(BrandFont.body(13.5))
                        .foregroundStyle(Brand.dim)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Brand.faint)
            }
            .padding(16)
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
