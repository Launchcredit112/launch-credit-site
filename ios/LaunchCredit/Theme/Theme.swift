import SwiftUI
import UIKit

/// Design tokens lifted 1:1 from the Launch marketing site (`index.html` `:root`).
/// Keep this file in sync with the CSS custom properties so web and app stay identical.
enum Brand {

    // MARK: - Surfaces
    static let bg      = Color(hex: 0xFFFFFF)
    static let s1      = Color(hex: 0xF5F7F9)
    static let s2      = Color(hex: 0xFFFFFF)
    static let s3      = Color(hex: 0xEEF1F4)

    // MARK: - Ink
    static let ink     = Color(hex: 0x0B0D10)
    static let dim     = Color(hex: 0x55605A)
    static let faint   = Color(hex: 0x8B958F)
    static let onGreen = Color(hex: 0x040C15)

    // MARK: - Lines
    static let line    = Color(hex: 0x0B0D10, alpha: 0.10)
    static let line2   = Color(hex: 0x0B0D10, alpha: 0.17)

    // MARK: - Primary (the site calls it "green"; the palette is blue)
    static let green   = Color(hex: 0x0059CC)
    static let greenBr = Color(hex: 0x0064E8)
    static let greenLt = Color(hex: 0x47A2EA)
    static let greenDk = Color(hex: 0x004199)
    static let wash    = Color(hex: 0xE8EFF8)

    // MARK: - Accents
    static let orange  = Color(hex: 0xE8963C)
    static let purple  = Color(hex: 0xB9A0FF)
    static let red     = Color(hex: 0xD14836)
    static let scoreLo = Color(hex: 0xE8431C)
    static let scoreHi = Color(hex: 0x0B5BE0)
    static let iris    = Color(hex: 0x4338CA)
    static let irisWash = Color(hex: 0xE9E9FB)

    /// `--grad: linear-gradient(135deg, #47A2EA 0%, #0060DC 100%)`
    static let grad = LinearGradient(
        colors: [Color(hex: 0x47A2EA), Color(hex: 0x0060DC)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// The hero mesh blobs, reused as an ambient background.
    static let blobBlue   = Color(hex: 0x80B5F5)
    static let blobCyan   = Color(hex: 0x9DDAFE)
    static let blobPurple = Color(hex: 0xD9CCFF)
}

// MARK: - Typography

/// The site pairs Outfit (headings) with Plus Jakarta Sans (body) and
/// Instrument Serif italic for accents. Those families ship as optional
/// bundle resources — see `Resources/Fonts/README.md`. When they are absent we
/// fall back to the system faces with matching weights and tracking, so the app
/// looks right out of the box and upgrades automatically once fonts are added.
enum BrandFont {

    private static let headingFamily = "Outfit"
    private static let bodyFamily    = "PlusJakartaSans"
    private static let serifFamily   = "InstrumentSerif-Italic"

    private static func isAvailable(_ family: String) -> Bool {
        availabilityCache.value(for: family)
    }

    /// `h1`/`h2`/`h3` on the site: Outfit 700, letter-spacing -.035em.
    static func heading(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        if isAvailable(headingFamily) {
            return .custom(headingFamily, size: size).weight(weight)
        }
        return .system(size: size, weight: weight, design: .rounded)
    }

    /// Body copy: Plus Jakarta Sans.
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if isAvailable(bodyFamily) {
            return .custom(bodyFamily, size: size).weight(weight)
        }
        return .system(size: size, weight: weight)
    }

    /// `.ital` — Instrument Serif italic, used for the emphasised half of a headline.
    static func serifItalic(_ size: CGFloat) -> Font {
        if isAvailable(serifFamily) {
            return .custom(serifFamily, size: size)
        }
        return .system(size: size, weight: .regular, design: .serif).italic()
    }

    /// `.eyebrow` — 12px / 700 / .22em uppercase.
    static var eyebrow: Font { heading(12, weight: .bold) }

    /// `.tnum` — tabular figures so score digits do not jitter while animating.
    static func number(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        heading(size, weight: weight).monospacedDigit()
    }

    private static let availabilityCache = FontAvailabilityCache()
}

/// Font lookups are not free, and the views ask on every layout pass.
private final class FontAvailabilityCache: @unchecked Sendable {
    private var cache: [String: Bool] = [:]
    private let lock = NSLock()

    func value(for family: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if let hit = cache[family] { return hit }
        let found = !UIFont.fontNames(forFamilyName: family).isEmpty
            || UIFont(name: family, size: 12) != nil
        cache[family] = found
        return found
    }
}

// MARK: - Metrics

enum Metrics {
    static let radiusCard: CGFloat = 22
    static let radiusTile: CGFloat = 16
    static let radiusPill: CGFloat = 100
    static let gutter: CGFloat = 20
    static let sectionGap: CGFloat = 26
}

// MARK: - Color helper

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue:  Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Score colour ramp

extension Brand {
    /// The site reads Poor as red and every band above it as blue (`index.html`,
    /// "Poor reads red, every tier above it reads blue").
    static func scoreColor(for score: Int) -> Color {
        score < 580 ? scoreLo : scoreHi
    }

    /// Band label — defined once in the model layer (`creditBand(for:)`).
    static func band(for score: Int) -> String { creditBand(for: score) }
}
