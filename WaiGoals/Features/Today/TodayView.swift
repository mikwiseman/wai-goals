import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(NotificationCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Goal.sortIndex) private var allGoals: [Goal]

    @State private var showingEditor = false
    @State private var showingSettings = false
    @State private var milestone: MilestoneInfo?
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

    private var pendingGoals: [Goal] {
        dueGoals.filter { !$0.isCompleted(on: today, calendar: calendar) }
    }

    private var intendedPendingCount: Int {
        pendingGoals.filter { $0.hasIntention(on: today, calendar: calendar) }.count
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
                    milestone = MilestoneInfo(streak: 30, unit: .day, accent: .teal)
                default: break
                }
            }
        }
        .overlay {
            if let milestone {
                MilestoneOverlay(
                    streak: milestone.streak,
                    unit: milestone.unit,
                    tint: milestone.accent.color
                ) {
                    withAnimation { self.milestone = nil }
                }
                .transition(.opacity)
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                Text(today.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.Spacing.xs)

                intentionSummary

                LazyVStack(spacing: Theme.Spacing.m) {
                    ForEach(sortedDue) { goal in
                        let hasIntention = goal.hasIntention(on: today, calendar: calendar)
                        TodayGoalRow(
                            goal: goal,
                            isDone: goal.isCompleted(on: today, calendar: calendar),
                            hasIntention: hasIntention,
                            isCelebrating: recentlyCompletedGoalID == goal.id,
                            calendar: calendar,
                            onToggle: { toggle(goal) },
                            onIntend: { intentionGoal = goal },
                            onOpen: { deepLinkedGoal = goal }
                        )
                    }
                }
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, Theme.Spacing.xs)
            .padding(.bottom, Theme.Spacing.huge)
        }
        .scrollIndicators(.hidden)
        .animation(reduceMotion ? nil : WaiMotion.spatial, value: sortedDue.map(\.id))
    }

    private var intentionSummary: some View {
        let total = dueGoals.count
        let fraction = total == 0 ? 0 : Double(doneCount) / Double(total)
        let allDone = total > 0 && doneCount == total
        let pending = pendingGoals.count
        let intended = intendedPendingCount

        return HStack(spacing: Theme.Spacing.xl) {
            ZStack {
                ProgressRing(fraction: fraction, lineWidth: 11)
                    .frame(width: 92, height: 92)
                if allDone {
                    Image(systemName: "checkmark")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(.tint)
                } else {
                    VStack(spacing: 0) {
                        Text("\(doneCount)")
                            .font(.system(.title, design: .rounded).weight(.bold))
                            .monospacedDigit()
                            .minimumScaleFactor(0.5)
                        Text("of \(total)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Today's progress")
            .accessibilityValue(
                summaryAccessibilityValue(
                    total: total,
                    allDone: allDone,
                    pending: pending,
                    intended: intended
                )
            )

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(summaryTitle(total: total, allDone: allDone, pending: pending, intended: intended))
                    .font(.title3.weight(.semibold))
                Text(summaryMessage(total: total, allDone: allDone, pending: pending, intended: intended))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity)
        .card(cornerRadius: Theme.Radius.hero)
    }

    private func summaryTitle(total: Int, allDone: Bool, pending: Int, intended: Int) -> String {
        if allDone { return "All done for today" }
        if total == 0 { return "Nothing scheduled today" }
        if pending > 0 && intended == pending { return "Today is committed" }
        if intended > 0 { return "Intention in motion" }
        return "Choose today’s intention"
    }

    private func summaryMessage(total: Int, allDone: Bool, pending: Int, intended: Int) -> String {
        if allDone { return "Every goal checked off. Nice work." }
        if total == 0 { return "Enjoy the open space." }
        if pending > 0 && intended == pending {
            return "All \(pending) pending \(pending == 1 ? "goal is" : "goals are") committed."
        }
        if intended > 0 {
            return "\(intended) of \(pending) pending \(pending == 1 ? "goal" : "goals") committed."
        }
        return "\(pending) \(pending == 1 ? "goal is" : "goals are") waiting for approval."
    }

    private func summaryAccessibilityValue(
        total: Int,
        allDone: Bool,
        pending: Int,
        intended: Int
    ) -> String {
        if allDone { return "All \(total) goals complete" }
        if total == 0 { return "No goals scheduled today" }
        return "\(doneCount) of \(total) goals complete, \(intended) of \(pending) pending goals have intentions"
    }

    private func toggle(_ goal: Goal) {
        let before = AchievementSnapshot(goals: allGoals, calendar: calendar)
        let wasDone = goal.isCompleted(on: today, calendar: calendar)
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

        if !wasDone {
            showRowFeedback(for: goal.id)
        }

        if !wasDone, let newStreak, Milestone.reached(newStreak) {
            Haptics.success()
            withAnimation {
                milestone = MilestoneInfo(
                    streak: newStreak,
                    unit: goal.schedule.streakUnit,
                    accent: goal.accent
                )
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
