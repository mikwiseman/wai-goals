import Foundation
import UserNotifications
import Observation

/// A Sendable snapshot of a goal's reminder, decoupled from SwiftData so it can
/// cross to the notification center without passing models across isolation.
struct ReminderSpec: Sendable, Identifiable {
    let id: UUID
    let title: String
    let type: ScheduleType
    let weekdays: [Int] // Calendar weekday ints, for .specificDays
    let hour: Int
    let minute: Int

    init?(goal: Goal, calendar: Calendar = .current) {
        guard goal.reminderEnabled, !goal.isArchived,
              !goal.title.trimmingCharacters(in: .whitespaces).isEmpty,
              let time = goal.reminderTime else { return nil }
        let comps = calendar.dateComponents([.hour, .minute], from: time)
        self.id = goal.id
        self.title = goal.title
        self.type = goal.schedule.type
        self.weekdays = goal.scheduledWeekdaysRaw.sorted()
        self.hour = comps.hour ?? 9
        self.minute = comps.minute ?? 0
    }

    func requests() -> [UNNotificationRequest] {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = "A quiet nudge to keep it going."
        content.sound = .default
        content.interruptionLevel = .active
        content.userInfo = ["goalID": id.uuidString]

        func request(id suffix: String, _ comps: DateComponents) -> UNNotificationRequest {
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            return UNNotificationRequest(identifier: "\(NotificationScheduler.prefix)\(id)-\(suffix)",
                                         content: content, trigger: trigger)
        }

        switch type {
        case .daily, .timesPerWeek:
            // Weekly goals can be done any day, so nudge daily at the chosen time.
            return [request(id: "daily", DateComponents(hour: hour, minute: minute))]
        case .specificDays:
            let days = weekdays.isEmpty ? Array(1...7) : weekdays
            return days.map { wd in
                request(id: "w\(wd)", DateComponents(hour: hour, minute: minute, weekday: wd))
            }
        }
    }
}

/// Owns notification authorization state and keeps scheduled reminders in sync
/// with the user's goals.
@MainActor
@Observable
final class NotificationScheduler {
    nonisolated static let prefix = "wg-reminder-"

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// Requests permission if not yet determined. Returns whether notifications
    /// are usable afterwards.
    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        await refreshAuthorizationStatus()
        switch authorizationStatus {
        case .notDetermined:
            let granted = (try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])) ?? false
            await refreshAuthorizationStatus()
            return granted
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    /// Rebuilds all of the app's pending reminders from the given goals.
    func reschedule(for goals: [Goal]) {
        let specs = goals.compactMap { ReminderSpec(goal: $0) }
        Task { await Self.apply(specs) }
    }

    private static func apply(_ specs: [ReminderSpec]) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        if !ours.isEmpty { center.removePendingNotificationRequests(withIdentifiers: ours) }
        for spec in specs {
            for request in spec.requests() {
                try? await center.add(request)
            }
        }
    }
}
