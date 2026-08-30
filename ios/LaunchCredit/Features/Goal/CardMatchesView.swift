import SwiftUI

/// Cards matched to this file, with the reason each was picked. Never a shelf —
/// if the honest answer is "not yet", that is what the screen says.
struct CardMatchesView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.s1.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Card(padding: 16, background: Brand.wash) {
                            HStack(alignment: .top, spacing: 11) {
                                Image(systemName: "hand.raised.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Brand.greenDk)
                                Text(CardAdvisor.readinessNote(for: state.coachContext))
                                    .font(BrandFont.body(13.5, weight: .medium))
                                    .foregroundStyle(Brand.dim)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        ForEach(state.cardMatches) { match in
                            MatchCard(match: match)
                        }

                        Text("Matched on your score, your file's thickness and what you're carrying — not on what pays us most. Where we earn a commission, the card says so.")
                            .font(BrandFont.body(12))
                            .foregroundStyle(Brand.faint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(Metrics.gutter)
                }
            }
            .navigationTitle("Card matches")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(BrandFont.body(16, weight: .semibold))
                        .tint(Brand.greenDk)
                }
            }
        }
    }
}

struct MatchCard: View {
    let match: CardRecommendation

    var body: some View {
        Card(padding: 18) {
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    Text(match.kind.label.uppercased())
                        .font(BrandFont.heading(10.5, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(Brand.faint)
                    Spacer()
                    Chip(text: match.highlight, tone: .good)
                }

                Text(match.name)
                    .font(BrandFont.heading(18))
                    .tracking(-0.3)
                    .foregroundStyle(Brand.ink)

                Text(match.why)
                    .font(BrandFont.body(14))
                    .foregroundStyle(Brand.dim)
                    .fixedSize(horizontal: false, vertical: true)

                if match.paysCommission {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Launch earns a commission if you're approved.")
                            .font(BrandFont.body(11.5, weight: .medium))
                    }
                    .foregroundStyle(Brand.faint)
                }
            }
        }
    }
}

#Preview {
    CardMatchesView().environmentObject(AppState())
}
