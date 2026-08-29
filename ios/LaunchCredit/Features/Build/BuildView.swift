import SwiftUI

/// "Build history, not debt." The builder account and everything you already
/// pay, reported to all three bureaus.
struct BuildView: View {
    @EnvironmentObject private var state: AppState
    @State private var showingAddBill = false
    @State private var showingTierPicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: Metrics.sectionGap) {
                        SectionHeader(
                            eyebrow: "Build",
                            plain: "Build history,",
                            italic: "not debt.",
                            sub: "A reported line built for a thin file, plus credit for the bills you already pay."
                        )
                        .padding(.top, 14)

                        builderCard
                        billsSection
                        backdateCard
                    }
                    .padding(.horizontal, Metrics.gutter)
                    .padding(.bottom, 30)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingAddBill) { AddBillView() }
            .sheet(isPresented: $showingTierPicker) { TierPickerView() }
        }
    }

    // MARK: - Builder account

    private var builderCard: some View {
        Card(padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("BUILDER ACCOUNT")
                            .font(BrandFont.heading(10.5, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(Brand.faint)
                        Text(state.builder.isOpen ? "\(state.builder.tier.displayName) · open" : "Not open yet")
                            .font(BrandFont.heading(21))
                            .tracking(-0.5)
                            .foregroundStyle(Brand.ink)
                    }
                    Spacer()
                    if state.builder.isOpen {
                        LiveBadge(text: "Reporting")
                    }
                }

                if state.builder.isOpen {
                    VStack(spacing: 0) {
                        StatRow(label: "Reported tradeline", value: state.builder.tier.tradeline.formatted(.currency(code: "USD").precision(.fractionLength(0))))
                        StatRow(label: "Partner fee", value: state.builder.tier.monthlyFee.formatted(.currency(code: "USD").precision(.fractionLength(0))) + "/mo")
                        StatRow(label: "On-time payments") {
                            Chip(text: "\(state.builder.onTimePayments) months", tone: .good)
                        }
                        StatRow(label: "Hard inquiry") {
                            Chip(text: "None", tone: .good)
                        }
                        StatRow(label: "Next payment", value: state.builder.nextPaymentDate.formatted(.dateTime.month(.abbreviated).day()), showsDivider: false)
                    }

                    Button("Change tier") { showingTierPicker = true }
                        .buttonStyle(LineButtonStyle())
                } else {
                    Text("A small, low-cost line through our lending partner — reporting to all three bureaus from month one, with no hard inquiry.")
                        .font(BrandFont.body(14.5))
                        .foregroundStyle(Brand.dim)
                        .fixedSize(horizontal: false, vertical: true)

                    Button("Open my builder account") { showingTierPicker = true }
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
    }

    // MARK: - Bills

    private var billsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your bills")
                    .font(BrandFont.heading(19))
                    .foregroundStyle(Brand.ink)
                Spacer()
                Button {
                    showingAddBill = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                        Text("Add")
                    }
                    .font(BrandFont.body(14.5, weight: .bold))
                    .foregroundStyle(Brand.greenDk)
                }
            }

            ForEach(state.bills) { bill in
                BillRow(bill: bill) { newState in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        state.setBill(bill, state: newState)
                    }
                }
            }
        }
    }

    // MARK: - Backdating

    private var backdateCard: some View {
        Card(padding: 20, background: Brand.wash) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 9) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Brand.greenDk)
                    Text("Up to 24 months, backdated")
                        .font(BrandFont.heading(17))
                        .foregroundStyle(Brand.ink)
                }
                Text("You have paid these bills for years and none of it counted. When you add one, we push the history we can verify onto your report — so the work you already did starts showing up where lenders look.")
                    .font(BrandFont.body(14))
                    .foregroundStyle(Brand.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Bill row

struct BillRow: View {
    let bill: BillAccount
    let onChange: (BillAccount.State) -> Void

    private var tone: Color {
        switch bill.state {
        case .reporting: return Brand.greenDk
        case .pending:   return Brand.orange
        case .off:       return Brand.faint
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: bill.kind.symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(bill.state == .reporting ? Brand.greenDk : Brand.dim)
                .frame(width: 44, height: 44)
                .background(bill.state == .reporting ? Brand.wash : Brand.s3, in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(bill.kind.label)
                        .font(BrandFont.heading(16))
                        .foregroundStyle(Brand.ink)
                    Text(bill.monthlyAmount.formatted(.currency(code: "USD").precision(.fractionLength(0))))
                        .font(BrandFont.number(14))
                        .foregroundStyle(Brand.dim)
                }
                Text(bill.provider)
                    .font(BrandFont.body(13))
                    .foregroundStyle(Brand.faint)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 5) {
                Text(bill.state.label)
                    .font(BrandFont.body(12.5, weight: .bold))
                    .foregroundStyle(tone)
                if bill.state == .reporting && bill.backdatedMonths > 0 {
                    Text("\(bill.backdatedMonths) mo back")
                        .font(BrandFont.body(11.5))
                        .foregroundStyle(Brand.faint)
                } else if bill.state == .off {
                    Button("Turn on") { onChange(.pending) }
                        .font(BrandFont.body(12.5, weight: .bold))
                        .foregroundStyle(Brand.greenDk)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.s2, in: RoundedRectangle(cornerRadius: Metrics.radiusTile, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Metrics.radiusTile, style: .continuous).stroke(Brand.line, lineWidth: 1))
    }
}

// MARK: - Add a bill

struct AddBillView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var kind: BillAccount.Kind = .rent
    @State private var provider = ""
    @State private var amount = ""

    private var amountValue: Decimal? {
        Decimal(string: amount.filter { $0.isNumber || $0 == "." })
    }

    private var isValid: Bool {
        !provider.trimmingCharacters(in: .whitespaces).isEmpty && (amountValue ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.s1.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Add a bill you already pay and we'll start reporting it — plus whatever history we can verify, up to 24 months.")
                            .font(BrandFont.body(15))
                            .foregroundStyle(Brand.dim)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Type")
                                .font(BrandFont.heading(14, weight: .semibold))
                                .foregroundStyle(Brand.ink)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                                ForEach(BillAccount.Kind.allCases) { option in
                                    Button {
                                        kind = option
                                    } label: {
                                        HStack(spacing: 7) {
                                            Image(systemName: option.symbol)
                                            Text(option.label)
                                        }
                                        .font(BrandFont.body(14, weight: .semibold))
                                        .foregroundStyle(kind == option ? .white : Brand.dim)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 11)
                                        .background(kind == option ? Brand.green : Brand.s2, in: Capsule())
                                        .overlay(Capsule().stroke(kind == option ? Color.clear : Brand.line2, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        BrandField(placeholder: "Provider or landlord", text: $provider, autocapitalization: .words)
                        BrandField(placeholder: "Monthly amount", text: $amount, keyboard: .decimalPad)

                        Button("Start reporting it") {
                            state.addBill(
                                BillAccount(
                                    kind: kind,
                                    provider: provider.trimmingCharacters(in: .whitespaces),
                                    monthlyAmount: amountValue ?? 0,
                                    state: .pending,
                                    backdatedMonths: 0
                                )
                            )
                            dismiss()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!isValid)
                        .opacity(isValid ? 1 : 0.5)

                        Text("We verify the account before anything reaches your report. Verification usually takes a few days.")
                            .font(BrandFont.body(12.5))
                            .foregroundStyle(Brand.faint)
                    }
                    .padding(Metrics.gutter)
                }
            }
            .navigationTitle("Add a bill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }.tint(Brand.dim)
                }
            }
        }
    }
}

// MARK: - Tier picker

/// The three partner tiers from the web checkout.
struct TierPickerView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selected: BuilderTier = .basic

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.s1.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Pick the reported line that fits your budget. A bigger tradeline builds a thicker file — but on-time payments matter more than size, so start where you can comfortably stay current.")
                            .font(BrandFont.body(15))
                            .foregroundStyle(Brand.dim)
                            .fixedSize(horizontal: false, vertical: true)

                        ForEach(BuilderTier.allCases) { tier in
                            Button {
                                selected = tier
                            } label: {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle().stroke(selected == tier ? Brand.green : Brand.line2, lineWidth: 1.6)
                                        if selected == tier {
                                            Circle().fill(Brand.green).frame(width: 12, height: 12)
                                        }
                                    }
                                    .frame(width: 22, height: 22)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(tier.displayName)
                                            .font(BrandFont.heading(17))
                                            .foregroundStyle(Brand.ink)
                                        Text("\(tier.tradeline.formatted(.currency(code: "USD").precision(.fractionLength(0)))) reported tradeline")
                                            .font(BrandFont.body(13.5))
                                            .foregroundStyle(Brand.dim)
                                    }

                                    Spacer()

                                    Text("\(tier.monthlyFee.formatted(.currency(code: "USD").precision(.fractionLength(0))))/mo")
                                        .font(BrandFont.number(16))
                                        .foregroundStyle(Brand.greenDk)
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Brand.s2, in: RoundedRectangle(cornerRadius: Metrics.radiusTile, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Metrics.radiusTile, style: .continuous)
                                        .stroke(selected == tier ? Brand.green : Brand.line, lineWidth: selected == tier ? 1.6 : 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        Button(state.builder.isOpen ? "Switch to \(selected.displayName)" : "Open my \(selected.displayName) account") {
                            if state.builder.isOpen {
                                state.upgradeBuilder(to: selected)
                            } else {
                                state.openBuilderAccount(tier: selected)
                            }
                            dismiss()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.top, 4)

                        Text("The partner fee is billed alongside your Launch subscription. No hard inquiry, and you can change tier any time.")
                            .font(BrandFont.body(12.5))
                            .foregroundStyle(Brand.faint)
                    }
                    .padding(Metrics.gutter)
                }
            }
            .navigationTitle("Builder account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }.tint(Brand.dim)
                }
            }
            .onAppear { selected = state.builder.tier }
        }
    }
}

#Preview {
    BuildView().environmentObject(AppState())
}
