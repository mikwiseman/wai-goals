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

    /// A vivid, saturated palette that keeps its energy on both light and dark
    /// backgrounds.
    private var rgb: (r: Double, g: Double, b: Double) {
        switch self {
        case .indigo: (0.44, 0.32, 1.00)
        case .violet: (0.71, 0.30, 0.98)
        case .blue:   (0.14, 0.55, 1.00)
        case .teal:   (0.04, 0.75, 0.79)
        case .green:  (0.09, 0.78, 0.45)
        case .lime:   (0.56, 0.82, 0.10)
        case .amber:  (1.00, 0.71, 0.08)
        case .coral:  (1.00, 0.41, 0.38)
        }
    }

    /// A neighbouring hue used as the second stop in accent gradients, so
    /// filled controls read as lit from within rather than flat.
    private var partnerRGB: (r: Double, g: Double, b: Double) {
        switch self {
        case .indigo: (0.24, 0.62, 1.00)
        case .violet: (0.96, 0.34, 0.84)
        case .blue:   (0.16, 0.82, 1.00)
        case .teal:   (0.20, 0.90, 0.66)
        case .green:  (0.52, 0.89, 0.18)
        case .lime:   (0.88, 0.90, 0.12)
        case .amber:  (1.00, 0.50, 0.10)
        case .coral:  (1.00, 0.28, 0.56)
        }
    }

    var color: Color { Color(red: rgb.r, green: rgb.g, blue: rgb.b) }

    var partnerColor: Color { Color(red: partnerRGB.r, green: partnerRGB.g, blue: partnerRGB.b) }

    /// Two-stop gradient from the accent toward its partner hue.
    var gradientColors: [Color] { [color, partnerColor] }

    /// Black or white, selected against both gradient stops using WCAG
    /// relative luminance so symbols remain legible across the whole fill.
    var gradientForeground: Color {
        blackGradientContrast >= whiteGradientContrast ? .black : .white
    }

    /// Exposed for a regression test that enforces the 3:1 graphical contrast
    /// target across every accent gradient.
    var minimumGradientForegroundContrast: Double {
        max(blackGradientContrast, whiteGradientContrast)
    }

    /// Black or white, whichever is legible on top of `color` — used for
    /// checkmarks/labels drawn over an accent fill (e.g. light amber/lime).
    var contrastingForeground: Color {
        let luminance = 0.2126 * rgb.r + 0.7152 * rgb.g + 0.0722 * rgb.b
        return luminance > 0.6 ? .black : .white
    }

    private var blackGradientContrast: Double {
        let darkerStop = min(Self.relativeLuminance(rgb), Self.relativeLuminance(partnerRGB))
        return (darkerStop + 0.05) / 0.05
    }

    private var whiteGradientContrast: Double {
        let lighterStop = max(Self.relativeLuminance(rgb), Self.relativeLuminance(partnerRGB))
        return 1.05 / (lighterStop + 0.05)
    }

    private static func relativeLuminance(_ rgb: (r: Double, g: Double, b: Double)) -> Double {
        func linearized(_ component: Double) -> Double {
            component <= 0.04045
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * linearized(rgb.r)
            + 0.7152 * linearized(rgb.g)
            + 0.0722 * linearized(rgb.b)
    }

    static let `default` = AccentToken.indigo
}
