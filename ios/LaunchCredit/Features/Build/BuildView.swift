import SwiftUI

/// "Rent, phone, power, internet. Add them in the app and they start landing on
/// your report." Switching one on is the whole interaction — no forms.
struct BuildView: View {
    @EnvironmentObject private var state: AppState

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
        }
    }

    // MARK: - Builder account

    private var builderCard: some View {
        Card(padding: 20) {
            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("BUILDER ACCOUNT")
                            .font(BrandFont.heading(10.5, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(Brand.faint)
                        Text(state.builder.isOpen ? state.builder.tier.displayName : "Opening")
                            .font(BrandFont.heading(21))
                            .tracking(-0.5)
                            .foregroundStyle(Brand.ink)
                    }
                    Spacer()
                    if state.builder.isOpen { LiveBadge(text: "Reporting") }
                }

                VStack(spacing: 0) {
                    StatRow(
                        label: "Reported tradeline",
                        value: state.builder.tier.tradeline.formatted(.currency(code: "USD").precision(.fractionLength(0)))
                    )
                    StatRow(label: "On-time payments") {
                        Chip(text: "\(state.builder.onTimePayments) months", tone: .good)
                    }
                    StatRow(label: "Hard inquiry") {
                        Chip(text: "None", tone: .good)
                    }
                    StatRow(
                        label: "Next payment",
                        value: state.builder.nextPaymentDate.formatted(.dateTime.month(.abbreviated).day()),
                        showsDivider: false
                    )
                }
            }
        }
    }

    // MARK: - Bills

    private var billsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your bills")
                .font(BrandFont.heading(19))
                .foregroundStyle(Brand.ink)

            ForEach(state.bills) { bill in
                BillRow(bill: bill) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        state.toggleBill(bill)
                    }
                }
            }
        }
    }

    // MARK: - Backdating

    private var backdateCard: some View {
        Card(padding: 20, background: Brand.wash) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 9) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Brand.greenDk)
                    Text("Up to 24 months, backdated")
                        .font(BrandFont.heading(16))
                        .foregroundStyle(Brand.ink)
                }
                Text("You have paid these bills for years and none of it counted. Switch one on and we push the history we can verify onto your report — so the work you already did starts showing up where lenders look.")
                    .font(BrandFont.body(14))
                    .foregroundStyle(Brand.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Bill row

/// One tap switches the bill on. Verification is ours to do, not the member's
/// to fill in, so the row only ever reports what is happening.
struct BillRow: View {
    let bill: BillAccount
    let onToggle: () -> Void

    private var isOn: Bool { bill.state != .off }

    private var statusColor: Color {
        switch bill.state {
        case .reporting: return Brand.greenDk
        case .pending:   return Brand.orange
        case .off:       return Brand.faint
        }
    }

    private var statusText: String {
        switch bill.state {
        case .reporting: return bill.backdatedMonths > 0 ? "Reporting · \(bill.backdatedMonths) mo backdated" : "Reporting"
        case .pending:   return "Verifying — usually a few days"
        case .off:       return "Not reporting yet"
        }
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 14) {
                Image(systemName: bill.kind.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isOn ? Brand.greenDk : Brand.dim)
                    .frame(width: 42, height: 42)
                    .background(isOn ? Brand.wash : Brand.s3, in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(bill.kind.label)
                            .font(BrandFont.heading(16))
                            .foregroundStyle(Brand.ink)
                        Text(bill.monthlyAmount.formatted(.currency(code: "USD").precision(.fractionLength(0))))
                            .font(BrandFont.number(13.5))
                            .foregroundStyle(Brand.dim)
                    }
                    Text(statusText)
                        .font(BrandFont.body(12.5, weight: .medium))
                        .foregroundStyle(statusColor)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                // A switch, drawn rather than a Toggle, so the whole row is the target.
                Capsule()
                    .fill(isOn ? AnyShapeStyle(Brand.grad) : AnyShapeStyle(Brand.s3))
                    .frame(width: 46, height: 28)
                    .overlay(alignment: isOn ? .trailing : .leading) {
                        Circle()
                            .fill(.white)
                            .padding(2)
                            .shadow(color: Color(hex: 0x0B0D10, alpha: 0.22), radius: 2, x: 0, y: 1)
                    }
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Brand.s2, in: RoundedRectangle(cornerRadius: Metrics.radiusTile, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Metrics.radiusTile, style: .continuous).stroke(Brand.line, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(bill.kind.label), \(bill.provider)")
        .accessibilityValue(statusText)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}

#Preview {
    BuildView().environmentObject(AppState())
}
