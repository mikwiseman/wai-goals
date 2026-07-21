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
    @State private var milestone: MilestoneInfo?
    @State private var completionEmotion: GoalEmotion?
    @State private var completionID = UUID()
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
                case "milestone": milestone = MilestoneInfo(streak: 30, unit: .day, accent: .teal, emotion: .growth)
                default: break
                }
            }
        }
        .overlay {
            ZStack {
                if let completionEmotion {
                    EmotionCompletionOverlay(emotion: completionEmotion)
                        .transition(.scale(scale: 0.88).combined(with: .opacity))
                }
                if let milestone {
                    MilestoneOverlay(streak: milestone.streak, unit: milestone.unit,
                                     tint: milestone.accent.color, emotion: milestone.emotion) {
                        if reduceMotion {
                            self.milestone = nil
                        } else {
                            withAnimation { self.milestone = nil }
                        }
                    }
                    .transition(.opacity)
                }
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
        let allDone = total > 0 && doneCount == total
        let pending = pendingGoals.count
        let intended = intendedPendingCount
        let emotion = featuredEmotion
        return VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            heroLead(emotion: emotion, total: total, allDone: allDone,
                     pending: pending, intended: intended)

            VStack(spacing: Theme.Spacing.xs) {
                ProgressView(value: fraction)
                    .tint(.accentColor)
                HStack {
                    Text(total == 0 ? "No steps today" : "\(doneCount) of \(total) steps complete")
                    Spacer()
                    Text(fraction.formatted(.percent.precision(.fractionLength(0))))
                        .monospacedDigit()
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity)
        .card(cornerRadius: Theme.Radius.hero)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Today's progress")
        .accessibilityValue(heroAccessibilityValue(total: total, allDone: allDone,
                                                   pending: pending, intended: intended))
    }

    @ViewBuilder
    private func heroLead(emotion: GoalEmotion?, total: Int, allDone: Bool,
                          pending: Int, intended: Int) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                heroArtwork(emotion: emotion)
                    .frame(maxWidth: .infinity)
                heroCopy(emotion: emotion, total: total, allDone: allDone,
                         pending: pending, intended: intended)
            }
        } else {
            HStack(spacing: Theme.Spacing.l) {
                heroArtwork(emotion: emotion)
                heroCopy(emotion: emotion, total: total, allDone: allDone,
                         pending: pending, intended: intended)
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func heroArtwork(emotion: GoalEmotion?) -> some View {
        if let emotion {
            EmotionArtwork(emotion: emotion, size: 92, animated: true, decorative: false)
        } else {
            GoalJourneyArtwork(size: 88)
        }
    }

    private func heroCopy(emotion: GoalEmotion?, total: Int, allDone: Bool,
                          pending: Int, intended: Int) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(heroTitle(total: total, allDone: allDone, pending: pending, intended: intended))
                .font(.title3.weight(.semibold))
            Text(heroMessage(total: total, allDone: allDone, pending: pending, intended: intended))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let emotion {
                Text("Toward \(emotion.displayName.lowercased()) · \(emotion.feeling)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
            }
        }
    }

    private func heroTitle(total: Int, allDone: Bool, pending: Int, intended: Int) -> String {
        if allDone { return "Every goal moved forward" }
        if total == 0 { return "An open step" }
        if pending > 0 && intended == pending { return "The path is set" }
        if intended > 0 { return "Momentum has started" }
        return "Move a goal forward"
    }

    private func heroMessage(total: Int, allDone: Bool, pending: Int, intended: Int) -> String {
        if allDone { return "You reached every point you set for today." }
        if total == 0 { return "No goal needs your attention today." }
        if pending > 0 && intended == pending {
            return "Every remaining goal has a clear intention."
        }
        if intended > 0 {
            return "\(intended) of \(pending) remaining \(pending == 1 ? "goal has" : "goals have") a clear intention."
        }
        return "\(pending) \(pending == 1 ? "goal is" : "goals are") ready for one deliberate step."
    }

    private func heroAccessibilityValue(total: Int, allDone: Bool, pending: Int, intended: Int) -> String {
        if allDone { return "All \(total) goals complete" }
        if total == 0 { return "No goals scheduled today" }
        return "\(doneCount) of \(total) goals complete, \(intended) of \(pending) pending goals have intentions"
    }

    private var featuredEmotion: GoalEmotion? {
        pendingGoals
            .first(where: { $0.hasIntention(on: today, calendar: calendar) && $0.emotion != nil })?
            .emotion
            ?? pendingGoals.compactMap(\.emotion).first
            ?? dueGoals.compactMap(\.emotion).first
    }

    private func toggle(_ goal: Goal) {
        let wasDone = goal.isCompleted(on: today, calendar: calendar)
        let newStreak = goal.toggleCompletion(on: today, context: context, calendar: calendar)
        if let newStreak, Milestone.reached(newStreak) {
            Haptics.success()
            let info = MilestoneInfo(streak: newStreak, unit: goal.schedule.streakUnit,
                                     accent: goal.accent, emotion: goal.emotion)
            if reduceMotion {
                milestone = info
            } else {
                withAnimation {
                    milestone = info
                }
            }
        } else if !wasDone, let emotion = goal.emotion {
            showCompletion(emotion)
        }
    }

    private func showCompletion(_ emotion: GoalEmotion) {
        let id = UUID()
        completionID = id
        if reduceMotion {
            completionEmotion = emotion
        } else {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                completionEmotion = emotion
            }
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.35))
            guard completionID == id else { return }
            if reduceMotion {
                completionEmotion = nil
            } else {
                withAnimation(.easeOut(duration: 0.22)) {
                    completionEmotion = nil
                }
            }
        }
    }
}
