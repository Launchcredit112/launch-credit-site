import SwiftUI
import UIKit

/// The hero score readout: a 300–850 arc with the band underneath, animating up
/// on first appearance the way the site's counter does.
struct ScoreDial: View {
    let score: Int
    let change: Int
    var size: CGFloat = 210

    @State private var animatedFraction: Double = 0
    @State private var displayedScore: Int = 300

    private var fraction: Double {
        Double(max(300, min(850, score)) - 300) / 550.0
    }

    var body: some View {
        ZStack {
            // Track
            ArcShape(fraction: 1)
                .stroke(Brand.s3, style: StrokeStyle(lineWidth: 16, lineCap: .round))

            // Progress
            ArcShape(fraction: animatedFraction)
                .stroke(Brand.grad, style: StrokeStyle(lineWidth: 16, lineCap: .round))

            VStack(spacing: 2) {
                Text("\(displayedScore)")
                    .font(BrandFont.number(58))
                    .tracking(-2)
                    .foregroundStyle(Brand.ink)
                    .contentTransition(.numericText())

                Text(creditBand(for: score))
                    .font(BrandFont.heading(15, weight: .semibold))
                    .foregroundStyle(Brand.scoreColor(for: score))

                HStack(spacing: 4) {
                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 11, weight: .bold))
                    Text("\(abs(change)) points")
                        .font(BrandFont.body(13, weight: .semibold))
                        .monospacedDigit()
                }
                .foregroundStyle(change >= 0 ? Brand.greenDk : Brand.red)
                .padding(.top, 6)
            }
            .offset(y: 6)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Credit score \(score), \(creditBand(for: score)), \(change >= 0 ? "up" : "down") \(abs(change)) points since you started")
        .onAppear(perform: animate)
        .onChange(of: score) { _, _ in animate() }
    }

    private func animate() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            animatedFraction = fraction
            displayedScore = score
            return
        }
        animatedFraction = 0
        displayedScore = max(300, score - 60)
        withAnimation(.easeOut(duration: 1.1)) { animatedFraction = fraction }
        withAnimation(.easeOut(duration: 1.1)) { displayedScore = score }
    }
}

/// A 270° arc opening at the bottom, drawn clockwise from the lower left.
private struct ArcShape: Shape {
    var fraction: Double

    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let start = Angle.degrees(135)
        let sweep = Angle.degrees(270 * max(0, min(1, fraction)))
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: min(rect.width, rect.height) / 2 - 8,
            startAngle: start,
            endAngle: start + sweep,
            clockwise: false
        )
        return path
    }
}

// MARK: - Trend

/// The 12-month score line from the site's bento card, as a filled sparkline.
struct ScoreTrendChart: View {
    let points: [ScorePoint]
    var height: CGFloat = 92

    @State private var progress: CGFloat = 0

    private var scores: [Int] { points.map(\.score) }

    var body: some View {
        GeometryReader { geo in
            let path = linePath(in: geo.size)
            ZStack(alignment: .bottomLeading) {
                path
                    .strokedPath(StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                    .fill(Brand.grad)
                    .mask(
                        Rectangle()
                            .frame(width: geo.size.width * progress, alignment: .leading)
                            .frame(width: geo.size.width, alignment: .leading)
                    )

                filledPath(in: geo.size)
                    .fill(
                        LinearGradient(
                            colors: [Brand.greenLt.opacity(0.22), Brand.greenLt.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(progress)
            }
        }
        .frame(height: height)
        .accessibilityLabel("Score trend over the last \(points.count) months")
        .onAppear {
            guard !UIAccessibility.isReduceMotionEnabled else { progress = 1; return }
            withAnimation(.easeOut(duration: 1.2).delay(0.15)) { progress = 1 }
        }
    }

    private func positions(in size: CGSize) -> [CGPoint] {
        guard scores.count > 1,
              let low = scores.min(),
              let high = scores.max()
        else { return [] }
        // A flat run should sit mid-height rather than divide by zero.
        let span = max(1, high - low)
        return scores.enumerated().map { index, score in
            let x = size.width * CGFloat(index) / CGFloat(scores.count - 1)
            let normalized = CGFloat(score - low) / CGFloat(span)
            let y = size.height - normalized * (size.height - 8) - 4
            return CGPoint(x: x, y: y)
        }
    }

    private func linePath(in size: CGSize) -> Path {
        let pts = positions(in: size)
        var path = Path()
        guard let first = pts.first else { return path }
        path.move(to: first)
        for point in pts.dropFirst() { path.addLine(to: point) }
        return path
    }

    private func filledPath(in size: CGSize) -> Path {
        let pts = positions(in: size)
        var path = Path()
        guard let first = pts.first, let last = pts.last else { return path }
        path.move(to: CGPoint(x: first.x, y: size.height))
        path.addLine(to: first)
        for point in pts.dropFirst() { path.addLine(to: point) }
        path.addLine(to: CGPoint(x: last.x, y: size.height))
        path.closeSubpath()
        return path
    }
}

#Preview {
    VStack(spacing: 30) {
        ScoreDial(score: 648, change: 36)
        ScoreTrendChart(points: CreditProfile.seed.history).padding(.horizontal, 20)
    }
}
