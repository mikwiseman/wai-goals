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

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: Theme.Spacing.s) {
                    ForEach(GoalEmotion.allCases) { emotion in
                        compactChoice(emotion)
                    }
                }
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: Theme.Spacing.m) {
                        ForEach(GoalEmotion.allCases) { emotion in
                            worldChoice(emotion)
                                .escherScrollDepth(axis: .horizontal)
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.vertical, Theme.Spacing.xs)
                    .padding(.horizontal, 2)
                }
                .contentMargins(.horizontal, 2, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
                .scrollIndicators(.hidden)
                .frame(height: 278)
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.78),
                   value: selection)
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func worldChoice(_ emotion: GoalEmotion) -> some View {
        let selected = selection == emotion
        return Button {
            selection = emotion
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Image(decorative: emotion.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 184, height: 184)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                            .strokeBorder(selected ? .white : .white.opacity(0.24),
                                          lineWidth: selected ? 2 : 0.75)
                    }
                    .shadow(color: emotion.worldTint.opacity(selected ? 0.48 : 0.18),
                            radius: selected ? 18 : 8, y: 8)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(emotion.displayName)
                            .font(.subheadline.weight(.bold))
                        Spacer()
                        if selected {
                            selectionCheck(tint: emotion.worldTint)
                        }
                    }
                    Text(emotion.feeling)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(Theme.Spacing.s)
            .frame(width: 208, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(selected ? tint.opacity(0.82) : .white.opacity(0.24),
                                  lineWidth: selected ? 1.5 : 0.75)
            }
            .scaleEffect(selected ? 1 : 0.965)
        }
        .buttonStyle(.waiPressable(scale: 0.94))
        .accessibilityLabel("\(emotion.displayName), \(emotion.feeling)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private func selectionCheck(tint: Color) -> some View {
        if reduceMotion {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(tint)
        } else {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(tint)
                .symbolEffect(.bounce)
        }
    }

    private func compactChoice(_ emotion: GoalEmotion) -> some View {
        let selected = selection == emotion
        return Button {
            selection = emotion
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                EmotionArtwork(emotion: emotion, size: 64)
                VStack(alignment: .leading, spacing: 3) {
                    Text(emotion.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(emotion.feeling)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(emotion.worldTint)
                }
            }
            .padding(Theme.Spacing.s)
            .background(selected ? tint.opacity(0.13) : Color(.tertiarySystemFill),
                        in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        }
        .buttonStyle(.waiPressable(scale: 0.97))
        .accessibilityLabel("\(emotion.displayName), \(emotion.feeling)")
        .accessibilityAddTraits(selected ? .isSelected : [])
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
                    withAnimation(.spring(response: 0.58, dampingFraction: 0.88).delay(WaiMotion.entranceDelay(order: order))) {
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
