import SwiftUI

/// One plan, everything in it — plus the disclosures, kept in the same words
/// the site uses. Reached from the avatar on Home, not from a tab.
struct AccountView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var showingDisclosures = false
    @State private var confirmingSignOut = false

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.s1.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        identity
                        planCard
                        disclosures
                        Button("Sign out") { confirmingSignOut = true }
                            .buttonStyle(LineButtonStyle())
                    }
                    .padding(Metrics.gutter)
                }
            }
            .navigationTitle("Your account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(BrandFont.body(16, weight: .semibold))
                        .tint(Brand.greenDk)
                }
            }
            .confirmationDialog("Sign out of Launch?", isPresented: $confirmingSignOut, titleVisibility: .visible) {
                Button("Sign out", role: .destructive) {
                    dismiss()
                    state.signOut()
                }
                Button("Cancel", role: .cancel) { }
            }
        }
    }

    // MARK: - Identity

    private var identity: some View {
        HStack(spacing: 14) {
            Text(state.user?.initials ?? "L")
                .font(BrandFont.heading(20))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(Brand.grad, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(state.user?.fullName ?? "Member")
                    .font(BrandFont.heading(19))
                    .tracking(-0.4)
                    .foregroundStyle(Brand.ink)
                Text(state.user?.email ?? "")
                    .font(BrandFont.body(13.5))
                    .foregroundStyle(Brand.dim)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Plan

    private var planCard: some View {
        Card(padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("YOUR PLAN")
                            .font(BrandFont.heading(10.5, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(Brand.faint)
                        Text(state.subscription.planName)
                            .font(BrandFont.heading(22))
                            .tracking(-0.5)
                            .foregroundStyle(Brand.ink)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(state.subscription.monthlyPrice.formatted(.currency(code: "USD")))
                            .font(BrandFont.number(23))
                            .foregroundStyle(Brand.ink)
                        Text("/ month")
                            .font(BrandFont.body(12.5))
                            .foregroundStyle(Brand.faint)
                    }
                }

                VStack(spacing: 0) {
                    StatRow(label: "Launch subscription", value: state.subscription.monthlyPrice.formatted(.currency(code: "USD")))
                    StatRow(label: "Builder account (partner)", value: state.subscription.builderFee.formatted(.currency(code: "USD")))
                    StatRow(label: "Total monthly", value: state.subscription.totalMonthly.formatted(.currency(code: "USD")))
                    StatRow(
                        label: "Next charge",
                        value: state.subscription.renewsOn.formatted(.dateTime.month(.abbreviated).day()),
                        showsDivider: false
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(PlanBenefits.all, id: \.self) { benefit in
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(Brand.greenDk)
                                .frame(width: 18, height: 18)
                                .background(Brand.wash, in: Circle())
                            Text(benefit)
                                .font(BrandFont.body(14))
                                .foregroundStyle(Brand.dim)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, 2)

                Text("Cancel any time. No contract, no cancellation fee, no setup fee.")
                    .font(BrandFont.body(12.5))
                    .foregroundStyle(Brand.faint)
            }
        }
    }

    // MARK: - Disclosures

    /// The site keeps these behind one "Important disclosures" toggle in the
    /// footer. Same idea here — present, never in the way.
    private var disclosures: some View {
        Card(padding: 18, background: Brand.s2) {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        showingDisclosures.toggle()
                    }
                } label: {
                    HStack {
                        Text("Important disclosures")
                            .font(BrandFont.heading(15))
                            .foregroundStyle(Brand.ink)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Brand.faint)
                            .rotationEffect(.degrees(showingDisclosures ? 180 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if showingDisclosures {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(PlanDisclosure.all) { item in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                    .font(BrandFont.body(13.5, weight: .bold))
                                    .foregroundStyle(Brand.ink)
                                Text(item.body)
                                    .font(BrandFont.body(13))
                                    .foregroundStyle(Brand.dim)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    Text("Launch is a credit-building service — not credit repair. Individual results vary.")
                        .font(BrandFont.body(13))
                        .foregroundStyle(Brand.faint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// Kept in sync with the disclosures in the site footer.
struct PlanDisclosure: Identifiable {
    var id: String { title }
    let title: String
    let body: String

    static let all: [PlanDisclosure] = [
        .init(
            title: "Not credit repair",
            body: "Launch is a credit-building service. We do not file disputes on your behalf and we cannot remove accurate information from your report."
        ),
        .init(
            title: "Soft inquiries only",
            body: "Reading your report through Launch is a soft inquiry and never lowers your score. A hard inquiry happens only when you apply for credit yourself."
        ),
        .init(
            title: "Builder account",
            body: "The credit builder account is opened and serviced by our lending partner, subject to their approval and terms. The partner fee is billed alongside your Launch subscription."
        ),
        .init(
            title: "Bill reporting",
            body: "Rent and bill reporting depends on our ability to verify the account and on each bureau accepting the data. Backdating covers up to 24 months of verifiable history."
        ),
        .init(
            title: "Results vary",
            body: "Score estimates in this app are directional, based on how scoring models weigh each factor. They are not a guarantee, and late payments can lower your score."
        )
    ]
}

#Preview {
    AccountView().environmentObject(AppState())
}
