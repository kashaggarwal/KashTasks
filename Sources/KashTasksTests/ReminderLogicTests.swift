import Foundation
import KashTasksCore

func runReminderLogicTests(_ t: TestRunner) {
    let appStart = Date(timeIntervalSince1970: 1_000)
    let now      = Date(timeIntervalSince1970: 2_000)
    let dueWhileRunning = Date(timeIntervalSince1970: 1_500)

    do {
        let item = TodoItem(title: "ring", dueDate: dueWhileRunning)
        let fired = ReminderLogic.tasksToFire([item], now: now, appStart: appStart, notified: [:])
        t.expectEqual(fired.map(\.id), [item.id], "fires when unseen")
    }

    do {
        let item = TodoItem(title: "again", dueDate: dueWhileRunning)
        let fired = ReminderLogic.tasksToFire([item], now: now, appStart: appStart,
                                              notified: [item.id: dueWhileRunning])
        t.expectTrue(fired.isEmpty, "no fire when notified for same dueDate")
    }

    do {
        let newDue = Date(timeIntervalSince1970: 1_800)
        let item = TodoItem(title: "snoozed", dueDate: newDue)
        let fired = ReminderLogic.tasksToFire([item], now: now, appStart: appStart,
                                              notified: [item.id: dueWhileRunning])
        t.expectEqual(fired.map(\.id), [item.id], "re-fires when dueDate changed")
    }

    do {
        let future = TodoItem(title: "later", dueDate: Date(timeIntervalSince1970: 5_000))
        t.expectTrue(ReminderLogic.tasksToFire([future], now: now, appStart: appStart, notified: [:]).isEmpty, "no fire future")
        let missed = TodoItem(title: "missed", dueDate: Date(timeIntervalSince1970: 500))
        t.expectTrue(ReminderLogic.tasksToFire([missed], now: now, appStart: appStart, notified: [:]).isEmpty, "no late-fire pre-launch")
        let done = TodoItem(title: "done", dueDate: dueWhileRunning, isDone: true)
        t.expectTrue(ReminderLogic.tasksToFire([done], now: now, appStart: appStart, notified: [:]).isEmpty, "no fire done")
        let undated = TodoItem(title: "no date")
        t.expectTrue(ReminderLogic.tasksToFire([undated], now: now, appStart: appStart, notified: [:]).isEmpty, "no fire undated")
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
