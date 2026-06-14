import Foundation

public enum ReminderLogic {
    /// Tasks whose due time passed while the app was running and that have not been
    /// notified for their *current* due date. `notified` maps a task id to the dueDate
    /// value it last fired for, so changing a due date (snooze / reschedule / recurrence)
    /// re-arms the reminder.
    public static func tasksToFire(
        _ items: [TodoItem],
        now: Date,
        appStart: Date,
        notified: [UUID: Date]
    ) -> [TodoItem] {
        items.filter { item in
            guard let due = item.dueDate, !item.isDone else { return false }
            guard due >= appStart && due <= now else { return false }
            return notified[item.id] != due
        }
    }

    /// Past-due and not completed — used for the red "missed/overdue" indicator in the UI.
    public static func isOverdue(_ item: TodoItem, now: Date) -> Bool {
        guard let due = item.dueDate, !item.isDone else { return false }
        return due < now
    }
}
