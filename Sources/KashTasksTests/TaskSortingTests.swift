import Foundation
import KashTasksCore

func runTaskSortingTests(_ t: TestRunner) {
    // empty tag becomes "Inbox"
    do {
        let groups = TaskSorting.grouped([TodoItem(title: "Loose", tag: "")])
        t.expectEqual(groups.map(\.tag), ["Inbox"], "empty tag -> Inbox")
    }

    // groups alphabetical by tag
    do {
        let items = [
            TodoItem(title: "A", tag: "Work"),
            TodoItem(title: "B", tag: "Home"),
        ]
        t.expectEqual(TaskSorting.grouped(items).map(\.tag), ["Home", "Work"], "alphabetical groups")
    }

    // sorts by priority then due date within a group
    do {
        let early = Date(timeIntervalSince1970: 100)
        let late = Date(timeIntervalSince1970: 200)
        let items = [
            TodoItem(title: "low",        priority: .low,    tag: "T"),
            TodoItem(title: "high-late",  priority: .high,   tag: "T", dueDate: late),
            TodoItem(title: "high-early", priority: .high,   tag: "T", dueDate: early),
            TodoItem(title: "medium",     priority: .medium, tag: "T"),
        ]
        let sorted = TaskSorting.grouped(items).first!.items.map(\.title)
        t.expectEqual(sorted, ["high-early", "high-late", "medium", "low"], "priority then dueDate")
    }

    // dated tasks sort before undated at same priority
    do {
        let due = Date(timeIntervalSince1970: 100)
        let items = [
            TodoItem(title: "no-date", priority: .medium, tag: "T"),
            TodoItem(title: "dated",   priority: .medium, tag: "T", dueDate: due),
        ]
        let sorted = TaskSorting.grouped(items).first!.items.map(\.title)
        t.expectEqual(sorted, ["dated", "no-date"], "dated before undated")
    }
}
