import Foundation
import KashTasksCore

func runTaskStoreMutationTests(_ t: TestRunner) {
    func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("kashtasks-mut-\(UUID().uuidString).json")
    }

    do {
        let url = tempURL(); defer { try? FileManager.default.removeItem(at: url) }
        let store = TaskStore(fileURL: url)
        let item = TodoItem(title: "once", dueDate: Date(timeIntervalSince1970: 100))
        store.add(item)
        store.complete(item.id, now: Date(timeIntervalSince1970: 200))
        t.expectEqual(store.items.first?.isDone, true, "non-recurring complete -> done")
    }

    do {
        let url = tempURL(); defer { try? FileManager.default.removeItem(at: url) }
        let store = TaskStore(fileURL: url)
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        let due = cal.date(from: DateComponents(year: 2026, month: 6, day: 14, hour: 9))!
        let item = TodoItem(title: "daily", dueDate: due, recurrence: .daily)
        store.add(item)
        store.complete(item.id, now: Date(timeIntervalSince1970: 0))
        let updated = store.items.first!
        t.expectEqual(updated.isDone, false, "recurring complete stays open")
        let expectedNext = cal.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 9))!
        t.expectEqual(updated.dueDate, expectedNext, "recurring complete advances dueDate")
    }

    do {
        let url = tempURL(); defer { try? FileManager.default.removeItem(at: url) }
        let store = TaskStore(fileURL: url)
        let item = TodoItem(title: "habit", recurrence: .daily)
        store.add(item)
        let now = Date(timeIntervalSince1970: 1_000_000)
        store.complete(item.id, now: now)
        let updated = store.items.first!
        t.expectEqual(updated.isDone, false, "recurring no-due stays open")
        t.expectTrue(updated.dueDate != nil, "recurring no-due gets a dueDate")
        t.expectTrue((updated.dueDate ?? now) > now, "recurring no-due advances into the future")
    }

    do {
        let url = tempURL(); defer { try? FileManager.default.removeItem(at: url) }
        let store = TaskStore(fileURL: url)
        let item = TodoItem(title: "s", dueDate: Date(timeIntervalSince1970: 100), isDone: true)
        store.add(item)
        let now = Date(timeIntervalSince1970: 5_000)
        store.snooze(item.id, by: 600, from: now)
        let updated = store.items.first!
        t.expectEqual(updated.dueDate, now.addingTimeInterval(600), "snooze -> now+interval")
        t.expectEqual(updated.isDone, false, "snooze clears done")
    }

    do {
        let url = tempURL(); defer { try? FileManager.default.removeItem(at: url) }
        let store = TaskStore(fileURL: url)
        let item = TodoItem(title: "r", isDone: true)
        store.add(item)
        let target = Date(timeIntervalSince1970: 99_999)
        store.reschedule(item.id, to: target)
        let updated = store.items.first!
        t.expectEqual(updated.dueDate, target, "reschedule -> target date")
        t.expectEqual(updated.isDone, false, "reschedule clears done")
    }

    do {
        let url = tempURL(); defer { try? FileManager.default.removeItem(at: url) }
        let store = TaskStore(fileURL: url)
        let due = Date(timeIntervalSince1970: 100)
        let item = TodoItem(title: "roll", dueDate: due, recurrence: .daily)
        store.add(item)
        store.toggleDone(item.id)
        let updated = store.items.first!
        t.expectEqual(updated.isDone, false, "toggleDone recurring stays open")
        t.expectTrue((updated.dueDate ?? due) > due, "toggleDone recurring advances")
    }
}
