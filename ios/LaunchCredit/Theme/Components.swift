import SwiftUI
import UIKit

// MARK: - Eyebrow

/// `.eyebrow` — the small uppercase kicker above every section heading.
struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(BrandFont.eyebrow)
            .tracking(2.6)
            .foregroundStyle(Brand.faint)
    }
}

// MARK: - Headline

/// Renders the site's two-tone headline: an Outfit run followed by an
/// Instrument Serif italic run, e.g. "One plan. *Everything in it.*"
struct Headline: View {
    let plain: String
    var italic: String? = nil
    var size: CGFloat = 30

    var body: some View {
        Group {
            if let italic {
                Text(plain + " ")
                    .font(BrandFont.heading(size))
                + Text(italic)
                    .font(BrandFont.serifItalic(size * 1.02))
            } else {
                Text(plain).font(BrandFont.heading(size))
            }
        }
        .foregroundStyle(Brand.ink)
        .tracking(-0.9)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct SectionHeader: View {
    let eyebrow: String
    let plain: String
    var italic: String? = nil
    var sub: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: eyebrow)
            Headline(plain: plain, italic: italic, size: 28)
            if let sub {
                Text(sub)
                    .font(BrandFont.body(15))
                    .foregroundStyle(Brand.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Buttons

/// `.btn.btn-green` — gradient pill, the primary action everywhere on the site.
struct PrimaryButtonStyle: ButtonStyle {
    var fullWidth: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BrandFont.heading(16, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 16)
            .padding(.horizontal, 26)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(Brand.grad, in: Capsule())
            .shadow(color: Color(hex: 0x0050B8, alpha: 0.45), radius: 16, x: 0, y: 8)
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// `.btn.btn-line`
struct LineButtonStyle: ButtonStyle {
    var fullWidth: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BrandFont.heading(16, weight: .semibold))
            .foregroundStyle(configuration.isPressed ? Brand.greenDk : Brand.ink)
            .padding(.vertical, 16)
            .padding(.horizontal, 26)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(Brand.s2, in: Capsule())
            .overlay(
                Capsule().stroke(configuration.isPressed ? Brand.green : Brand.line2, lineWidth: 1)
            )
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

// MARK: - Card

/// The site's card shell: white, hairline border, 22pt corners, soft shadow.
struct Card<Content: View>: View {
    var padding: CGFloat = 20
    var background: Color = Brand.s2
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: Metrics.radiusCard, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.radiusCard, style: .continuous)
                    .stroke(Brand.line, lineWidth: 1)
            )
            .shadow(color: Color(hex: 0x0B0D10, alpha: 0.05), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Chips

/// `.chipk` — the little point-cost / status pill inside list rows.
struct Chip: View {
    enum Tone { case cost, good, neutral, wash }
    let text: String
    var tone: Tone = .neutral

    private var fg: Color {
        switch tone {
        case .cost:    return Brand.orange
        case .good:    return Brand.greenDk
        case .neutral: return Brand.dim
        case .wash:    return Brand.iris
        }
    }
    private var bg: Color {
        switch tone {
        case .cost:    return Brand.orange.opacity(0.12)
        case .good:    return Brand.wash
        case .neutral: return Brand.s3
        case .wash:    return Brand.irisWash
        }
    }

    var body: some View {
        Text(text)
            .font(BrandFont.heading(12, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(fg)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(bg, in: Capsule())
    }
}

/// `.badge` — outlined uppercase pill with a live dot.
struct LiveBadge: View {
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Brand.greenBr)
                .frame(width: 7, height: 7)
            Text(text.uppercased())
                .font(BrandFont.heading(11, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(Brand.dim)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Brand.s2.opacity(0.7), in: Capsule())
        .overlay(Capsule().stroke(Brand.line2, lineWidth: 1))
    }
}

// MARK: - Key/value row

/// `.mini .row` — label on the left, value or chip on the right, hairline rule.
struct StatRow<Trailing: View>: View {
    let label: String
    var showsDivider: Bool = true
    @ViewBuilder var trailing: Trailing

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(BrandFont.body(14, weight: .medium))
                    .foregroundStyle(Brand.dim)
                Spacer(minLength: 12)
                trailing
            }
            .padding(.vertical, 10)
            if showsDivider {
                Rectangle().fill(Brand.line).frame(height: 1)
            }
        }
    }
}

extension StatRow where Trailing == Text {
    init(label: String, value: String, showsDivider: Bool = true) {
        self.init(label: label, showsDivider: showsDivider) {
            Text(value)
                .font(BrandFont.heading(14, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Brand.ink)
        }
    }
}

// MARK: - Mesh background

/// The hero's drifting blur blobs (`.mesh` / `.blob`), toned down for a phone.
struct MeshBackground: View {
    @State private var drift = false

    var body: some View {
        ZStack {
            Brand.bg
            Circle()
                .fill(Brand.blobBlue).opacity(0.42)
                .frame(width: 340, height: 340)
                .blur(radius: 80)
                .offset(x: drift ? 110 : 150, y: drift ? -180 : -140)
            Circle()
                .fill(Brand.blobCyan).opacity(0.38)
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: drift ? -150 : -120, y: drift ? -40 : 0)
            Circle()
                .fill(Brand.blobPurple).opacity(0.34)
                .frame(width: 280, height: 280)
                .blur(radius: 80)
                .offset(x: drift ? 120 : 90, y: drift ? 180 : 220)
        }
        .ignoresSafeArea()
        .onAppear {
            guard !UIAccessibility.isReduceMotionEnabled else { return }
            withAnimation(.easeInOut(duration: 18).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }
}

// MARK: - Brand mark

/// The rounded-square logo tile from the site header (`.brand .mk`).
struct BrandMark: View {
    var size: CGFloat = 44

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            .fill(Brand.s2)
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                    .stroke(Brand.line, lineWidth: 1)
            )
            .overlay(
                Image("LaunchMark")
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.22)
            )
            .frame(width: size, height: size)
            .shadow(color: Color(hex: 0x0B0D10, alpha: 0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Text field

/// Matches the checkout form fields: 14pt corners, hairline border, blue focus
/// ring, and a reveal toggle on secure entry.
///
/// Focus is driven from the outside so screens can move the keyboard between
/// fields. `.focused()` on a container does not reliably reach a nested
/// `TextField`, so the binding is handed to the field itself. Focus values are
/// plain strings to keep the type non-generic.
struct BrandField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var autocapitalization: TextInputAutocapitalization = .never
    var errorMessage: String? = nil
    var focusBinding: FocusState<String?>.Binding? = nil
    var focusID: String? = nil

    @State private var revealed = false

    private var isFocused: Bool {
        guard let focusBinding, let focusID else { return false }
        return focusBinding.wrappedValue == focusID
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                field
                    .font(BrandFont.body(16))
                    .foregroundStyle(Brand.ink)
                    .keyboardType(keyboard)
                    .textContentType(contentType)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled()

                if isSecure {
                    Button {
                        revealed.toggle()
                    } label: {
                        Image(systemName: revealed ? "eye.slash" : "eye")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Brand.faint)
                    }
                    .accessibilityLabel(revealed ? "Hide password" : "Show password")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .background(Brand.s2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(borderColor, lineWidth: isFocused ? 1.6 : 1)
            )
            .animation(.easeOut(duration: 0.15), value: isFocused)

            if let errorMessage {
                Text(errorMessage)
                    .font(BrandFont.body(12.5, weight: .medium))
                    .foregroundStyle(Brand.red)
                    .transition(.opacity)
            }
        }
    }

    @ViewBuilder
    private var field: some View {
        if let focusBinding, let focusID {
            entry.focused(focusBinding, equals: focusID)
        } else {
            entry
        }
    }

    @ViewBuilder
    private var entry: some View {
        if isSecure && !revealed {
            SecureField(placeholder, text: $text)
        } else {
            TextField(placeholder, text: $text)
        }
    }

    private var borderColor: Color {
        if errorMessage != nil { return Brand.red }
        return isFocused ? Brand.green : Brand.line2
    }
}
