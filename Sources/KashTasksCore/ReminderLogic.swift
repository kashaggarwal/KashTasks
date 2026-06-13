import Foundation

public enum ReminderLogic {
    /// Tasks whose due time passed while the app was running and have not yet fired.
    public static func tasksToFire(
        _ items: [TodoItem],
        now: Date,
        appStart: Date,
        notified: Set<UUID>
    ) -> [TodoItem] {
        items.filter { item in
            guard let due = item.dueDate,
                  !item.isDone,
                  !notified.contains(item.id)
            else { return false }
            return due >= appStart && due <= now
        }
    }

    /// Past-due and not completed — used for the red "missed/overdue" indicator in the UI.
    public static func isOverdue(_ item: TodoItem, now: Date) -> Bool {
        guard let due = item.dueDate, !item.isDone else { return false }
        return due < now
    }
}
