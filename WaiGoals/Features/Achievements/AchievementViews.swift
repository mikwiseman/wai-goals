import SwiftUI

struct AchievementArtwork: View {
    let progress: AchievementProgress
    var size: CGFloat = 72
    var animated = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if animated, progress.isUnlocked, !reduceMotion {
                artwork
                    .phaseAnimator([false, true]) { content, lifted in
                        content
                            .scaleEffect(lifted ? 1.035 : 0.985)
                            .offset(y: lifted ? -4 : 3)
                    } animation: { lifted in
                        .easeInOut(duration: lifted ? 3.2 : 2.8)
                    }
            } else {
                artwork
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(progress.id.title)
        .accessibilityValue(progress.isUnlocked ? "Discovered" : progress.progressLabel)
    }

    private var artwork: some View {
        Image(decorative: progress.id.assetName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .saturation(progress.isUnlocked ? 1 : 0.38)
            .opacity(progress.isUnlocked ? 1 : 0.82)
            .overlay {
                if !progress.isUnlocked {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                        Image(systemName: "lock.fill")
                            .font(.system(size: size * 0.13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.92))
                    }
                    .frame(width: max(30, size * 0.24), height: max(30, size * 0.24))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .strokeBorder(.white.opacity(progress.isUnlocked ? 0.46 : 0.2), lineWidth: 0.75)
            }
            .shadow(color: .indigo.opacity(progress.isUnlocked ? 0.32 : 0.08),
                    radius: size * 0.12, y: size * 0.05)
    }
}

struct AchievementCard: View {
    let progress: AchievementProgress
    let namespace: Namespace.ID
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                AchievementArtwork(
                    progress: progress,
                    size: dynamicTypeSize.isAccessibilitySize ? 242 : 160,
                    animated: progress.isUnlocked
                )
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                        Text(progress.id.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                        Spacer(minLength: 0)
                        Image(systemName: progress.isUnlocked ? "sparkles" : "arrow.up.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(progress.isUnlocked ? Color.orange : .secondary)
                    }
                    Text(progress.isUnlocked ? progress.id.shortMeaning : progress.progressLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
                }

                ProgressView(value: progress.fraction)
                    .tint(progress.isUnlocked ? .orange : .indigo)
            }
            .padding(Theme.Spacing.m)
            .frame(width: dynamicTypeSize.isAccessibilitySize ? 286 : 192,
                   alignment: .leading)
            .card()
            .matchedTransitionSource(id: progress.id, in: namespace)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(progress.id.title)
        .accessibilityValue(progress.isUnlocked ? "Discovered. \(progress.id.shortMeaning)" : progress.progressLabel)
        .accessibilityHint("Opens artifact details")
        .accessibilityAddTraits(.isButton)
    }
}

struct AchievementDetailView: View {
    let progress: AchievementProgress
    let namespace: Namespace.ID

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if reduceMotion {
                content
            } else {
                content
                    .navigationTransition(.zoom(sourceID: progress.id, in: namespace))
            }
        }
        .navigationTitle("Artifact")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var content: some View {
        ZStack {
            AppBackground(tint: progress.isUnlocked ? .orange : .indigo)
            ScrollView {
                VStack(spacing: Theme.Spacing.xxl) {
                    ZStack {
                        if progress.isUnlocked {
                            Circle()
                                .fill(Color.orange.opacity(0.18))
                                .frame(width: 250, height: 250)
                                .blur(radius: 18)
                                .accessibilityHidden(true)
                        }
                        AchievementArtwork(
                            progress: progress,
                            size: dynamicTypeSize.isAccessibilitySize ? 260 : 310,
                            animated: true
                        )
                    }

                    VStack(spacing: Theme.Spacing.s) {
                        Text(progress.isUnlocked ? "ARTIFACT DISCOVERED" : "STILL FORMING")
                            .font(.caption.weight(.bold))
                            .tracking(1.4)
                            .foregroundStyle(progress.isUnlocked ? .orange : .secondary)
                        Text(progress.id.title)
                            .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                            .multilineTextAlignment(.center)
                        Text(progress.id.shortMeaning)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text("HOW TO FIND IT")
                                .font(.caption2.weight(.bold))
                                .tracking(1.2)
                                .foregroundStyle(.secondary)
                            Text(progress.id.requirement)
                                .font(.body.weight(.semibold))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        ProgressView(value: progress.fraction)
                            .tint(progress.isUnlocked ? .orange : .indigo)

                        HStack {
                            Label(progress.progressLabel,
                                  systemImage: progress.isUnlocked ? "sparkles" : "point.topleft.down.to.point.bottomright.curvepath")
                            Spacer(minLength: Theme.Spacing.m)
                            Text(progress.fraction.formatted(.percent.precision(.fractionLength(0))))
                                .fontWeight(.bold)
                                .monospacedDigit()
                        }
                        .font(.subheadline)
                        .foregroundStyle(progress.isUnlocked ? .primary : .secondary)
                    }
                    .padding(Theme.Spacing.xl)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
                }
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, Theme.Spacing.l)
                .padding(.bottom, Theme.Spacing.huge)
            }
            .scrollIndicators(.hidden)
        }
    }
}

struct AchievementDiscoveryCard: View {
    let achievements: [AchievementProgress]
    let revealed: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var primary: AchievementProgress? { achievements.first }

    var body: some View {
        if let primary {
            HStack(spacing: Theme.Spacing.m) {
                AchievementArtwork(progress: primary, size: 68, animated: revealed)
                VStack(alignment: .leading, spacing: 3) {
                    Text("ARTIFACT DISCOVERED")
                        .font(.caption2.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(.orange)
                    Text(primary.id.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(discoveryDetail(primary))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(Theme.Spacing.s)
            .background(.ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(Color.orange.opacity(0.54), lineWidth: 0.75)
            }
            .opacity(revealed || reduceMotion ? 1 : 0)
            .offset(y: revealed || reduceMotion ? 0 : 22)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Artifact discovered, \(primary.id.title). \(discoveryDetail(primary))")
        }
    }

    private func discoveryDetail(_ primary: AchievementProgress) -> String {
        if achievements.count > 1 {
            return "\(primary.id.shortMeaning) Plus \(achievements.count - 1) more in the archive."
        }
        return primary.id.shortMeaning
    }
}
