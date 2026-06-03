import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(NotificationCoordinator.self) private var coordinator
    @Query(sort: \Goal.sortIndex) private var allGoals: [Goal]

    @State private var showingEditor = false
    @State private var showingSettings = false
    @State private var milestone: MilestoneInfo?
    @State private var deepLinkedGoal: Goal?
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
                        symbol: "sparkles",
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
                case "milestone": milestone = MilestoneInfo(streak: 30, unit: .day, accent: .teal)
                default: break
                }
            }
        }
        .overlay {
            if let milestone {
                MilestoneOverlay(streak: milestone.streak, unit: milestone.unit,
                                 tint: milestone.accent.color) {
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

                hero

                LazyVStack(spacing: Theme.Spacing.m) {
                    ForEach(sortedDue) { goal in
                        TodayGoalRow(
                            goal: goal,
                            isDone: goal.isCompleted(on: today, calendar: calendar),
                            calendar: calendar,
                            onToggle: { toggle(goal) },
                            onOpen: { deepLinkedGoal = goal }
                        )
                    }
                }
            }
            .padding(Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .scrollIndicators(.hidden)
    }

    private var hero: some View {
        let total = dueGoals.count
        let fraction = total == 0 ? 0 : Double(doneCount) / Double(total)
        let allDone = total > 0 && doneCount == total
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
            .accessibilityValue(allDone ? "All \(total) goals complete" : "\(doneCount) of \(total) goals complete")
            VStack(alignment: .leading, spacing: 4) {
                Text(allDone ? "All done for today" : "Keep it going")
                    .font(.title3.weight(.semibold))
                Text(allDone
                     ? "Every goal checked off. Nice work."
                     : (total == 0 ? "Nothing scheduled today — enjoy it."
                        : "\(total - doneCount) left to check off today."))
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

    private func toggle(_ goal: Goal) {
        let newStreak = goal.toggleCompletion(on: today, context: context, calendar: calendar)
        if let newStreak, Milestone.reached(newStreak) {
            Haptics.success()
            withAnimation {
                milestone = MilestoneInfo(streak: newStreak, unit: goal.schedule.streakUnit, accent: goal.accent)
            }
        }
    }
}
