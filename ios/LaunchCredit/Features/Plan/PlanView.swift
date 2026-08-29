import SwiftUI

/// "Ranked by what it costs you." — the diagnosis, hardest-hitting first, with
/// the one move that fixes each.
struct PlanView: View {
    @EnvironmentObject private var state: AppState
    @State private var expanded: Set<UUID> = []

    private var openFixes: [FixItem] {
        state.fixes.filter { $0.status != .done }.sorted { $0.pointCost > $1.pointCost }
    }

    private var doneFixes: [FixItem] {
        state.fixes.filter { $0.status == .done }
    }

    private var totalCost: Int {
        openFixes.reduce(0) { $0 + $1.pointCost }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: Metrics.sectionGap) {
                        SectionHeader(
                            eyebrow: "Your fix list",
                            plain: "Ranked by what it",
                            italic: "costs you.",
                            sub: "Not a wall of numbers. A short list, hardest-hitting first, with the exact move that fixes each one."
                        )
                        .padding(.top, 14)

                        summaryCard
                        progressTrack

                        if !openFixes.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Still costing you")
                                    .font(BrandFont.heading(17))
                                    .foregroundStyle(Brand.ink)

                                ForEach(openFixes) { fix in
                                    FixCard(
                                        fix: fix,
                                        isExpanded: expanded.contains(fix.id),
                                        onToggle: { toggle(fix) },
                                        onDone: { state.setFixStatus(fix, to: .done) },
                                        onStart: { state.setFixStatus(fix, to: .inProgress) }
                                    )
                                }
                            }
                        }

                        if !doneFixes.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Handled")
                                    .font(BrandFont.heading(17))
                                    .foregroundStyle(Brand.ink)

                                ForEach(doneFixes) { fix in
                                    DoneFixRow(fix: fix) {
                                        state.setFixStatus(fix, to: .todo)
                                    }
                                }
                            }
                        }

                        Text("Point estimates are directional, based on how scoring models weigh each factor. They are not a guarantee.")
                            .font(BrandFont.body(12))
                            .foregroundStyle(Brand.faint)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, Metrics.gutter)
                    .padding(.bottom, 30)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var summaryCard: some View {
        Card(padding: 20) {
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("COSTING YOU")
                        .font(BrandFont.heading(10.5, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(Brand.faint)
                    Text("−\(totalCost) pts")
                        .font(BrandFont.number(30))
                        .tracking(-1)
                        .foregroundStyle(Brand.orange)
                    Text("across \(openFixes.count) open \(openFixes.count == 1 ? "issue" : "issues")")
                        .font(BrandFont.body(13))
                        .foregroundStyle(Brand.dim)
                }

                Rectangle().fill(Brand.line).frame(width: 1, height: 62)

                VStack(alignment: .leading, spacing: 5) {
                    Text("IF YOU FIX IT ALL")
                        .font(BrandFont.heading(10.5, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(Brand.faint)
                    Text("\(min(850, state.profile.score + totalCost))")
                        .font(BrandFont.number(30))
                        .tracking(-1)
                        .foregroundStyle(Brand.greenDk)
                    Text("from \(state.profile.score) today")
                        .font(BrandFont.body(13))
                        .foregroundStyle(Brand.dim)
                }
            }
        }
    }

    private var progressTrack: some View {
        let total = max(state.fixes.count, 1)
        let done = doneFixes.count
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(done) of \(total) handled")
                    .font(BrandFont.body(13.5, weight: .semibold))
                    .foregroundStyle(Brand.dim)
                Spacer()
                Text("\(Int(Double(done) / Double(total) * 100))%")
                    .font(BrandFont.number(13.5))
                    .foregroundStyle(Brand.greenDk)
            }
            ProgressTrack(value: Double(done) / Double(total))
        }
    }

    private func toggle(_ fix: FixItem) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            if expanded.contains(fix.id) { expanded.remove(fix.id) } else { expanded.insert(fix.id) }
        }
    }
}

// MARK: - Fix card

struct FixCard: View {
    let fix: FixItem
    let isExpanded: Bool
    let onToggle: () -> Void
    let onDone: () -> Void
    let onStart: () -> Void

    var body: some View {
        Card(padding: 18) {
            VStack(alignment: .leading, spacing: 13) {
                Button(action: onToggle) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 7) {
                            if fix.isBiggestWin {
                                Chip(text: "Biggest win", tone: .wash)
                            }
                            Text(fix.title)
                                .font(BrandFont.heading(17))
                                .tracking(-0.3)
                                .foregroundStyle(Brand.ink)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: 8) {
                                Chip(text: "−\(fix.pointCost) pts", tone: .cost)
                                Text("≈ \(fix.dollarCost.formatted(.currency(code: "USD").precision(.fractionLength(0))))/yr in interest")
                                    .font(BrandFont.body(12.5, weight: .medium))
                                    .foregroundStyle(Brand.faint)
                            }
                        }

                        Spacer(minLength: 6)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Brand.faint)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(alignment: .leading, spacing: 13) {
                        Text(fix.detail)
                            .font(BrandFont.body(14.5))
                            .foregroundStyle(Brand.dim)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("THE MOVE")
                                .font(BrandFont.heading(10.5, weight: .bold))
                                .tracking(1.5)
                                .foregroundStyle(Brand.greenDk)
                            Text(fix.move)
                                .font(BrandFont.body(14.5, weight: .semibold))
                                .foregroundStyle(Brand.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Brand.wash, in: RoundedRectangle(cornerRadius: Metrics.radiusTile, style: .continuous))

                        HStack(spacing: 10) {
                            Button("Mark done", action: onDone)
                                .buttonStyle(PrimaryButtonStyle(fullWidth: false))
                            if fix.status == .todo {
                                Button("Start it", action: onStart)
                                    .buttonStyle(LineButtonStyle(fullWidth: false))
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                } else if fix.status == .inProgress {
                    HStack(spacing: 7) {
                        Circle().fill(Brand.greenBr).frame(width: 6, height: 6)
                        Text("In progress")
                            .font(BrandFont.body(12.5, weight: .semibold))
                            .foregroundStyle(Brand.greenDk)
                    }
                }
            }
        }
    }
}

struct DoneFixRow: View {
    let fix: FixItem
    let onReopen: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 19))
                .foregroundStyle(Brand.greenBr)
            Text(fix.title)
                .font(BrandFont.body(14.5, weight: .medium))
                .foregroundStyle(Brand.dim)
                .strikethrough(color: Brand.faint)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button("Undo", action: onReopen)
                .font(BrandFont.body(13, weight: .semibold))
                .foregroundStyle(Brand.faint)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.s1, in: RoundedRectangle(cornerRadius: Metrics.radiusTile, style: .continuous))
    }
}

#Preview {
    PlanView().environmentObject(AppState())
}
