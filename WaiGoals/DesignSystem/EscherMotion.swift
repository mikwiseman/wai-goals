import SwiftUI

// MARK: - Motion language

enum WaiMotion {
    static let quick = Animation.snappy(duration: 0.24, extraBounce: 0.06)
    static let spatial = Animation.spring(response: 0.62, dampingFraction: 0.84)
    static let reveal = Animation.spring(response: 0.82, dampingFraction: 0.82)
}

extension GoalEmotion {
    var worldTint: Color {
        switch self {
        case .focus: .indigo
        case .calm: .cyan
        case .courage: .purple
        case .energy: .orange
        case .joy: .pink
        case .connection: .blue
        case .growth: .mint
        case .balance: .teal
        }
    }

    var worldPrompt: String {
        switch self {
        case .focus: "Find the one clear stair."
        case .calm: "Let the noise fall away."
        case .courage: "Take the stair that looks impossible."
        case .energy: "Turn intention into motion."
        case .joy: "Leave room for surprise."
        case .connection: "Move toward what matters together."
        case .growth: "Become through the next small step."
        case .balance: "Return every part to its place."
        }
    }
}

// MARK: - Living world

/// The central product surface: goal data and Escher artwork share one spatial
/// stage instead of appearing as a card plus a decorative thumbnail.
struct EscherWorldStage: View {
    let emotion: GoalEmotion?
    let title: String
    let eyebrow: String
    let message: String
    var progress: Double = 0
    var isComplete = false
    var height: CGFloat = 382
    var actionTitle: String?
    var actionSymbol = "arrow.up.right"
    var action: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibleStage
            } else {
                cinematicStage
            }
        }
        .frame(height: dynamicTypeSize.isAccessibilitySize ? max(height, 820) : height)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous)
                .strokeBorder(.white.opacity(0.28), lineWidth: 0.75)
        }
        .shadow(color: (emotion?.worldTint ?? .indigo).opacity(0.22), radius: 28, y: 16)
    }

    private var cinematicStage: some View {
        GeometryReader { proxy in
            ZStack {
                stageBackground

                worldArtwork(width: proxy.size.width)
                    .offset(y: -30)

                LinearGradient(
                    colors: [.clear, .black.opacity(0.08), .black.opacity(0.84)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 0) {
                    stageHeader
                    Spacer(minLength: Theme.Spacing.xl)
                    stageCopy
                }
                .padding(Theme.Spacing.xl)
            }
        }
    }

    private var accessibleStage: some View {
        ZStack {
            stageBackground

            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                stageHeader

                worldArtwork(width: 300)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)

                if let emotion {
                    Text(emotion.displayName.uppercased())
                        .font(.caption.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(emotion.worldTint.mix(with: .white, by: 0.48))
                        .dynamicTypeSize(.small ... .xxxLarge)
                }

                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)

                ProgressView(value: min(max(progress, 0), 1))
                    .tint(.white)

                if let actionTitle, let action {
                    Button(action: action) {
                        Label(actionTitle, systemImage: actionSymbol)
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .waiGlassButton(prominent: true)
                    .tint(emotion?.worldTint ?? .indigo)
                    .controlSize(.large)
                    .accessibilityLabel(actionTitle)
                }
            }
            .padding(Theme.Spacing.xl)
        }
    }

    private var stageBackground: some View {
        let tint = emotion?.worldTint ?? .indigo
        return ZStack {
            Color(red: 0.018, green: 0.025, blue: 0.10)

            if !reduceTransparency {
                RadialGradient(
                    colors: [tint.opacity(0.48), tint.opacity(0.12), .clear],
                    center: UnitPoint(x: 0.72, y: 0.22),
                    startRadius: 6,
                    endRadius: 320
                )
                LinearGradient(
                    colors: [.white.opacity(0.08), .clear, tint.opacity(0.14)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    @ViewBuilder
    private func worldArtwork(width: CGFloat) -> some View {
        let size = min(width * 0.84, 326)
        if let emotion {
            Group {
                if reduceMotion {
                    rawArtwork(emotion: emotion, size: size)
                } else {
                    rawArtwork(emotion: emotion, size: size)
                        .phaseAnimator([false, true]) { content, lifted in
                            content
                                .scaleEffect(lifted ? 1.035 : 0.985)
                                .offset(y: lifted ? -5 : 4)
                        } animation: { lifted in
                            .easeInOut(duration: lifted ? 3.8 : 3.4)
                        }
                }
            }
        } else {
            Image("GoalJourney")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        }
    }

    private func rawArtwork(emotion: GoalEmotion, size: CGFloat) -> some View {
        Image(decorative: emotion.assetName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .shadow(color: emotion.worldTint.opacity(0.46), radius: 26, y: 12)
    }

    private var stageHeader: some View {
        HStack(spacing: Theme.Spacing.s) {
            Text(eyebrow.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.76))
            Spacer(minLength: Theme.Spacing.m)
            HStack(spacing: 6) {
                Image(systemName: isComplete ? "checkmark" : "point.topleft.down.to.point.bottomright.curvepath")
                Text(isComplete ? "ARRIVED" : progress.formatted(.percent.precision(.fractionLength(0))))
                    .contentTransition(.numericText())
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .dynamicTypeSize(.small ... .xxxLarge)
    }

    private var stageCopy: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            if let emotion {
                Text(emotion.displayName.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(emotion.worldTint.mix(with: .white, by: 0.48))
                    .dynamicTypeSize(.small ... .xxxLarge)
            }
            Text(title)
                .font(.system(dynamicTypeSize.isAccessibilitySize ? .title3 : .title2,
                              design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
            Text(message)
                .font(dynamicTypeSize.isAccessibilitySize ? .body : .subheadline)
                .foregroundStyle(.white.opacity(0.74))
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)

            ProgressView(value: min(max(progress, 0), 1))
                .tint(.white)
                .padding(.top, Theme.Spacing.xxs)

            if let actionTitle, let action {
                Button(action: action) {
                    Label(actionTitle, systemImage: actionSymbol)
                        .font((dynamicTypeSize.isAccessibilitySize ? Font.body : .subheadline).weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .waiGlassButton(prominent: true)
                .tint(emotion?.worldTint ?? .indigo)
                .controlSize(.large)
                .padding(.top, Theme.Spacing.xs)
                .accessibilityLabel(actionTitle)
            }
        }
    }
}

// MARK: - Full-screen completion journey

struct CompletionJourneyMoment: Identifiable, Equatable {
    let id: UUID
    let goalTitle: String
    let emotion: GoalEmotion
    let progressLabel: String
    let milestone: String?
    let achievements: [AchievementProgress]

    init(goalTitle: String, emotion: GoalEmotion, progressLabel: String,
         milestone: String? = nil, achievements: [AchievementProgress] = [],
         id: UUID = UUID()) {
        self.id = id
        self.goalTitle = goalTitle
        self.emotion = emotion
        self.progressLabel = progressLabel
        self.milestone = milestone
        self.achievements = achievements
    }
}

struct GoalCompletionJourney: View {
    let moment: CompletionJourneyMoment
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var revealed = false
    @State private var glow = false
    @State private var artifactRevealed = false

    var body: some View {
        ZStack {
            background

            if dynamicTypeSize.isAccessibilitySize {
                ScrollView {
                    journeyContent(artworkSize: 220, accessible: true)
                        .padding(.top, 84)
                        .padding(.bottom, Theme.Spacing.huge)
                        .containerRelativeFrame(.horizontal)
                        .offset(x: -Theme.Spacing.xxxl)
                }
                .scrollIndicators(.hidden)
                .frame(maxWidth: .infinity)
            } else {
                journeyContent(artworkSize: 308, accessible: false)
                    .padding(.vertical, Theme.Spacing.l)
                    .padding(.top, 34)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // The NavigationStack overlay carries a 48pt horizontal
                    // content offset; cancel it so the full-screen journey is
                    // centered in the physical display.
                    .offset(x: -Theme.Spacing.xxxl)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .accessibilityElement(children: .contain)
        .onAppear(perform: start)
    }

    private func journeyContent(artworkSize: CGFloat, accessible: Bool) -> some View {
        VStack(spacing: accessible ? Theme.Spacing.m : Theme.Spacing.l) {
            if !accessible {
                Spacer(minLength: Theme.Spacing.m)
                    .frame(maxHeight: 86)
            }

            journeyArtwork(size: artworkSize)

            VStack(spacing: Theme.Spacing.s) {
                if let milestone = moment.milestone {
                    Text(milestone)
                        .font(.system(accessible ? .title3 : .largeTitle,
                                      design: .rounded).weight(.heavy))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .multilineTextAlignment(.center)
                        .lineLimit(accessible ? nil : 2)
                        .minimumScaleFactor(accessible ? 1 : 0.72)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(moment.emotion.completionMessage)
                    .font(.system(accessible ? .headline : .title2,
                                  design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(accessible ? nil : 2)
                    .minimumScaleFactor(accessible ? 1 : 0.8)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(moment.goalTitle) · \(moment.progressLabel)")
                    .font(accessible ? .body : .subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .lineLimit(accessible ? nil : 2)
                    .minimumScaleFactor(accessible ? 1 : 0.82)
                    .fixedSize(horizontal: false, vertical: true)
                    .dynamicTypeSize(accessible ? .small ... .xxxLarge : .small ... .accessibility5)
            }
            .frame(maxWidth: 354)

            progressPips

            if !moment.achievements.isEmpty {
                AchievementDiscoveryCard(
                    achievements: moment.achievements,
                    revealed: artifactRevealed
                )
                .frame(maxWidth: 354)
                .animation(reduceMotion ? nil : WaiMotion.reveal, value: artifactRevealed)
            }

            Button("Continue", action: onDismiss)
                .fontWeight(.semibold)
                .waiGlassButton(prominent: true)
                .tint(moment.emotion.worldTint)
                .controlSize(.large)
                .frame(maxWidth: 354)
                .padding(.top, Theme.Spacing.xs)
        }
        .frame(width: 354)
    }

    private func journeyArtwork(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(moment.emotion.worldTint.opacity(glow ? 0.05 : 0.58), lineWidth: 2)
                .frame(width: size * 0.8, height: size * 0.8)
                .scaleEffect(glow ? 1.42 : 0.72)
                .opacity(reduceMotion ? 0 : 1)

            Image(decorative: moment.emotion.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .mask {
                    RadialGradient(
                        colors: [.black, .black, .clear],
                        center: .center,
                        startRadius: size * 0.3,
                        endRadius: size * 0.68
                    )
                }
                .scaleEffect(reduceMotion ? 1 : (revealed ? 1 : 0.72))
                .offset(y: reduceMotion ? 0 : (revealed ? -8 : 54))
                .rotation3DEffect(
                    .degrees(reduceMotion || revealed ? 0 : 8),
                    axis: (x: 1, y: 0, z: 0),
                    perspective: 0.55
                )
                .shadow(color: moment.emotion.worldTint.opacity(0.62), radius: 34, y: 18)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var progressPips: some View {
        HStack(spacing: 7) {
            ForEach(0..<5, id: \.self) { index in
                Capsule()
                    .fill(index < 4 ? moment.emotion.worldTint : .white)
                    .frame(width: index == 4 ? 34 : 12, height: 6)
                    .opacity(revealed || reduceMotion ? 1 : 0.18)
                    .animation(
                        reduceMotion ? nil : WaiMotion.quick.delay(Double(index) * 0.07),
                        value: revealed
                    )
            }
        }
        .accessibilityHidden(true)
    }

    private var background: some View {
        ZStack {
            Color(red: 0.008, green: 0.012, blue: 0.055)
            Image(decorative: moment.emotion.assetName)
                .resizable()
                .scaledToFill()
                .blur(radius: 52)
                .scaleEffect(1.36)
                .opacity(0.28)
            LinearGradient(
                colors: [.black.opacity(0.05), .black.opacity(0.62)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private func start() {
        guard !reduceMotion else {
            revealed = true
            artifactRevealed = true
            return
        }
        withAnimation(WaiMotion.reveal) {
            revealed = true
        }
        withAnimation(.easeOut(duration: 1.2)) {
            glow = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(720))
            withAnimation(WaiMotion.reveal) {
                artifactRevealed = true
            }
        }
    }
}

// MARK: - Scroll depth

extension View {
    func escherScrollDepth(axis: Axis = .vertical) -> some View {
        modifier(EscherScrollDepthModifier(axis: axis))
    }
}

private struct EscherScrollDepthModifier: ViewModifier {
    let axis: Axis
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.scrollTransition(axis: axis) { view, phase in
                view
                    .scaleEffect(phase.isIdentity ? 1 : 0.94)
                    .opacity(phase.isIdentity ? 1 : 0.72)
            }
        }
    }
}
