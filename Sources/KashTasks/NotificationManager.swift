import Foundation
import UserNotifications
import KashTasksCore

@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let categoryID = "TASK_DUE"

    private let store: TaskStore

    init(store: TaskStore) {
        self.store = store
        super.init()
    }

    /// Become the delegate and register the actionable category.
    func register() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let done = UNNotificationAction(identifier: "DONE", title: "Done", options: [])
        let snooze = UNNotificationAction(identifier: "SNOOZE", title: "Snooze 10 min", options: [])
        let tomorrow = UNNotificationAction(identifier: "TOMORROW", title: "Tomorrow 9 AM", options: [])
        let category = UNNotificationCategory(
            identifier: Self.categoryID,
            actions: [done, snooze, tomorrow],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    // Show banners even while the app is frontmost.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let taskId = response.notification.request.content.userInfo["taskId"] as? String
        let actionID = response.actionIdentifier
        Task { @MainActor in
            if let taskId { self.handle(actionID: actionID, taskId: taskId) }
        }
        completionHandler()
    }

    private func handle(actionID: String, taskId: String) {
        guard let id = UUID(uuidString: taskId) else { return }
        switch actionID {
        case "DONE":
            store.complete(id)
        case "SNOOZE":
            store.snooze(id, by: 600)
        case "TOMORROW":
            store.reschedule(id, to: Self.tomorrowMorning())
        default:
            break
        }
    }

    private static func tomorrowMorning() -> Date {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return cal.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }
}
