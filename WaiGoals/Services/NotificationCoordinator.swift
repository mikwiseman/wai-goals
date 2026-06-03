import Foundation
import UserNotifications
import Observation

/// Bridges incoming notifications to the UI: presents reminders while the app is
/// foregrounded, and routes a tapped reminder to its goal.
@MainActor
@Observable
final class NotificationCoordinator: NSObject, UNUserNotificationCenterDelegate {
    /// Set when the user taps a reminder; views observe this to navigate.
    var routeGoalID: UUID?

    func register() {
        UNUserNotificationCenter.current().delegate = self
    }

    // Show reminders as a banner + sound even when the app is open.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    // A reminder was tapped — surface the goal it belongs to.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        guard let raw = info["goalID"] as? String, let id = UUID(uuidString: raw) else { return }
        await MainActor.run { self.routeGoalID = id }
    }
}
