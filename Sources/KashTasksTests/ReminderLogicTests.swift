import Foundation
import KashTasksCore

func runReminderLogicTests(_ t: TestRunner) {
    let now      = Date(timeIntervalSince1970: 2_000)
    let duePast  = Date(timeIntervalSince1970: 1_500)

    do {
        let item = TodoItem(title: "ring", dueDate: duePast)
        let fired = ReminderLogic.tasksToFire([item], now: now, notified: [:])
        t.expectEqual(fired.map(\.id), [item.id], "fires when unseen")
    }

    do {
        let item = TodoItem(title: "again", dueDate: duePast)
        let fired = ReminderLogic.tasksToFire([item], now: now, notified: [item.id: duePast])
        t.expectTrue(fired.isEmpty, "no fire when notified for same dueDate")
    }

    do {
        let newDue = Date(timeIntervalSince1970: 1_800)
        let item = TodoItem(title: "snoozed", dueDate: newDue)
        let fired = ReminderLogic.tasksToFire([item], now: now, notified: [item.id: duePast])
        t.expectEqual(fired.map(\.id), [item.id], "re-fires when dueDate changed")
    }

    do {
        let future = TodoItem(title: "later", dueDate: Date(timeIntervalSince1970: 5_000))
        t.expectTrue(ReminderLogic.tasksToFire([future], now: now, notified: [:]).isEmpty, "no fire future")
        // A task that came due while the app was closed must now fire once on launch.
        let missed = TodoItem(title: "missed", dueDate: Date(timeIntervalSince1970: 500))
        t.expectEqual(ReminderLogic.tasksToFire([missed], now: now, notified: [:]).map(\.id),
                      [missed.id], "missed reminder fires on launch")
        let done = TodoItem(title: "done", dueDate: duePast, isDone: true)
        t.expectTrue(ReminderLogic.tasksToFire([done], now: now, notified: [:]).isEmpty, "no fire done")
        let undated = TodoItem(title: "no date")
        t.expectTrue(ReminderLogic.tasksToFire([undated], now: now, notified: [:]).isEmpty, "no fire undated")
    }

    // Labeling: a reminder whose due time predates this launch is a missed (overdue) fire.
    do {
        let appStart = Date(timeIntervalSince1970: 1_000)
        t.expectTrue(ReminderLogic.wasMissed(due: Date(timeIntervalSince1970: 500), appStart: appStart),
                     "due before launch is missed")
        t.expectFalse(ReminderLogic.wasMissed(due: Date(timeIntervalSince1970: 1_500), appStart: appStart),
                      "due at/after launch is on-time")
    }

    do {
        let item = TodoItem(title: "x", dueDate: Date(timeIntervalSince1970: 500))
        t.expectTrue(ReminderLogic.isOverdue(item, now: now), "overdue past+not done")
        let doneItem = TodoItem(title: "x", dueDate: Date(timeIntervalSince1970: 500), isDone: true)
        t.expectFalse(ReminderLogic.isOverdue(doneItem, now: now), "not overdue when done")
        let futureItem = TodoItem(title: "x", dueDate: Date(timeIntervalSince1970: 5_000))
        t.expectFalse(ReminderLogic.isOverdue(futureItem, now: now), "not overdue when future")
    }
}
