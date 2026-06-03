import UIKit

/// Thin wrapper for imperative haptics. Most feedback uses SwiftUI's
/// `.sensoryFeedback`; this is for moments triggered from logic (e.g. hitting a
/// milestone) where a view trigger is awkward.
@MainActor
enum Haptics {
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    static func tap() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred()
    }
}
