import SwiftUI

/// "Offers picked for you." Products surface only when the file is ready — and
/// we say plainly when Launch earns a commission.
struct MarketplaceView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

    private var ready: [Offer] {
        state.offers.filter { state.profile.score >= $0.unlocksAtScore }
    }

    private var locked: [Offer] {
        state.offers.filter { state.profile.score < $0.unlocksAtScore }
            .sorted { $0.unlocksAtScore < $1.unlocksAtScore }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.s1.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Card(padding: 18, background: Brand.wash) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "hand.raised.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Brand.greenDk)
                                Text("We only surface products that match where your file actually is. Applying before you're ready means a denial and a hard inquiry you keep for two years.")
                                    .font(BrandFont.body(13.5, weight: .medium))
                                    .foregroundStyle(Brand.dim)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        if !ready.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Ready for you")
                                    .font(BrandFont.heading(18))
                                    .foregroundStyle(Brand.ink)
                                ForEach(ready) { offer in
                                    OfferCard(offer: offer, isLocked: false, currentScore: state.profile.score)
                                }
                            }
                        }

                        if !locked.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Not yet")
                                    .font(BrandFont.heading(18))
                                    .foregroundStyle(Brand.ink)
                                ForEach(locked) { offer in
                                    OfferCard(offer: offer, isLocked: true, currentScore: state.profile.score)
                                }
                            }
                        }

                        Text("Launch earns a commission on some of these, and each card says so. It never changes the order they appear in.")
                            .font(BrandFont.body(12))
                            .foregroundStyle(Brand.faint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(Metrics.gutter)
                }
            }
            .navigationTitle("Marketplace")
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

struct OfferCard: View {
    let offer: Offer
    let isLocked: Bool
    let currentScore: Int

    var body: some View {
        Card(padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(offer.category.uppercased())
                        .font(BrandFont.heading(10.5, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(Brand.faint)
                    Spacer()
                    Chip(
                        text: isLocked ? "Needs \(offer.unlocksAtScore)" : offer.highlight,
                        tone: isLocked ? .neutral : .good
                    )
                }

                Text(offer.name)
                    .font(BrandFont.heading(18))
                    .tracking(-0.3)
                    .foregroundStyle(Brand.ink)

                Text(offer.detail)
                    .font(BrandFont.body(14))
                    .foregroundStyle(Brand.dim)
                    .fixedSize(horizontal: false, vertical: true)

                if isLocked {
                    VStack(alignment: .leading, spacing: 7) {
                        ProgressTrack(value: Double(currentScore) / Double(offer.unlocksAtScore), height: 6)
                        Text("\(max(0, offer.unlocksAtScore - currentScore)) points to go. Keep the streak running and I'll unlock it.")
                            .font(BrandFont.body(12.5))
                            .foregroundStyle(Brand.faint)
                    }
                } else {
                    Button("See the offer") { }
                        .buttonStyle(LineButtonStyle())
                }

                if offer.paysCommission {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Launch earns a commission if you're approved.")
                            .font(BrandFont.body(11.5, weight: .medium))
                    }
                    .foregroundStyle(Brand.faint)
                }
            }
            .opacity(isLocked ? 0.72 : 1)
        }
    }
}

#Preview {
    MarketplaceView().environmentObject(AppState())
}
