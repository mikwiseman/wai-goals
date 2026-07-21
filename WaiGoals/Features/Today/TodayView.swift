import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(NotificationCoordinator.self) private var coordinator
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Goal.sortIndex) private var allGoals: [Goal]

    @State private var showingEditor = false
    @State private var showingSettings = false
    @State private var completionMoment: CompletionJourneyMoment?
    @State private var selectedGoalID: UUID?
    @State private var deepLinkedGoal: Goal?
    @State private var intentionGoal: Goal?
    @State private var didHandleLaunch = false

    private let calendar = Calendar.current
    private var today: Date { calendar.startOfDay(for: .now) }

    private var dueGoals: [Goal] {
        allGoals
            .filter { !$0.isArchived && $0.schedule.isScheduled(on: today, calendar: calendar) }
    }

    private var sortedDue: [Goal] {
        dueGoals.sorted { a, b in
            let da = a.isCompleted(on: today, calendar: calendar)
            let db = b.isCompleted(on: today, calendar: calendar)
            if da != db { return !da } // pending first
            return a.sortIndex < b.sortIndex
        }
    }

    private var doneCount: Int {
        dueGoals.filter { $0.isCompleted(on: today, calendar: calendar) }.count
    }

    private var pendingGoals: [Goal] {
        dueGoals.filter { !$0.isCompleted(on: today, calendar: calendar) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                if allGoals.filter({ !$0.isArchived }).isEmpty {
                    EmptyStateView(
                        symbol: "sparkles",
                        emotion: .growth,
                        title: "Start with one goal",
                        message: "Track the habits that matter — like “Stop working at 7 PM.” One tap a day is all it takes.",
                        actionTitle: "Add a goal",
                        action: { showingEditor = true }
                    )
                } else {
                    content
                }
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingEditor = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add goal")
                }
            }
            .sheet(isPresented: $showingEditor) { GoalEditorView() }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .sheet(item: $intentionGoal) { goal in
                IntentionApprovalSheet(goal: goal, date: today, calendar: calendar)
            }
            .navigationDestination(item: $deepLinkedGoal) { GoalDetailView(goal: $0) }
            .onChange(of: coordinator.routeGoalID) { _, id in
                guard let id, let goal = allGoals.first(where: { $0.id == id }) else { return }
                deepLinkedGoal = goal
                coordinator.routeGoalID = nil
            }
            .task {
                guard !didHandleLaunch else { return }
                didHandleLaunch = true
                switch AppLaunch.openTarget {
                case "editor": showingEditor = true
                case "settings": showingSettings = true
                case "detail": deepLinkedGoal = allGoals.first { !$0.isArchived }
                case "milestone":
                    completionMoment = CompletionJourneyMoment(
                        goalTitle: allGoals.first?.title ?? "Your goal",
                        emotion: allGoals.first?.emotion ?? .growth,
                        progressLabel: "A new stair is visible",
                        milestone: "30 days in a row"
                    )
                default: break
                }
            }
        }
        .toolbar(completionMoment == nil ? .visible : .hidden, for: .tabBar)
        .overlay {
            if let completionMoment {
                GoalCompletionJourney(moment: completionMoment) {
                    dismissCompletion()
                }
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 1.04)))
                .zIndex(20)
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                Text(today.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, Theme.Spacing.xxs)
                    .entranceMotion(order: 0)
                hero
                    .entranceMotion(order: 1)

                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    SectionHeading(
                        title: "Today’s goals",
                        detail: sortedDue.isEmpty ? "Open day" : "\(doneCount)/\(dueGoals.count) complete"
                    )
                    todayGoalsSurface
                }
                .entranceMotion(order: 2)
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, Theme.Spacing.xs)
            .padding(.bottom, Theme.Spacing.huge)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var todayGoalsSurface: some View {
        if sortedDue.isEmpty {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: "circle.dotted")
                    .font(.title2)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text("Nothing scheduled")
                        .font(.headline)
                    Text("The open space is part of the path too.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        } else {
            LazyVStack(spacing: 0) {
                ForEach(Array(sortedDue.enumerated()), id: \.element.id) { index, goal in
                    let hasIntention = goal.hasIntention(on: today, calendar: calendar)
                    TodayGoalRow(
                        goal: goal,
                        isDone: goal.isCompleted(on: today, calendar: calendar),
                        hasIntention: hasIntention,
                        calendar: calendar,
                        onToggle: { toggle(goal) },
                        onIntend: { intentionGoal = goal },
                        onOpen: { deepLinkedGoal = goal }
                    )
                    .padding(.horizontal, Theme.Spacing.l)

                    if index < sortedDue.count - 1 {
                        Divider()
                            .padding(.leading, 80)
                    }
                }
            }
            .card()
        }
    }

    private var hero: some View {
        let total = dueGoals.count
        let fraction = total == 0 ? 0 : Double(doneCount) / Double(total)
        return VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            if sortedDue.isEmpty {
                EscherWorldStage(
                    emotion: nil,
                    title: "An open step",
                    eyebrow: "Today’s observatory",
                    message: "No goal needs your attention today.",
                    progress: 0,
                    height: 354
                )
            } else {
                TabView(selection: $selectedGoalID) {
                    ForEach(sortedDue) { goal in
                        let done = goal.isCompleted(on: today, calendar: calendar)
                        EscherWorldStage(
                            emotion: goal.emotion,
                            title: goal.title,
                            eyebrow: done ? "Step complete" : "Today’s next stair",
                            message: goal.emotion?.worldPrompt ?? goal.schedule.summary(calendar: calendar),
                            progress: fraction,
                            isComplete: done,
                            height: 382,
                            actionTitle: done
                                ? (dynamicTypeSize.isAccessibilitySize ? "Open" : "Open this world")
                                : (dynamicTypeSize.isAccessibilitySize ? "Complete" : "Complete this step"),
                            actionSymbol: done ? "arrow.up.right" : "checkmark",
                            action: done ? { deepLinkedGoal = goal } : { toggle(goal) }
                        )
                        .padding(.horizontal, 1)
                        .tag(Optional(goal.id))
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: dynamicTypeSize.isAccessibilitySize ? 820 : 382)
                .animation(reduceMotion ? nil : WaiMotion.spatial, value: selectedGoalID)

                worldRail

                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                            Text(doneCount == total ? "Every world moved forward" : "\(doneCount) of \(total) stairs climbed")
                            Text(fraction.formatted(.percent.precision(.fractionLength(0))))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                        }
                        .font(.subheadline.weight(.semibold))
                    } else {
                        HStack(alignment: .firstTextBaseline) {
                            Text(doneCount == total ? "Every world moved forward" : "\(doneCount) of \(total) stairs climbed")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(fraction.formatted(.percent.precision(.fractionLength(0))))
                                .font(.caption.weight(.bold))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                        }
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
        .onAppear(perform: selectInitialGoal)
        .onChange(of: sortedDue.map(\.id)) { _, ids in
            if let selectedGoalID, ids.contains(selectedGoalID) { return }
            selectInitialGoal()
        }
    }

    private var worldRail: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Theme.Spacing.s) {
                ForEach(sortedDue) { goal in
                    let selected = selectedGoalID == goal.id
                    let done = goal.isCompleted(on: today, calendar: calendar)
                    Button {
                        if reduceMotion {
                            selectedGoalID = goal.id
                        } else {
                            withAnimation(WaiMotion.spatial) { selectedGoalID = goal.id }
                        }
                    } label: {
                        ZStack(alignment: .bottomTrailing) {
                            if let emotion = goal.emotion {
                                EmotionArtwork(emotion: emotion, size: selected ? 52 : 44)
                            } else {
                                GoalIcon(symbol: goal.symbol, tint: goal.accent.color,
                                         size: selected ? 52 : 44)
                            }
                            if done {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white, goal.accent.color)
                                    .background(Circle().fill(Color(.systemBackground)))
                                    .offset(x: 3, y: 3)
                                    .dynamicTypeSize(.large)
                            }
                        }
                        .padding(3)
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(selected ? goal.accent.color : .clear, lineWidth: 2)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(goal.title)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 3)
        }
        .scrollIndicators(.hidden)
    }

    private func toggle(_ goal: Goal) {
        let wasDone = goal.isCompleted(on: today, calendar: calendar)
        let newStreak = goal.toggleCompletion(on: today, context: context, calendar: calendar)
        if let newStreak, Milestone.reached(newStreak) {
            Haptics.success()
            if let emotion = goal.emotion {
                showCompletion(goal: goal, emotion: emotion,
                               milestone: "\(newStreak) \(goal.schedule.streakUnit.label(for: newStreak)) in a row")
            }
        } else if !wasDone, let emotion = goal.emotion {
            showCompletion(goal: goal, emotion: emotion)
        }
    }

    private func showCompletion(goal: Goal, emotion: GoalEmotion, milestone: String? = nil) {
        let moment = CompletionJourneyMoment(
            goalTitle: goal.title,
            emotion: emotion,
            progressLabel: "\(doneCount) of \(dueGoals.count) today",
            milestone: milestone
        )
        if reduceMotion {
            completionMoment = moment
        } else {
            withAnimation(WaiMotion.reveal) {
                completionMoment = moment
            }
        }
    }

    private func dismissCompletion() {
        if reduceMotion {
            completionMoment = nil
        } else {
            withAnimation(.easeOut(duration: 0.24)) {
                completionMoment = nil
            }
        }
    }

    private func selectInitialGoal() {
        selectedGoalID = pendingGoals.first?.id ?? sortedDue.first?.id
    }
}
