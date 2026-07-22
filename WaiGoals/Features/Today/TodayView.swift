import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(NotificationCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Goal.sortIndex) private var allGoals: [Goal]

    @State private var showingEditor = false
    @State private var showingSettings = false
    @State private var completionMoment: CompletionJourneyMoment?
    @State private var recentlyCompletedGoalID: UUID?
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

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                if allGoals.filter({ !$0.isArchived }).isEmpty {
                    EmptyStateView(
                        symbol: "target",
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
                case "achievement":
                    completionMoment = CompletionJourneyMoment(
                        goalTitle: allGoals.first?.title ?? "Your goal",
                        emotion: allGoals.first?.emotion ?? .growth,
                        progressLabel: "A real step moved the path",
                        achievements: [
                            AchievementProgress(
                                id: .atlasMaker,
                                currentValue: 100,
                                targetValue: 100
                            )
                        ]
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
        List {
            if sortedDue.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Nothing scheduled")
                        .font(.headline)
                    Text("Today is open. Your other goals are still available in Goals.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, Theme.Spacing.m)
                .listRowBackground(Color.clear)
            } else {
                ForEach(sortedDue) { goal in
                    let isDone = goal.isCompleted(on: today, calendar: calendar)
                    let hasIntention = goal.hasIntention(on: today, calendar: calendar)
                    TodayGoalRow(
                        goal: goal,
                        isDone: isDone,
                        hasIntention: hasIntention,
                        isCelebrating: recentlyCompletedGoalID == goal.id,
                        calendar: calendar,
                        onToggle: { toggle(goal) },
                        onOpen: { deepLinkedGoal = goal }
                    )
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        if !isDone {
                            Button {
                                intentionGoal = goal
                            } label: {
                                Label(
                                    hasIntention ? "Review intention" : "Set intention",
                                    systemImage: hasIntention ? "checkmark.seal.fill" : "target"
                                )
                            }
                            .tint(goal.accent.color)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(.secondary.opacity(0.14))
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, Theme.Spacing.xs, for: .scrollContent)
        .animation(reduceMotion ? nil : WaiMotion.spatial, value: sortedDue.map(\.id))
    }

    private func toggle(_ goal: Goal) {
        let before = AchievementSnapshot(goals: allGoals, calendar: calendar)
        let wasDone = goal.isCompleted(on: today, calendar: calendar)
        let completedBeforeToggle = doneCount
        let newStreak = withAnimation(reduceMotion ? nil : WaiMotion.quick) {
            goal.toggleCompletion(on: today, context: context, calendar: calendar)
        }
        let achievements = wasDone ? [] : AchievementEngine.newlyUnlocked(
            before: before,
            after: before.addingCompletion(to: goal.id, on: today, calendar: calendar),
            excluding: Set(context.allAchievementUnlocks().compactMap(\.achievement)),
            asOf: today,
            calendar: calendar
        )
        AchievementUnlockStore.record(achievements.map(\.id), context: context)
        let completedToday = wasDone
            ? max(completedBeforeToggle - 1, 0)
            : min(completedBeforeToggle + 1, dueGoals.count)

        if !wasDone {
            showRowFeedback(for: goal.id)
        }

        if !wasDone, let newStreak, Milestone.reached(newStreak) {
            if let emotion = goal.emotion {
                showCompletion(goal: goal, emotion: emotion,
                               milestone: "\(newStreak) \(goal.schedule.streakUnit.label(for: newStreak)) in a row",
                               achievements: achievements,
                               completedToday: completedToday)
            }
        }
    }

    private func showCompletion(
        goal: Goal,
        emotion: GoalEmotion,
        milestone: String? = nil,
        achievements: [AchievementProgress] = [],
        completedToday: Int
    ) {
        let moment = CompletionJourneyMoment(
            goalTitle: goal.title,
            emotion: emotion,
            progressLabel: "\(completedToday) of \(dueGoals.count) steps today",
            milestone: milestone,
            achievements: achievements
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

    private func showRowFeedback(for goalID: UUID) {
        if reduceMotion {
            recentlyCompletedGoalID = goalID
        } else {
            withAnimation(WaiMotion.quick) {
                recentlyCompletedGoalID = goalID
            }
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(650))
            guard recentlyCompletedGoalID == goalID else { return }
            if reduceMotion {
                recentlyCompletedGoalID = nil
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    recentlyCompletedGoalID = nil
                }
            }
        }
    }
}
