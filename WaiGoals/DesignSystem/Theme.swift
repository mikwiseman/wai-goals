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

/// A quiet field of light under the system's Liquid Glass navigation layer.
struct AppBackground: View {
    var tint: Color = .accentColor
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            if !reduceTransparency {
                LinearGradient(
                    colors: [
                        tint.opacity(scheme == .dark ? 0.20 : 0.13),
                        Color.blue.opacity(scheme == .dark ? 0.08 : 0.045),
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: UnitPoint(x: 0.72, y: 0.56)
                )
                .ignoresSafeArea()

                RadialGradient(
                    colors: [tint.opacity(scheme == .dark ? 0.14 : 0.08), .clear],
                    center: UnitPoint(x: 0.88, y: 0.04),
                    startRadius: 0,
                    endRadius: 420
                )
                .ignoresSafeArea()
            }
        }
    }
}

// MARK: - Card

private struct CardModifier: ViewModifier {
    var cornerRadius: CGFloat = Theme.Radius.card
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
                        scheme == .dark ? Color.white.opacity(0.075) : Color.white.opacity(0.72),
                        lineWidth: 0.75
                    )
            )
            .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.035), radius: 18, x: 0, y: 8)
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
    /// for controls and navigation, while content uses adaptive material.
    func card(cornerRadius: CGFloat = Theme.Radius.card) -> some View {
        modifier(CardModifier(cornerRadius: cornerRadius))
    }

    func waiGlassButton(prominent: Bool = false) -> some View {
        modifier(GlassButtonModifier(prominent: prominent))
    }
}
