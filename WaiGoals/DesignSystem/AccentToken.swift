import SwiftUI

/// The curated palette a goal can be tinted with. Stored as a string raw value
/// on the model; resolved to a `Color` for display. Kept deliberately small so
/// the app stays cohesive and minimal.
enum AccentToken: String, CaseIterable, Identifiable, Sendable {
    case indigo, violet, blue, teal, green, lime, amber, coral

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .indigo: "Indigo"
        case .violet: "Violet"
        case .blue: "Blue"
        case .teal: "Teal"
        case .green: "Green"
        case .lime: "Lime"
        case .amber: "Amber"
        case .coral: "Coral"
        }
    }

    /// A refined, slightly desaturated palette that reads well on both light
    /// and dark backgrounds.
    private var rgb: (r: Double, g: Double, b: Double) {
        switch self {
        case .indigo: (0.42, 0.40, 0.95)
        case .violet: (0.66, 0.38, 0.93)
        case .blue:   (0.20, 0.56, 0.98)
        case .teal:   (0.10, 0.70, 0.74)
        case .green:  (0.18, 0.74, 0.50)
        case .lime:   (0.52, 0.76, 0.24)
        case .amber:  (0.97, 0.70, 0.20)
        case .coral:  (0.98, 0.45, 0.42)
        }
    }

    var color: Color { Color(red: rgb.r, green: rgb.g, blue: rgb.b) }

    /// Black or white, whichever is legible on top of `color` — used for
    /// checkmarks/labels drawn over an accent fill (e.g. light amber/lime).
    var contrastingForeground: Color {
        let luminance = 0.2126 * rgb.r + 0.7152 * rgb.g + 0.0722 * rgb.b
        return luminance > 0.6 ? .black : .white
    }

    static let `default` = AccentToken.indigo
}
