import SwiftUI

// MARK: - Generated emotional artwork

struct EmotionArtwork: View {
    let emotion: GoalEmotion
    var size: CGFloat = 56
    var animated = false
    var decorative = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if animated && !reduceMotion {
                artwork
                    .phaseAnimator([false, true]) { content, lifted in
                        content
                            .offset(y: lifted ? -4 : 3)
                            .scaleEffect(lifted ? 1.025 : 0.985)
                    } animation: { lifted in
                        .easeInOut(duration: lifted ? 3.6 : 3.2)
                    }
            } else {
                artwork
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(emotion.displayName)
        .accessibilityHidden(decorative)
    }

    private var artwork: some View {
        Image(decorative: emotion.assetName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .strokeBorder(.white.opacity(0.42), lineWidth: 0.75)
            }
            .shadow(color: .indigo.opacity(0.16), radius: size * 0.14, y: size * 0.06)
    }
}

struct EmotionPill: View {
    let emotion: GoalEmotion
    var showsFeeling = false

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            EmotionArtwork(emotion: emotion, size: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(emotion.displayName)
                    .font(.caption.weight(.semibold))
                if showsFeeling {
                    Text(emotion.feeling)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.trailing, Theme.Spacing.s)
        .padding(.vertical, 4)
        .padding(.leading, 4)
        .background(.thinMaterial, in: Capsule())
        .overlay { Capsule().strokeBorder(.white.opacity(0.38), lineWidth: 0.5) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Desired feeling: \(emotion.displayName), \(emotion.feeling)")
    }
}

// MARK: - Picker

struct EmotionPicker: View {
    @Binding var selection: GoalEmotion?
    var tint: Color = .accentColor
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var columns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            [GridItem(.flexible())]
        } else {
            [
                GridItem(.flexible(), spacing: Theme.Spacing.s),
                GridItem(.flexible(), spacing: Theme.Spacing.s)
            ]
        }
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.s) {
            ForEach(GoalEmotion.allCases) { emotion in
                let selected = selection == emotion
                Button {
                    selection = emotion
                } label: {
                    HStack(spacing: Theme.Spacing.s) {
                        EmotionArtwork(emotion: emotion, size: 54)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(emotion.displayName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                            Text(emotion.feeling)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(Theme.Spacing.xs)
                    .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                            .fill(selected ? tint.opacity(0.13) : Color(.tertiarySystemFill))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                            .strokeBorder(selected ? tint.opacity(0.78) : .clear, lineWidth: 1.5)
                    }
                    .scaleEffect(selected ? 1.018 : 1)
                    .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(emotion.displayName), \(emotion.feeling)")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.78),
                   value: selection)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

// MARK: - Completion reward

struct EmotionCompletionOverlay: View {
    let emotion: GoalEmotion

    var body: some View {
        ZStack {
            Color.black.opacity(0.14)
                .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.m) {
                EmotionArtwork(emotion: emotion, size: 118, animated: true)
                VStack(spacing: 5) {
                    Text(emotion.displayName)
                        .font(.title3.weight(.bold))
                    Text(emotion.completionMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: 280)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous)
                    .strokeBorder(.white.opacity(0.52), lineWidth: 0.75)
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(emotion.displayName). \(emotion.completionMessage)")
    }
}

// MARK: - Staggered screen reveal

private struct EntranceMotionModifier: ViewModifier {
    let order: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: reduceMotion || visible ? 0 : 14)
            .onAppear {
                if reduceMotion {
                    visible = true
                } else {
                    withAnimation(.spring(response: 0.58, dampingFraction: 0.88).delay(Double(order) * 0.055)) {
                        visible = true
                    }
                }
            }
            .onChange(of: reduceMotion) { _, reduced in
                if reduced { visible = true }
            }
    }
}

extension View {
    func entranceMotion(order: Int) -> some View {
        modifier(EntranceMotionModifier(order: order))
    }
}
