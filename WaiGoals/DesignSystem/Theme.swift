import SwiftUI

/// Lightweight design tokens. Kept small and opinionated for a cohesive,
/// minimal look.
enum Theme {
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 6
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 28
        static let xxxl: CGFloat = 40
    }

    enum Radius {
        static let small: CGFloat = 12
        static let button: CGFloat = 16
        static let card: CGFloat = 22
        static let hero: CGFloat = 28
    }
}

// MARK: - Background

/// A subtle accent wash over the system background. Gives Liquid Glass surfaces
/// varied content to refract (glass on a perfectly flat color looks dead), while
/// staying quiet enough to feel minimal.
struct AppBackground: View {
    var tint: Color = .accentColor
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            if !reduceTransparency {
                LinearGradient(
                    colors: [tint.opacity(scheme == .dark ? 0.20 : 0.12), .clear],
                    startPoint: .top, endPoint: .center
                )
                .ignoresSafeArea()

                RadialGradient(
                    colors: [tint.opacity(scheme == .dark ? 0.16 : 0.10), .clear],
                    center: UnitPoint(x: 0.85, y: 0.08), startRadius: 0, endRadius: 380
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

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(scheme == .dark ? 0.06 : 0.04), lineWidth: 1)
            )
            .shadow(color: .black.opacity(scheme == .dark ? 0.0 : 0.05), radius: 12, x: 0, y: 6)
    }
}

extension View {
    /// A clean content card. Content lives on solid surfaces; glass is reserved
    /// for floating/navigation chrome (HIG layering).
    func card(cornerRadius: CGFloat = Theme.Radius.card) -> some View {
        modifier(CardModifier(cornerRadius: cornerRadius))
    }
}
