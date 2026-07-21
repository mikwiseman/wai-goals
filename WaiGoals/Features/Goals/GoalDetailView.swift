import SwiftUI
import SwiftData

struct GoalDetailView: View {
    @Bindable var goal: Goal

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(NotificationScheduler.self) private var scheduler
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showingEditor = false
    @State private var completionMoment: CompletionJourneyMoment?
    @State private var showingDeleteConfirm = false
    @State private var showingIntention = false

    private let calendar = Calendar.current
    private var today: Date { calendar.startOfDay(for: .now) }

    var body: some View {
        let tint = goal.accent.color
        let streak = goal.streak(asOf: today, calendar: calendar)
        let completed = goal.completedDays(calendar: calendar)

        ZStack {
            AppBackground(tint: tint)
            ScrollView {
                VStack(spacing: Theme.Spacing.xxl) {
                    header(tint: tint)
                        .entranceMotion(order: 0)
                    if goal.schedule.isScheduled(on: today, calendar: calendar) {
                        markTodayButton(tint: tint)
                            .entranceMotion(order: 1)
                        intentionCard(tint: tint)
                            .entranceMotion(order: 2)
                    }
                    momentumCard(streak: streak, completed: completed, tint: tint)
                        .entranceMotion(order: 3)
                    historyCard(completed: completed, tint: tint)
                        .entranceMotion(order: 4)
                    overviewCard(completed: completed, tint: tint)
                        .entranceMotion(order: 5)
                }
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, Theme.Spacing.s)
                .padding(.bottom, Theme.Spacing.huge)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(goal.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showingEditor = true } label: { Label("Edit", systemImage: "pencil") }
                    Button { setArchived(!goal.isArchived) } label: {
                        Label(goal.isArchived ? "Restore" : "Archive",
                              systemImage: goal.isArchived ? "arrow.uturn.backward" : "archivebox")
                    }
                    Divider()
                    Button(role: .destructive) { showingDeleteConfirm = true } label: { Label("Delete", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .toolbar(completionMoment == nil ? .visible : .hidden, for: .tabBar)
        .confirmationDialog("Delete this goal?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete “\(goal.title)”", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes the goal and its streak history.")
        }
        .sheet(isPresented: $showingEditor) {
            GoalEditorView(goal: goal)
        }
        .sheet(isPresented: $showingIntention) {
            IntentionApprovalSheet(goal: goal, date: today, calendar: calendar)
        }
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

    // MARK: - Sections

    private func header(tint: Color) -> some View {
        let weekly = StatsCalculator.currentWeekProgress(
            schedule: goal.schedule,
            completedDays: goal.completedDays(calendar: calendar),
            asOf: today,
            calendar: calendar
        )
        let progress = weekly.total == 0 ? 0 : Double(weekly.done) / Double(weekly.total)
        return EscherWorldStage(
            emotion: goal.emotion,
            title: goal.title,
            eyebrow: "Inside this world",
            message: goal.emotion?.worldPrompt ?? goal.schedule.summary(calendar: calendar),
            progress: progress,
            isComplete: goal.isCompleted(on: today, calendar: calendar),
            height: 426
        )
        .overlay(alignment: .topLeading) {
            GoalIcon(symbol: goal.symbol, tint: tint, size: 42)
                .padding(Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.xxl)
        }
    }

    private func markTodayButton(tint: Color) -> some View {
        let isDone = goal.isCompleted(on: today, calendar: calendar)
        return Button {
            toggleToday()
        } label: {
            Group {
                if reduceMotion {
                    markTodayLabel(isDone: isDone)
                } else {
                    markTodayLabel(isDone: isDone)
                        .symbolEffect(.bounce, value: isDone)
                }
            }
        }
        .waiGlassButton(prominent: true)
        .tint(tint)
        .controlSize(.large)
        .sensoryFeedback(trigger: isDone) { _, now in now ? .success : .impact(weight: .light) }
    }

    private func markTodayLabel(isDone: Bool) -> some View {
        Label(isDone ? "Done today" : "Mark done today",
              systemImage: isDone ? "checkmark.circle.fill" : "circle")
            .font(.headline)
            .frame(maxWidth: .infinity)
    }

    private func intentionCard(tint: Color) -> some View {
        let intention = goal.intention(on: today, calendar: calendar)
        return Button {
            showingIntention = true
        } label: {
            HStack(alignment: .top, spacing: Theme.Spacing.m) {
                Image(systemName: intention == nil ? "target" : "checkmark.seal.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(intention == nil ? "Approve intention" : "Intention approved")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(Intention.pledgeText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(Theme.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .card()
        .accessibilityLabel(intention == nil ? "Approve intention for \(goal.title)" :
                            "Review intention for \(goal.title)")
    }

    private func momentumCard(streak: StreakResult, completed: Set<Date>, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            SectionHeading(title: "Momentum", detail: goal.schedule.summary(calendar: calendar))

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: Theme.Spacing.l) {
                        statBlock(value: "\(streak.current)",
                                  label: "Current \(streak.unit.label(for: streak.current))",
                                  symbol: "flame.fill", tint: tint, prominent: true)
                        Divider()
                        statBlock(value: "\(streak.best)",
                                  label: "Best \(streak.unit.label(for: streak.best))",
                                  symbol: "trophy.fill", tint: tint, prominent: false)
                    }
                } else {
                    HStack(spacing: 0) {
                        statBlock(value: "\(streak.current)",
                                  label: "Current \(streak.unit.label(for: streak.current))",
                                  symbol: "flame.fill", tint: tint, prominent: true)
                        Divider().frame(height: 52)
                        statBlock(value: "\(streak.best)",
                                  label: "Best \(streak.unit.label(for: streak.best))",
                                  symbol: "trophy.fill", tint: tint, prominent: false)
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                Text("This week")
                    .font(.subheadline.weight(.semibold))
                WeekStrip(schedule: goal.schedule, completedDays: completed,
                          tint: tint, calendar: calendar)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity)
        .card()
    }

    private func statBlock(value: String, label: String, symbol: String, tint: Color, prominent: Bool) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.headline)
                    .foregroundStyle(prominent ? AnyShapeStyle(tint) : AnyShapeStyle(Color.secondary))
                Text(value)
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func historyCard(completed: Set<Date>, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            SectionHeading(title: "The path behind you", detail: "18 weeks")
            HeatmapView(schedule: goal.schedule, completedDays: completed, tint: tint, calendar: calendar)

            Divider()

            Text("Weekly rhythm")
                .font(.subheadline.weight(.semibold))
            TrendChartView(
                points: StatsCalculator.weeklyTrend(schedule: goal.schedule, completedDays: completed,
                                                    weeks: 12, asOf: today, calendar: calendar),
                tint: tint
            )
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func overviewCard(completed: Set<Date>, tint: Color) -> some View {
        // Clamp the window to the goal's creation date so a brand-new goal isn't
        // shown an artificially low rate for days before it existed.
        let windowStart = calendar.date(byAdding: .day, value: -29, to: today) ?? today
        let from = max(windowStart, calendar.startOfDay(for: goal.createdAt))
        let rate = StatsCalculator.completionRate(schedule: goal.schedule, completedDays: completed,
                                                  from: from, to: today, calendar: calendar)
        return VStack(spacing: Theme.Spacing.l) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: Theme.Spacing.l) {
                        statBlock(value: rate.formatted(.percent.precision(.fractionLength(0))),
                                  label: "30-day rate", symbol: "chart.line.uptrend.xyaxis",
                                  tint: tint, prominent: false)
                        Divider()
                        statBlock(value: "\(goal.completions.count)",
                                  label: "Total done", symbol: "checkmark.seal.fill",
                                  tint: tint, prominent: false)
                    }
                } else {
                    HStack(spacing: 0) {
                        statBlock(value: rate.formatted(.percent.precision(.fractionLength(0))),
                                  label: "30-day rate", symbol: "chart.line.uptrend.xyaxis",
                                  tint: tint, prominent: false)
                        Divider().frame(height: 52)
                        statBlock(value: "\(goal.completions.count)",
                                  label: "Total done", symbol: "checkmark.seal.fill",
                                  tint: tint, prominent: false)
                    }
                }
            }

            if goal.reminderEnabled, let time = goal.reminderTime {
                Divider()
                HStack(spacing: Theme.Spacing.m) {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(tint)
                    Text("Reminder")
                    Spacer()
                    Text(time.formatted(date: .omitted, time: .shortened))
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity)
        .card()
    }

    // MARK: - Actions

    private func toggleToday() {
        let wasDone = goal.isCompleted(on: today, calendar: calendar)
        let newStreak = goal.toggleCompletion(on: today, context: context, calendar: calendar)
        if let newStreak, Milestone.reached(newStreak) {
            Haptics.success()
            if let emotion = goal.emotion {
                showCompletion(
                    emotion,
                    milestone: "\(newStreak) \(goal.schedule.streakUnit.label(for: newStreak)) in a row"
                )
            }
        } else if !wasDone, let emotion = goal.emotion {
            showCompletion(emotion)
        }
    }

    private func showCompletion(_ emotion: GoalEmotion, milestone: String? = nil) {
        let week = StatsCalculator.currentWeekProgress(
            schedule: goal.schedule,
            completedDays: goal.completedDays(calendar: calendar),
            asOf: today,
            calendar: calendar
        )
        let moment = CompletionJourneyMoment(
            goalTitle: goal.title,
            emotion: emotion,
            progressLabel: "\(week.done) of \(week.total) this week",
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

    private func setArchived(_ archived: Bool) {
        goal.isArchived = archived
        context.saveOrLog()
        syncReminders()
    }

    private func delete() {
        // Dismiss first so the view stops reading `goal` before it's tombstoned.
        dismiss()
        context.delete(goal)
        context.saveOrLog()
        syncReminders()
    }

    private func syncReminders() {
        scheduler.reschedule(for: context.allGoals())
    }
}
