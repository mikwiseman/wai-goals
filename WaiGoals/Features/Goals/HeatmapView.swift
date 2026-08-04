import SwiftUI

/// A GitHub-style contribution grid: one column per week (oldest → newest), one
/// cell per day, colored by completion state.
struct HeatmapView: View {
    let schedule: Schedule
    let completedDays: Set<Date>
    var tint: Color = .accentColor
    var weeks: Int = 18
    var calendar: Calendar = .current
    /// When set, today and past cells become tappable so the user can mark or
    /// unmark completions retroactively. Future cells stay inert.
    var onToggleDay: ((Date) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let cellSize: CGFloat = 13
    private let spacing: CGFloat = 4

    var body: some View {
        let today = calendar.startOfDay(for: .now)
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let weekStarts: [Date] = (0..<weeks).reversed().compactMap {
            calendar.date(byAdding: .weekOfYear, value: -$0, to: currentWeekStart)
        }
        let rangeStart = weekStarts.first ?? currentWeekStart
        let completedCount = completedDays.filter { $0 >= rangeStart && $0 <= today }.count

        return ScrollView(.horizontal) {
            HStack(spacing: spacing) {
                ForEach(weekStarts, id: \.self) { weekStart in
                    VStack(spacing: spacing) {
                        ForEach(0..<7, id: \.self) { row in
                            let day = calendar.date(byAdding: .day, value: row, to: weekStart) ?? weekStart
                            let state = StatsCalculator.dayState(
                                schedule: schedule, completedDays: completedDays,
                                on: day, asOf: today, calendar: calendar
                            )
                            if let onToggleDay, day <= today {
                                Button { onToggleDay(day) } label: {
                                    dayCell(day: day, state: state, today: today)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.waiPressable(scale: 0.7))
                                .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                                .accessibilityValue(state.accessibilityDescription)
                                .accessibilityHint(state == .completed
                                                   ? "Double-tap to unmark this day"
                                                   : "Double-tap to mark this day done")
                            } else {
                                dayCell(day: day, state: state, today: today)
                            }
                        }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .defaultScrollAnchor(.trailing)
        .accessibilityElement(children: onToggleDay == nil ? .ignore : .contain)
        .accessibilityLabel("Completion history, last \(weeks) weeks")
        .accessibilityValue("\(completedCount) days completed")
    }

    private func dayCell(day: Date, state: DayState, today: Date) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(color(for: state))
            .frame(width: cellSize, height: cellSize)
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(calendar.isDate(day, inSameDayAs: today) ? tint : .clear,
                                  lineWidth: 1.5)
            )
            .animation(reduceMotion ? nil : WaiMotion.quick, value: state)
    }

    private func color(for state: DayState) -> Color {
        switch state {
        case .completed: tint
        case .missed: Color.secondary.opacity(0.22)
        case .todayPending: tint.opacity(0.22)
        case .notScheduled: Color.secondary.opacity(0.08)
        case .future: Color.secondary.opacity(0.05)
        }
    }
}
