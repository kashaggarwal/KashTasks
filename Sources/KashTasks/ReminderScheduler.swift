import Foundation
import Combine
import UserNotifications
import KashTasksCore

@MainActor
final class ReminderScheduler: ObservableObject {
    private let store: TaskStore
    private let appStart: Date
    private var notified: Set<UUID> = []
    private var timer: Timer?
    private var cancellable: AnyCancellable?

    init(store: TaskStore, appStart: Date = Date()) {
        self.store = store
        self.appStart = appStart
    }

    func start() {
        // Idempotent: `start()` is called from the menu popover's onAppear, which
        // fires on every open. Without this guard each open would leak another timer.
        guard timer == nil else { return }

        // Re-evaluate whenever the store changes...
        cancellable = store.$items
            .sink { [weak self] _ in
                Task { @MainActor in self?.evaluate() }
            }

        // ...and on a steady tick so due times are caught while idle.
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
            notified.insert(item.id)
            post(item)
        }
    }

    private func post(_ item: TodoItem) {
        let content = UNMutableNotificationContent()
        content.title = item.title
        content.body = item.notes.isEmpty ? "Task due now" : item.notes
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: item.id.uuidString,
            content: content,
            trigger: nil // deliver immediately
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                NSLog("KashTasks: failed to deliver notification for \(item.title): \(error)")
            }
        }
    }
}
