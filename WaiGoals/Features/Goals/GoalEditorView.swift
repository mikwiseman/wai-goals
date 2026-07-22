import SwiftUI
import SwiftData

struct GoalEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(NotificationScheduler.self) private var scheduler
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Goal.sortIndex) private var allGoals: [Goal]

    private let editingGoal: Goal?

    @State private var title: String
    @State private var symbol: String
    @State private var accent: AccentToken
    @State private var emotion: GoalEmotion?
    @State private var scheduleType: ScheduleType
    @State private var weekdays: Set<Weekday>
    @State private var timesPerWeek: Int
    @State private var reminderEnabled: Bool
    @State private var reminderTime: Date
    @State private var showingSymbolPicker = false

    init(goal: Goal? = nil) {
        self.editingGoal = goal
        let schedule = goal?.schedule ?? .daily
        _title = State(initialValue: goal?.title ?? "")
        _symbol = State(initialValue: goal?.symbol ?? "target")
        _accent = State(initialValue: goal?.accent ?? .default)
        _emotion = State(initialValue: goal?.emotion)
        _scheduleType = State(initialValue: schedule.type)
        _weekdays = State(initialValue: schedule.weekdays.isEmpty ? [.monday, .wednesday, .friday] : schedule.weekdays)
        _timesPerWeek = State(initialValue: schedule.type == .timesPerWeek ? schedule.timesPerWeek : 3)
        _reminderEnabled = State(initialValue: goal?.reminderEnabled ?? false)
        _reminderTime = State(initialValue: goal?.reminderTime ?? GoalEditorView.defaultReminderTime)
    }

    private static var defaultReminderTime: Date {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now) ?? .now
    }

    var body: some View {
        NavigationStack {
            Form {
                previewSection
                emotionSection
                detailsSection
                scheduleSection
                reminderSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(AppBackground(tint: accent.color))
            .navigationTitle(editingGoal == nil ? "New Goal" : "Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave).fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingSymbolPicker) {
                SymbolPicker(selection: $symbol, tint: accent.color)
            }
        }
    }

    // MARK: - Sections

    private var previewSection: some View {
        Section {
            EscherWorldStage(
                emotion: emotion,
                title: title.isEmpty ? "Name the next stair" : title,
                eyebrow: editingGoal == nil ? "New world" : "Refine this world",
                message: emotion?.worldPrompt ?? "Choose how you want this goal to change you.",
                progress: 0,
                height: 344
            )
            .id(emotion)
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96)))
            .overlay(alignment: .topLeading) {
                GoalIcon(symbol: symbol, tint: accent.color, size: 40)
                    .padding(Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.xxl)
            }
            .listRowInsets(.init(top: Theme.Spacing.s, leading: 0,
                                bottom: Theme.Spacing.s, trailing: 0))
            .listRowBackground(Color.clear)
        }
    }

    private var emotionSection: some View {
        Section {
            EmotionPicker(selection: $emotion, tint: accent.color)
                .padding(.vertical, Theme.Spacing.xs)
        } header: {
            Text("Choose the world")
        } footer: {
            Text("How do you want to feel as this goal becomes part of you?")
        }
    }

    private var detailsSection: some View {
        Section("Goal") {
            TextField("Goal name", text: $title)
                .font(.body)

            Button { showingSymbolPicker = true } label: {
                HStack {
                    Text("Icon").foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: symbol).foregroundStyle(accent.color)
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("Color").foregroundStyle(.primary)
                colorPicker
            }
        }
    }

    private var colorPicker: some View {
        HStack(spacing: 0) {
            ForEach(AccentToken.allCases) { token in
                Button { accent = token } label: {
                    Circle()
                        .fill(token.color)
                        .frame(width: 30, height: 30)
                        .overlay {
                            if accent == token {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(token.contrastingForeground)
                            }
                        }
                        .scaleEffect(accent == token ? 1.12 : 1)
                        .frame(maxWidth: .infinity, minHeight: 44) // 44pt hit target
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(token.displayName)
                .accessibilityAddTraits(accent == token ? .isSelected : [])
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: accent)
    }

    private var scheduleSection: some View {
        Section("Schedule") {
            Picker("Repeat", selection: $scheduleType) {
                Text("Daily").tag(ScheduleType.daily)
                Text("Days").tag(ScheduleType.specificDays)
                Text("Weekly").tag(ScheduleType.timesPerWeek)
            }
            .pickerStyle(.segmented)

            switch scheduleType {
            case .daily:
                Text("Every day").font(.subheadline).foregroundStyle(.secondary)
            case .specificDays:
                weekdayPicker
            case .timesPerWeek:
                Stepper(value: $timesPerWeek, in: 1...7) {
                    Text("\(timesPerWeek)× per week")
                }
            }
        }
    }

    private var weekdayPicker: some View {
        HStack(spacing: 0) {
            ForEach(Weekday.ordered(firstWeekday: Calendar.current.firstWeekday)) { weekday in
                let isOn = weekdays.contains(weekday)
                Button {
                    if isOn { weekdays.remove(weekday) } else { weekdays.insert(weekday) }
                } label: {
                    Text(weekday.veryShortSymbol())
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(isOn ? accent.color : Color(.secondarySystemBackground)))
                        .foregroundStyle(isOn ? accent.contrastingForeground : .primary)
                        .frame(maxWidth: .infinity, minHeight: 44) // 44pt hit target
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(weekday.shortSymbol())
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }

    private var reminderSection: some View {
        Section("Reminder") {
            Toggle("Remind me", isOn: $reminderEnabled.animation(reduceMotion ? nil : .default))
            if reminderEnabled {
                DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                if scheduler.authorizationStatus == .denied {
                    Label("Notifications are off. Enable them in Settings to get reminders.",
                          systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Logic

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        emotion != nil &&
        (scheduleType != .specificDays || !weekdays.isEmpty)
    }

    private var schedule: Schedule {
        switch scheduleType {
        case .daily: Schedule(type: .daily)
        case .specificDays: Schedule(type: .specificDays, weekdays: weekdays)
        case .timesPerWeek: Schedule(type: .timesPerWeek, timesPerWeek: timesPerWeek)
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let time = reminderEnabled ? reminderTime : nil

        if let goal = editingGoal {
            goal.title = trimmed
            goal.symbol = symbol
            goal.colorToken = accent.rawValue
            goal.emotion = emotion
            goal.schedule = schedule
            goal.reminderEnabled = reminderEnabled
            goal.reminderTime = time
        } else {
            let nextIndex = (allGoals.map(\.sortIndex).max() ?? -1) + 1
            let goal = Goal(title: trimmed, symbol: symbol, color: accent, emotion: emotion, schedule: schedule,
                            reminderEnabled: reminderEnabled, reminderTime: time, sortIndex: nextIndex)
            context.insert(goal)
        }
        context.saveOrLog()

        Task { @MainActor in
            if reminderEnabled { await scheduler.requestAuthorizationIfNeeded() }
            scheduler.reschedule(for: context.allGoals())
        }
        dismiss()
    }
}
