import Foundation

public enum ReminderLogic {
    /// Tasks whose due time has arrived and that have not been notified for their
    /// *current* due date. `notified` maps a task id to the dueDate value it last
    /// fired for, so changing a due date (snooze / reschedule / recurrence) re-arms
    /// the reminder, and a persisted map keeps a missed reminder from re-firing on
    /// every launch.
    ///
    /// This intentionally fires for due times that passed while the app was *not*
    /// running ("missed" reminders) — caller persistence guarantees each fires once.
    public static func tasksToFire(
        _ items: [TodoItem],
        now: Date,
        notified: [UUID: Date]
    ) -> [TodoItem] {
        items.filter { item in
            guard let due = item.dueDate, !item.isDone else { return false }
            guard due <= now else { return false }
            return notified[item.id] != due
        }
    }

    /// True when a fired reminder's due time predates this launch — i.e. it came due
    /// while the app was closed. Used to label the notification as overdue.
    public static func wasMissed(due: Date, appStart: Date) -> Bool {
        due < appStart
    }

    /// Past-due and not completed — used for the red "missed/overdue" indicator in the UI.
    public static func isOverdue(_ item: TodoItem, now: Date) -> Bool {
        guard let due = item.dueDate, !item.isDone else { return false }
        return due < now
    }
}
