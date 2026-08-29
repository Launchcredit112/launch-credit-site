import SwiftUI

/// Account, plan and the disclosures. One plan, everything in it.
struct ProfileView: View {
    @EnvironmentObject private var state: AppState

    @State private var showingSignOut = false
    @State private var showingDelete = false
    @State private var showingDisclosures = false
    @State private var notificationsOn = true

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: Metrics.sectionGap) {
                        identityCard
                        planCard
                        settingsCard
                        legalCard
                        signOutButtons
                    }
                    .padding(.horizontal, Metrics.gutter)
                    .padding(.top, 14)
                    .padding(.bottom, 30)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingDisclosures) { DisclosuresView() }
            .confirmationDialog("Sign out of Launch?", isPresented: $showingSignOut, titleVisibility: .visible) {
                Button("Sign out", role: .destructive) { state.signOut() }
                Button("Cancel", role: .cancel) { }
            }
            .confirmationDialog(
                "Delete your account?",
                isPresented: $showingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete everything", role: .destructive) { state.deleteAccount() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This erases your account and all member data stored on this device. It cannot be undone.")
            }
        }
    }

    // MARK: - Identity

    private var identityCard: some View {
        Card(padding: 20) {
            HStack(spacing: 15) {
                Text(state.user?.initials ?? "L")
                    .font(BrandFont.heading(22))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(Brand.grad, in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(state.user?.fullName ?? "Member")
                        .font(BrandFont.heading(20))
                        .tracking(-0.4)
                        .foregroundStyle(Brand.ink)
                    Text(state.user?.email ?? "")
                        .font(BrandFont.body(13.5))
                        .foregroundStyle(Brand.dim)
                        .lineLimit(1)
                    if let joined = state.user?.joinedAt {
                        Text("Member since \(joined.formatted(.dateTime.month(.wide).year()))")
                            .font(BrandFont.body(12.5))
                            .foregroundStyle(Brand.faint)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Plan

    private var planCard: some View {
        Card(padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
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
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(state.subscription.monthlyPrice.formatted(.currency(code: "USD")))
                            .font(BrandFont.number(24))
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
                    StatRow(label: "Next charge", value: state.subscription.renewsOn.formatted(.dateTime.month(.abbreviated).day()), showsDivider: false)
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(PlanBenefits.all, id: \.self) { benefit in
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .heavy))
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
                .padding(.top, 4)

                Text("Cancel any time. No contract, no cancellation fee, no setup fee.")
                    .font(BrandFont.body(12.5))
                    .foregroundStyle(Brand.faint)
            }
        }
    }

    // MARK: - Settings

    private var settingsCard: some View {
        Card(padding: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Toggle(isOn: $notificationsOn) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Score and payment alerts")
                            .font(BrandFont.body(15, weight: .semibold))
                            .foregroundStyle(Brand.ink)
                        Text("We'll tell you the one move to make, and never spam you.")
                            .font(BrandFont.body(12.5))
                            .foregroundStyle(Brand.faint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(Brand.green)
                .padding(.vertical, 6)

                Rectangle().fill(Brand.line).frame(height: 1)

                SettingsRow(icon: "creditcard", title: "Payment method") { }
                SettingsRow(icon: "questionmark.circle", title: "Help and support") { }
                SettingsRow(icon: "doc.text", title: "Disclosures and legal", showsDivider: false) {
                    showingDisclosures = true
                }
            }
        }
    }

    // MARK: - Legal

    private var legalCard: some View {
        Card(padding: 18, background: Brand.s1) {
            Text("Launch is a credit-building service — not credit repair. We don't file disputes on your behalf, and no one can lawfully remove accurate information from your report. Individual results vary; late payments can lower your score.")
                .font(BrandFont.body(12.5))
                .foregroundStyle(Brand.faint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Sign out

    private var signOutButtons: some View {
        VStack(spacing: 12) {
            Button("Sign out") { showingSignOut = true }
                .buttonStyle(LineButtonStyle())

            Button("Delete account") { showingDelete = true }
                .font(BrandFont.body(14, weight: .semibold))
                .foregroundStyle(Brand.red)
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    var showsDivider: Bool = true
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Brand.dim)
                        .frame(width: 24)
                    Text(title)
                        .font(BrandFont.body(15, weight: .medium))
                        .foregroundStyle(Brand.ink)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Brand.faint)
                }
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showsDivider {
                Rectangle().fill(Brand.line).frame(height: 1)
            }
        }
    }
}

// MARK: - Disclosures

struct DisclosuresView: View {
    @Environment(\.dismiss) private var dismiss

    private let sections: [(String, String)] = [
        ("Not credit repair", "Launch is a credit-building service. We do not file disputes on your behalf and we cannot remove accurate information from your report. Anyone who promises that is not telling you the truth."),
        ("Soft inquiries only", "Reading your report through Launch is a soft inquiry and never lowers your score. A hard inquiry happens only when you apply for credit yourself."),
        ("Builder account", "The credit builder account is opened and serviced by our lending partner, subject to their approval and terms. The partner fee is billed alongside your Launch subscription."),
        ("Bill reporting", "Rent and bill reporting depends on our ability to verify the account and on each bureau accepting the data. Backdating covers up to 24 months of verifiable history."),
        ("Results vary", "Score estimates in this app are directional, based on how scoring models weigh each factor. They are not a guarantee, and late payments can lower your score."),
        ("Billing", "Launch is $39.99 per month, billed after each month of service. Cancel any time — there is no contract, no cancellation fee and no setup fee.")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(sections, id: \.0) { section in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(section.0)
                                .font(BrandFont.heading(17))
                                .foregroundStyle(Brand.ink)
                            Text(section.1)
                                .font(BrandFont.body(14.5))
                                .foregroundStyle(Brand.dim)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(Metrics.gutter)
            }
            .background(Brand.s1)
            .navigationTitle("Disclosures")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.tint(Brand.greenDk)
                }
            }
        }
    }
}

#Preview {
    ProfileView().environmentObject(AppState())
}
