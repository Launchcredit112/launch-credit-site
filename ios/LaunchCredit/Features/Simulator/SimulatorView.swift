import SwiftUI

/// "Test a move first." The web calculator, made interactive: move the inputs
/// and watch where a year could take you.
struct SimulatorView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var utilization: Double = 0.28
    @State private var billsReported: Double = 2
    @State private var backdatedMonths: Double = 24
    @State private var onTimeMonths: Double = 12
    @State private var builderOpen = true
    @State private var newInquiries: Double = 0
    @State private var loaded = false

    private var result: ScoreSimulator.Result {
        ScoreSimulator.project(
            .init(
                startingScore: state.profile.score,
                overallUtilization: utilization,
                currentOverallUtilization: state.utilization,
                // Moving the overall dial moves the strained card with it.
                worstCardUtilization: min(worstCardNow, utilization / max(state.utilization, 0.01) * worstCardNow),
                currentWorstCardUtilization: worstCardNow,
                billsReported: Int(billsReported),
                backdatedMonths: Int(backdatedMonths),
                builderOpen: builderOpen,
                onTimeMonths: Int(onTimeMonths),
                newHardInquiries: Int(newInquiries)
            )
        )
    }

    private var worstCardNow: Double { ScoreSimulator.worstUtilization(of: state.cards) }

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.s1.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        resultCard
                        contributionsCard
                        controls
                        disclaimer
                    }
                    .padding(Metrics.gutter)
                }
            }
            .navigationTitle("What-if simulator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(BrandFont.body(16, weight: .semibold))
                        .tint(Brand.greenDk)
                }
            }
            .onAppear(perform: loadCurrentState)
        }
    }

    private func loadCurrentState() {
        guard !loaded else { return }
        loaded = true
        utilization = state.utilization
        billsReported = Double(state.bills.filter { $0.state == .reporting }.count)
        backdatedMonths = Double(state.bills.filter { $0.state == .reporting }.map(\.backdatedMonths).max() ?? 0)
        onTimeMonths = Double(state.profile.onTimeStreakMonths)
        builderOpen = state.builder.isOpen
    }

    // MARK: - Result

    private var resultCard: some View {
        Card(padding: 22) {
            VStack(spacing: 16) {
                HStack(alignment: .top, spacing: 0) {
                    VStack(spacing: 4) {
                        Text("TODAY")
                            .font(BrandFont.heading(10.5, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(Brand.faint)
                        Text("\(state.profile.score)")
                            .font(BrandFont.number(38))
                            .tracking(-1.4)
                            .foregroundStyle(Brand.scoreColor(for: state.profile.score))
                        Text(creditBand(for: state.profile.score))
                            .font(BrandFont.body(13, weight: .semibold))
                            .foregroundStyle(Brand.dim)
                    }
                    .frame(maxWidth: .infinity)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Brand.faint)
                        .padding(.top, 24)

                    VStack(spacing: 4) {
                        Text("PROJECTED")
                            .font(BrandFont.heading(10.5, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(Brand.faint)
                        Text("\(result.projected)")
                            .font(BrandFont.number(38))
                            .tracking(-1.4)
                            .foregroundStyle(Brand.scoreColor(for: result.projected))
                            .contentTransition(.numericText())
                        Text(creditBand(for: result.projected))
                            .font(BrandFont.body(13, weight: .semibold))
                            .foregroundStyle(Brand.dim)
                    }
                    .frame(maxWidth: .infinity)
                }

                Text(result.delta >= 0 ? "+\(result.delta) points" : "\(result.delta) points")
                    .font(BrandFont.heading(17, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(result.delta >= 0 ? AnyShapeStyle(Brand.grad) : AnyShapeStyle(Brand.red), in: Capsule())
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: result.delta)

                if creditBand(for: result.projected) != creditBand(for: state.profile.score) {
                    Text("You'd cross out of \(creditBand(for: state.profile.score)) and into \(creditBand(for: result.projected)).")
                        .font(BrandFont.body(14, weight: .medium))
                        .foregroundStyle(Brand.dim)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Contributions

    @ViewBuilder
    private var contributionsCard: some View {
        if !result.contributions.isEmpty {
            Card {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Where the points come from")
                        .font(BrandFont.heading(16))
                        .foregroundStyle(Brand.ink)
                        .padding(.bottom, 6)

                    ForEach(Array(result.contributions.enumerated()), id: \.element.id) { index, item in
                        StatRow(label: item.label, showsDivider: index < result.contributions.count - 1) {
                            Chip(
                                text: item.points >= 0 ? "+\(item.points) pts" : "\(item.points) pts",
                                tone: item.points >= 0 ? .good : .cost
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Controls

    private var controls: some View {
        Card {
            VStack(alignment: .leading, spacing: 20) {
                SimSlider(
                    title: "Overall utilization",
                    value: $utilization,
                    range: 0...1,
                    step: 0.01,
                    display: "\(Int((utilization * 100).rounded()))%",
                    caption: utilization <= 0.30 ? "Under 30% — where you want it" : "Over 30% — this is the loudest factor"
                )

                SimSlider(
                    title: "Bills reported",
                    value: $billsReported,
                    range: 0...6,
                    step: 1,
                    display: "\(Int(billsReported))",
                    caption: "Rent, phone, power, internet"
                )

                SimSlider(
                    title: "Months backdated",
                    value: $backdatedMonths,
                    range: 0...24,
                    step: 1,
                    display: "\(Int(backdatedMonths)) mo",
                    caption: "Launch backdates up to 24 months"
                )

                SimSlider(
                    title: "On-time streak",
                    value: $onTimeMonths,
                    range: 0...24,
                    step: 1,
                    display: "\(Int(onTimeMonths)) mo",
                    caption: "The part that compounds"
                )

                SimSlider(
                    title: "New hard inquiries",
                    value: $newInquiries,
                    range: 0...5,
                    step: 1,
                    display: "\(Int(newInquiries))",
                    caption: "Each application costs a few points for two years"
                )

                Toggle(isOn: $builderOpen) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Builder account open")
                            .font(BrandFont.body(15, weight: .semibold))
                            .foregroundStyle(Brand.ink)
                        Text("A reported line through our partner")
                            .font(BrandFont.body(12.5))
                            .foregroundStyle(Brand.faint)
                    }
                }
                .tint(Brand.green)
            }
        }
    }

    private var disclaimer: some View {
        Text("An estimate, not a promise. Scoring models weigh dozens of factors and each bureau sees a slightly different file — treat this as direction, not a guarantee.")
            .font(BrandFont.body(12))
            .foregroundStyle(Brand.faint)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Slider row

struct SimSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let display: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title)
                    .font(BrandFont.body(15, weight: .semibold))
                    .foregroundStyle(Brand.ink)
                Spacer()
                Text(display)
                    .font(BrandFont.number(15))
                    .foregroundStyle(Brand.greenDk)
            }
            Slider(value: $value, in: range, step: step)
                .tint(Brand.green)
            Text(caption)
                .font(BrandFont.body(12.5))
                .foregroundStyle(Brand.faint)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    SimulatorView().environmentObject(AppState())
}
