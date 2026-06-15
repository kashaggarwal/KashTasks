import Foundation
import Combine
import UserNotifications
import KashTasksCore

@MainActor
final class ReminderScheduler: ObservableObject {
    private let store: TaskStore
    private let appStart: Date
    private let notified: NotifiedStore
    private var timer: Timer?
    private var cancellable: AnyCancellable?

    init(store: TaskStore, appStart: Date = Date(), notified: NotifiedStore? = nil) {
        self.store = store
        self.appStart = appStart
        self.notified = notified ?? NotifiedStore(fileURL: AppPaths.notifiedFile)
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
        notified.prune(keeping: Set(store.items.map(\.id)))

        let due = ReminderLogic.tasksToFire(store.items, now: Date(), notified: notified.entries)
        for item in due {
            guard let dueDate = item.dueDate else { continue }
            notified.markNotified(item.id, due: dueDate)
            post(item, missed: ReminderLogic.wasMissed(due: dueDate, appStart: appStart))
        }
    }

    private func post(_ item: TodoItem, missed: Bool) {
        let content = UNMutableNotificationContent()
        content.title = item.title
        if missed { content.subtitle = "Overdue" }
        content.body = item.notes.isEmpty ? (missed ? "This was due earlier" : "Task due now") : item.notes
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
