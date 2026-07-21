import SwiftUI
import SwiftData

struct GoalsListView: View {
    @Environment(\.modelContext) private var context
    @Environment(NotificationScheduler.self) private var scheduler
    @Query(sort: \Goal.sortIndex) private var goals: [Goal]
    @State private var showingEditor = false
    @State private var goalToDelete: Goal?

    private let calendar = Calendar.current
    private var active: [Goal] { goals.filter { !$0.isArchived } }
    private var archived: [Goal] { goals.filter { $0.isArchived } }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                if goals.isEmpty {
                    EmptyStateView(
                        symbol: "square.stack.3d.up",
                        emotion: .courage,
                        title: "No goals yet",
                        message: "Add goals you want to keep up with — daily, on certain days, or a few times a week.",
                        actionTitle: "Add a goal",
                        action: { showingEditor = true }
                    )
                } else {
                    list
                }
            }
            .navigationTitle("Goals")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingEditor = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add goal")
                }
                ToolbarItem(placement: .topBarLeading) {
                    if active.count > 1 { EditButton() }
                }
            }
            .sheet(isPresented: $showingEditor) { GoalEditorView() }
            .confirmationDialog(
                "Delete this goal?",
                isPresented: Binding(get: { goalToDelete != nil }, set: { if !$0 { goalToDelete = nil } }),
                titleVisibility: .visible,
                presenting: goalToDelete
            ) { goal in
                Button("Delete “\(goal.title)”", role: .destructive) { delete(goal) }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("This permanently removes the goal and its streak history.")
            }
        }
    }

    private var list: some View {
        List {
            Section {
                ForEach(active) { goal in
                    NavigationLink {
                        GoalDetailView(goal: goal)
                    } label: {
                        GoalListRow(goal: goal, calendar: calendar)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { goalToDelete = goal } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button { setArchived(goal, true) } label: {
                            Label("Archive", systemImage: "archivebox")
                        }
                        .tint(.gray)
                    }
                    .listRowInsets(.init(top: Theme.Spacing.s, leading: Theme.Spacing.l,
                                        bottom: Theme.Spacing.s, trailing: Theme.Spacing.l))
                }
                .onMove(perform: move)
            } header: {
                HStack {
                    Text("Active goals")
                    Spacer()
                    Text("\(active.count)")
                        .monospacedDigit()
                }
            }

            if !archived.isEmpty {
                Section {
                    ForEach(archived) { goal in
                        GoalListRow(goal: goal, calendar: calendar)
                            .foregroundStyle(.secondary)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { delete(goal) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button { setArchived(goal, false) } label: {
                                    Label("Restore", systemImage: "arrow.uturn.backward")
                                }
                                .tint(.blue)
                            }
                            .listRowInsets(.init(top: Theme.Spacing.s, leading: Theme.Spacing.l,
                                                bottom: Theme.Spacing.s, trailing: Theme.Spacing.l))
                    }
                } header: {
                    HStack {
                        Text("Archived")
                        Spacer()
                        Text("\(archived.count)")
                            .monospacedDigit()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(Theme.Spacing.xl)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Mutations

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = active
        reordered.move(fromOffsets: source, toOffset: destination)
        // Reindex active first, then archived, so sortIndex stays globally unique
        // (archived goals keeping stale indices could otherwise tie with active
        // ones and reorder nondeterministically).
        var index = 0
        for goal in reordered { goal.sortIndex = index; index += 1 }
        for goal in archived { goal.sortIndex = index; index += 1 }
        context.saveOrLog()
        syncReminders()
    }

    private func delete(_ goal: Goal) {
        context.delete(goal)
        context.saveOrLog()
        syncReminders()
    }

    private func setArchived(_ goal: Goal, _ archived: Bool) {
        goal.isArchived = archived
        context.saveOrLog()
        syncReminders()
    }

    private func syncReminders() {
        scheduler.reschedule(for: context.allGoals())
    }
}

struct GoalListRow: View {
    let goal: Goal
    var calendar: Calendar = .current
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let tint = goal.accent.color
        let streak = goal.streak(asOf: .now, calendar: calendar)
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    HStack(alignment: .top, spacing: Theme.Spacing.m) {
                        artwork(size: 52, tint: tint)
                        Text(goal.title)
                            .font(.body.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(metadata)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if streak.current > 0 {
                        StreakBadge(count: streak.current, unit: streak.unit,
                                    tint: tint, showsLabel: true)
                    }
                }
            } else {
                HStack(spacing: Theme.Spacing.m) {
                    artwork(size: 48, tint: tint)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(goal.title)
                            .font(.body.weight(.semibold))
                            .lineLimit(1)
                        Text(metadata)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    Spacer(minLength: Theme.Spacing.s)
                    if streak.current > 0 {
                        StreakBadge(count: streak.current, unit: streak.unit, tint: tint)
                    }
                }
            }
        }
        .padding(.vertical, Theme.Spacing.xxs)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func artwork(size: CGFloat, tint: Color) -> some View {
        if let emotion = goal.emotion {
            EmotionArtwork(emotion: emotion, size: size, decorative: false)
        } else {
            GoalIcon(symbol: goal.symbol, tint: tint, size: size)
        }
    }

    private var metadata: String {
        var parts = [goal.schedule.summary(calendar: calendar)]
        if let emotion = goal.emotion { parts.append(emotion.displayName) }
        if goal.reminderEnabled, let time = goal.reminderTime {
            parts.append(time.formatted(date: .omitted, time: .shortened))
        }
        return parts.joined(separator: " · ")
    }
}
