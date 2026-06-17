import Foundation
import UserNotifications

/// Schedules local "time to leave" notifications. Local notifications need no
/// push entitlement — only the user's authorization.
struct NotificationService {
    static let leaveReminderIdentifier = "com.example.LeaveNow.leaveReminder"

    private let center = UNUserNotificationCenter.current()

    /// Requests alert/sound authorization. Returns whether notifications are now
    /// permitted. In the background this never prompts; it reflects current status.
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    var isAuthorized: Bool {
        get async {
            let status = await center.notificationSettings().authorizationStatus
            switch status {
            case .authorized, .provisional, .ephemeral: return true
            default: return false
            }
        }
    }

    /// Schedules a single leave reminder, replacing any existing one. A past/now
    /// fire date delivers almost immediately.
    func scheduleLeaveReminder(at fireDate: Date, title: String, body: String) async {
        center.removePendingNotificationRequests(withIdentifiers: [Self.leaveReminderIdentifier])

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let interval = max(1, fireDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: Self.leaveReminderIdentifier, content: content, trigger: trigger)
        try? await center.add(request)
    }

    func cancelLeaveReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.leaveReminderIdentifier])
    }
}
