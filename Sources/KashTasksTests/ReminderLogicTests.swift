import Foundation
import KashTasksCore

func runReminderLogicTests(_ t: TestRunner) {
    let appStart = Date(timeIntervalSince1970: 1_000)
    let now      = Date(timeIntervalSince1970: 2_000)

    // fires when due passed while running
    do {
        let item = TodoItem(title: "ring", dueDate: Date(timeIntervalSince1970: 1_500))
        let fired = ReminderLogic.tasksToFire([item], now: now, appStart: appStart, notified: [])
        t.expectEqual(fired.map(\.id), [item.id], "fires when due passed while running")
    }

    // does not fire when due is still future
    do {
        let item = TodoItem(title: "later", dueDate: Date(timeIntervalSince1970: 5_000))
        let fired = ReminderLogic.tasksToFire([item], now: now, appStart: appStart, notified: [])
        t.expectTrue(fired.isEmpty, "no fire when future")
    }

    // does not late-fire for task due before launch (missed)
    do {
        let item = TodoItem(title: "missed", dueDate: Date(timeIntervalSince1970: 500))
        let fired = ReminderLogic.tasksToFire([item], now: now, appStart: appStart, notified: [])
        t.expectTrue(fired.isEmpty, "no late-fire for pre-launch due")
    }

    // does not fire already-notified
    do {
        let item = TodoItem(title: "again", dueDate: Date(timeIntervalSince1970: 1_500))
        let fired = ReminderLogic.tasksToFire([item], now: now, appStart: appStart, notified: [item.id])
        t.expectTrue(fired.isEmpty, "no double fire")
    }

    // does not fire done task
    do {
        let item = TodoItem(title: "done", dueDate: Date(timeIntervalSince1970: 1_500), isDone: true)
        let fired = ReminderLogic.tasksToFire([item], now: now, appStart: appStart, notified: [])
        t.expectTrue(fired.isEmpty, "no fire for done")
    }

    // does not fire undated task
    do {
        let item = TodoItem(title: "no date")
        let fired = ReminderLogic.tasksToFire([item], now: now, appStart: appStart, notified: [])
        t.expectTrue(fired.isEmpty, "no fire for undated")
    }

    // isOverdue: past due and not done
    do {
        let item = TodoItem(title: "x", dueDate: Date(timeIntervalSince1970: 500))
        t.expectTrue(ReminderLogic.isOverdue(item, now: now), "overdue when past+not done")
    }

    // isOverdue false when done
    do {
        let item = TodoItem(title: "x", dueDate: Date(timeIntervalSince1970: 500), isDone: true)
        t.expectFalse(ReminderLogic.isOverdue(item, now: now), "not overdue when done")
    }

    // isOverdue false when future
    do {
        let item = TodoItem(title: "x", dueDate: Date(timeIntervalSince1970: 5_000))
        t.expectFalse(ReminderLogic.isOverdue(item, now: now), "not overdue when future")
    }
}
