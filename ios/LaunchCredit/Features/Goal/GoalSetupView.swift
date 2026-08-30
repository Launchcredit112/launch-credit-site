import SwiftUI

/// Pick what you're actually trying to do. The score follows from it.
struct GoalSetupView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var kind: Goal.Kind = .auto
    @State private var amountText = ""

    private var amount: Decimal {
        guard kind.needsAmount else { return 0 }
        let digits = amountText.filter(\.isNumber)
        return Decimal(string: digits).map { max($0, 1_000) } ?? kind.defaultAmount
    }

    private var preview: GoalPlan {
        GoalEngine.plan(for: Goal(kind: kind, amount: amount), context: state.coachContext)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.s1.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Tell me what you're aiming at and I'll work backwards from it — the score you need, what it costs you to wait, and the steps in between.")
                            .font(BrandFont.body(15))
                            .foregroundStyle(Brand.dim)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(spacing: 10) {
                            ForEach(Goal.Kind.allCases) { option in
                                GoalKindRow(kind: option, isSelected: kind == option) {
                                    Haptics.tap()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                        kind = option
                                        amountText = ""
                                    }
                                }
                            }
                        }

                        if kind.needsAmount {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("How much?")
                                    .font(BrandFont.heading(15))
                                    .foregroundStyle(Brand.ink)
                                BrandField(
                                    placeholder: money(kind.defaultAmount),
                                    text: $amountText,
                                    keyboard: .numberPad
                                )
                            }
                        }

                        outcome

                        Button(state.goal?.kind == kind ? "Update my goal" : "Track this goal") {
                            Haptics.success()
                            state.setGoal(Goal(kind: kind, amount: amount))
                            dismiss()
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        if state.goal != nil {
                            Button("Stop tracking") {
                                state.setGoal(nil)
                                dismiss()
                            }
                            .font(BrandFont.body(14, weight: .semibold))
                            .foregroundStyle(Brand.red)
                            .frame(maxWidth: .infinity)
                        }

                        Text("Rates shown are indicative by score band, not quotes. What you're actually offered depends on the lender, your income and the rest of your file.")
                            .font(BrandFont.body(12))
                            .foregroundStyle(Brand.faint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(Metrics.gutter)
                }
            }
            .navigationTitle("Your goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }.tint(Brand.dim)
                }
            }
            .onAppear {
                if let existing = state.goal {
                    kind = existing.kind
                    if existing.kind.needsAmount { amountText = "\(NSDecimalNumber(decimal: existing.amount).intValue)" }
                }
            }
        }
    }

    /// The whole reason to set a goal: seeing what the gap costs.
    private var outcome: some View {
        Card(padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Text("WHAT THIS TAKES")
                    .font(BrandFont.heading(10.5, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Brand.faint)

                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("You're at")
                            .font(BrandFont.body(12.5))
                            .foregroundStyle(Brand.faint)
                        Text("\(preview.currentScore)")
                            .font(BrandFont.number(26))
                            .foregroundStyle(Brand.ink)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("You need")
                            .font(BrandFont.body(12.5))
                            .foregroundStyle(Brand.faint)
                        Text("\(preview.targetScore)")
                            .font(BrandFont.number(26))
                            .foregroundStyle(Brand.greenDk)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("About")
                            .font(BrandFont.body(12.5))
                            .foregroundStyle(Brand.faint)
                        Text(preview.isReadyToday ? "Ready" : preview.monthsToTarget.map { "\($0) mo" } ?? "—")
                            .font(BrandFont.number(26))
                            .foregroundStyle(Brand.ink)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let today = preview.todayTerms, let target = preview.targetTerms {
                    Rectangle().fill(Brand.line).frame(height: 1)
                    VStack(spacing: 0) {
                        StatRow(label: "At \(preview.currentScore) today", value: "\(money(today.monthlyPayment))/mo · \(today.aprText)")
                        StatRow(
                            label: "At \(preview.targetScore)",
                            value: "\(money(target.monthlyPayment))/mo · \(target.aprText)",
                            showsDivider: preview.lifetimeSaving != nil
                        )
                        if let saving = preview.lifetimeSaving {
                            StatRow(label: "You'd keep", showsDivider: false) {
                                Chip(text: money(saving), tone: .good)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct GoalKindRow: View {
    let kind: Goal.Kind
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: kind.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isSelected ? Brand.greenDk : Brand.dim)
                    .frame(width: 42, height: 42)
                    .background(isSelected ? Brand.wash : Brand.s3, in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                Text(kind.title)
                    .font(BrandFont.heading(16))
                    .foregroundStyle(Brand.ink)

                Spacer()

                ZStack {
                    Circle().stroke(isSelected ? Brand.green : Brand.line2, lineWidth: 1.6)
                    if isSelected { Circle().fill(Brand.green).frame(width: 12, height: 12) }
                }
                .frame(width: 22, height: 22)
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Brand.s2, in: RoundedRectangle(cornerRadius: Metrics.radiusTile, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.radiusTile, style: .continuous)
                    .stroke(isSelected ? Brand.green : Brand.line, lineWidth: isSelected ? 1.6 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    GoalSetupView().environmentObject(AppState())
}
