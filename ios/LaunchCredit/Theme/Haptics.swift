import UIKit

/// Physical feedback for the moments that matter: a move marked done, a bill
/// switched on. Used sparingly — a phone that buzzes at everything stops
/// meaning anything.
enum Haptics {

    /// A confirmed change: the payment landed, the score moved.
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// A control was hit — a toggle, an offered action.
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
