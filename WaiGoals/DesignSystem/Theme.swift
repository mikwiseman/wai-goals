import SwiftUI

/// Airy, semantic design tokens shared by every surface in the app.
enum Theme {
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
        static let huge: CGFloat = 64
    }

    enum Radius {
        static let small: CGFloat = 14
        static let button: CGFloat = 18
        static let card: CGFloat = 26
        static let hero: CGFloat = 32
    }

    static let pagePadding: CGFloat = 20
}

// MARK: - Background

/// A living field of colour under the system's Liquid Glass navigation layer:
/// three slow-drifting accent glows over the grouped background. Motion and
/// transparency fall back to a calm static wash when the user asks for less.
struct AppBackground: View {
    var tint: Color = .accentColor
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            if !reduceTransparency {
                if reduceMotion {
                    glowField
                } else {
                    glowField
                        .phaseAnimator([false, true]) { content, drift in
                            content
                                .offset(x: drift ? 24 : -20, y: drift ? -18 : 22)
                                .scaleEffect(drift ? 1.07 : 1.0)
                        } animation: { drift in
                            .easeInOut(duration: drift ? 9 : 11)
                        }
                }
            }
        }
    }

    private var glowField: some View {
        let dark = scheme == .dark
        return ZStack {
            RadialGradient(
                colors: [tint.opacity(dark ? 0.34 : 0.22), .clear],
                center: UnitPoint(x: 0.10, y: 0.0),
                startRadius: 0,
                endRadius: 520
            )
            RadialGradient(
                colors: [AccentToken.violet.partnerColor.opacity(dark ? 0.26 : 0.15), .clear],
                center: UnitPoint(x: 0.98, y: 0.22),
                startRadius: 0,
                endRadius: 460
            )
            RadialGradient(
                colors: [AccentToken.blue.partnerColor.opacity(dark ? 0.22 : 0.12), .clear],
                center: UnitPoint(x: 0.28, y: 1.04),
                startRadius: 0,
                endRadius: 560
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Card

private struct CardModifier: ViewModifier {
    var cornerRadius: CGFloat = Theme.Radius.card
    /// When set, the card picks up a faint coloured edge and ambient glow in
    /// that tint — used so a surface can echo the goal it belongs to.
    var tint: Color? = nil
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        reduceTransparency
                            ? AnyShapeStyle(Color(.secondarySystemBackground))
                            : AnyShapeStyle(.regularMaterial)
                    )
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        tint.map { $0.opacity(scheme == .dark ? 0.45 : 0.32) }
                            ?? (scheme == .dark ? Color.white.opacity(0.075) : Color.white.opacity(0.72)),
                        lineWidth: 0.75
                    )
            )
            .shadow(
                color: tint.map { $0.opacity(scheme == .dark ? 0.28 : 0.16) }
                    ?? .black.opacity(scheme == .dark ? 0 : 0.035),
                radius: tint == nil ? 18 : 14,
                x: 0,
                y: tint == nil ? 8 : 7
            )
    }
}

private struct GlassButtonModifier: ViewModifier {
    let prominent: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            if prominent {
                content.buttonStyle(.glassProminent)
            } else {
                content.buttonStyle(.glass)
            }
        } else if prominent {
            content.buttonStyle(.borderedProminent)
        } else {
            content.buttonStyle(.bordered)
        }
    }
}

extension View {
    /// A restrained content surface. Liquid Glass remains the functional layer
    /// for controls and navigation, while content uses adaptive material. Pass
    /// `tint` to give the card a faint coloured edge and glow.
    func card(cornerRadius: CGFloat = Theme.Radius.card, tint: Color? = nil) -> some View {
        modifier(CardModifier(cornerRadius: cornerRadius, tint: tint))
    }

    func waiGlassButton(prominent: Bool = false) -> some View {
        modifier(GlassButtonModifier(prominent: prominent))
    }
}
