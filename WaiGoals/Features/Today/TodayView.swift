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

    /// The day the list shows. Defaults to today; the switcher can page back
    /// through history (never forward past today).
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    /// Which edge the incoming day slides in from — matches travel direction.
    @State private var pageEdge: Edge = .leading
    /// One-shot "every goal done" celebration; the accent echoes the goal whose
    /// completion finished the day.
    @State private var allDoneAccent: AccentToken?
    @State private var allDoneGeneration = 0

    private let calendar = Calendar.current
    private var today: Date { calendar.startOfDay(for: .now) }
    private var isToday: Bool { calendar.isDate(selectedDay, inSameDayAs: today) }

    private var dueGoals: [Goal] {
        allGoals
            .filter { !$0.isArchived && $0.schedule.isScheduled(on: selectedDay, calendar: calendar) }
    }

    private var sortedDue: [Goal] {
        dueGoals.sorted { a, b in
            let da = a.isCompleted(on: selectedDay, calendar: calendar)
            let db = b.isCompleted(on: selectedDay, calendar: calendar)
            if da != db { return !da } // pending first
            return a.sortIndex < b.sortIndex
        }
    }

    private var doneCount: Int {
        dueGoals.filter { $0.isCompleted(on: selectedDay, calendar: calendar) }.count
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
            .navigationTitle(dayTitle)
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
                IntentionApprovalSheet(goal: goal, date: selectedDay, calendar: calendar)
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
            if let allDoneAccent {
                AllDoneCelebrationView(
                    tint: allDoneAccent.color,
                    partnerTint: allDoneAccent.partnerColor
                )
                .transition(.opacity)
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
            VStack(spacing: Theme.Spacing.m) {
                daySwitcher
                    .entranceMotion(order: 0)

                Group {
                    if dueGoals.isEmpty {
                        emptyDay
                    } else {
                        LazyVStack(spacing: Theme.Spacing.s) {
                            ForEach(Array(sortedDue.enumerated()), id: \.element.id) { index, goal in
                                TodayGoalRow(
                                    goal: goal,
                                    day: selectedDay,
                                    isToday: isToday,
                                    isDone: goal.isCompleted(on: selectedDay, calendar: calendar),
                                    hasIntention: goal.hasIntention(on: selectedDay, calendar: calendar),
                                    isCelebrating: recentlyCompletedGoalID == goal.id,
                                    calendar: calendar,
                                    onToggle: { toggle(goal) },
                                    onIntend: { intentionGoal = goal },
                                    onOpen: { deepLinkedGoal = goal }
                                )
                                .entranceMotion(order: index + 1)
                            }
                        }
                        .animation(reduceMotion ? nil : WaiMotion.spatial, value: sortedDue.map(\.id))
                    }
                }
                .id(selectedDay)
                .transition(
                    reduceMotion
                        ? .opacity
                        : .push(from: pageEdge).combined(with: .opacity)
                )
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, Theme.Spacing.xs)
            .padding(.bottom, Theme.Spacing.huge)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Day switching

    private var dayTitle: String {
        if isToday { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
           calendar.isDate(selectedDay, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        return selectedDay.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    private var daySwitcher: some View {
        HStack(spacing: Theme.Spacing.xs) {
            dayStepButton(symbol: "chevron.left", label: "Previous day", enabled: true) {
                step(by: -1)
            }

            Button {
                guard !isToday else { return }
                returnToToday()
            } label: {
                Text(selectedDay.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isToday ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
                    .contentTransition(.opacity)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .buttonStyle(.waiPressable(scale: 0.97))
            .disabled(isToday)
            .animation(reduceMotion ? nil : WaiMotion.quick, value: isToday)
            .accessibilityLabel(selectedDay.formatted(.dateTime.weekday(.wide).month(.wide).day()))
            .accessibilityHint(isToday ? "" : "Returns to today")

            dayStepButton(symbol: "chevron.right", label: "Next day", enabled: !isToday) {
                step(by: 1)
            }

            Spacer(minLength: Theme.Spacing.s)

            if !dueGoals.isEmpty {
                dayProgress
            }
        }
    }

    private func dayStepButton(
        symbol: String, label: String, enabled: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.footnote.weight(.bold))
                .foregroundStyle(enabled ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
                .frame(width: 34, height: 34)
                .background(Circle().fill(.regularMaterial))
                .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
                .contentShape(Circle())
        }
        .buttonStyle(.waiPressable(scale: 0.85))
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    /// The banner's job, shrunk to a glance: a small ring beside the date.
    private var dayProgress: some View {
        let total = dueGoals.count
        let allDone = total > 0 && doneCount == total
        return HStack(spacing: Theme.Spacing.xs) {
            Text("\(doneCount)/\(total)")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : WaiMotion.quick, value: doneCount)
            ZStack {
                ProgressRing(fraction: Double(doneCount) / Double(total), lineWidth: 3.5)
                    .frame(width: 26, height: 26)
                if allDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.tint)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : WaiMotion.pop, value: allDone)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress")
        .accessibilityValue("\(doneCount) of \(total) goals complete")
    }

    private var emptyDay: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "moon.zzz")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(isToday ? "Nothing scheduled today" : "Nothing was scheduled this day")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xxl)
        .card()
    }

    private func step(by delta: Int) {
        guard let next = calendar.date(byAdding: .day, value: delta, to: selectedDay) else { return }
        let day = calendar.startOfDay(for: next)
        guard day <= today else { return }
        Haptics.tap()
        pageEdge = delta < 0 ? .leading : .trailing
        withAnimation(reduceMotion ? nil : WaiMotion.page) {
            selectedDay = day
        }
        recentlyCompletedGoalID = nil
    }

    private func returnToToday() {
        Haptics.tap()
        pageEdge = .trailing
        withAnimation(reduceMotion ? nil : WaiMotion.page) {
            selectedDay = today
        }
        recentlyCompletedGoalID = nil
    }

    // MARK: - Completion

    private func toggle(_ goal: Goal) {
        let before = AchievementSnapshot(goals: allGoals, calendar: calendar)
        let wasDone = goal.isCompleted(on: selectedDay, calendar: calendar)
        let newStreak = withAnimation(reduceMotion ? nil : WaiMotion.quick) {
            goal.toggleCompletion(on: selectedDay, context: context, calendar: calendar)
        }
        let achievements = wasDone ? [] : AchievementEngine.newlyUnlocked(
            before: before,
            after: before.addingCompletion(to: goal.id, on: selectedDay, calendar: calendar),
            excluding: Set(context.allAchievementUnlocks().compactMap(\.achievement)),
            asOf: selectedDay,
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
        } else if !wasDone, isToday, milestone == nil,
                  dueGoals.allSatisfy({ $0.isCompleted(on: selectedDay, calendar: calendar) }) {
            celebrateAllDone(finishing: goal)
        }
    }

    /// Fires the day-complete moment: confetti and a capsule that lets itself
    /// out. Skipped when a milestone overlay already owns the screen.
    private func celebrateAllDone(finishing goal: Goal) {
        Haptics.success()
        allDoneGeneration += 1
        let generation = allDoneGeneration
        withAnimation(reduceMotion ? nil : WaiMotion.pop) {
            allDoneAccent = goal.accent
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(2600))
            guard allDoneGeneration == generation else { return }
            withAnimation(.easeOut(duration: 0.4)) {
                allDoneAccent = nil
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
