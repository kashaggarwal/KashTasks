import Foundation
import Combine
import UserNotifications
import KashTasksCore

@MainActor
final class ReminderScheduler: ObservableObject {
    private let store: TaskStore
    private let appStart: Date
    private var notified: [UUID: Date] = [:]
    private var timer: Timer?
    private var cancellable: AnyCancellable?

    init(store: TaskStore, appStart: Date = Date()) {
        self.store = store
        self.appStart = appStart
    }

    func start() {
        guard timer == nil else { return }

        cancellable = store.$items
            .sink { [weak self] _ in
                Task { @MainActor in self?.evaluate() }
            }

        let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.evaluate() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        evaluate()
    }

    private func evaluate() {
        let due = ReminderLogic.tasksToFire(
            store.items, now: Date(), appStart: appStart, notified: notified
        )
        for item in due {
            notified[item.id] = item.dueDate
            post(item)
        }
    }

    private func post(_ item: TodoItem) {
        let content = UNMutableNotificationContent()
        content.title = item.title
        content.body = item.notes.isEmpty ? "Task due now" : item.notes
        content.sound = .default
        content.categoryIdentifier = NotificationManager.categoryID
        content.userInfo = ["taskId": item.id.uuidString]

        let request = UNNotificationRequest(
            identifier: item.id.uuidString,
            content: content,
            trigger: nil
        )
        let title = item.title
        Task {
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                NSLog("KashTasks: failed to deliver notification for \(title): \(error)")
            }
        }
    }
}
