import Foundation
import KashTasksCore

func runTaskStoreTests(_ t: TestRunner) {
    func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("kashtasks-test-\(UUID().uuidString).json")
    }

    // add persists and reloads from disk
    do {
        let url = tempURL(); defer { try? FileManager.default.removeItem(at: url) }
        let store = TaskStore(fileURL: url)
        store.add(TodoItem(title: "First"))
        t.expectEqual(store.items.count, 1, "add increments count")
        let reloaded = TaskStore(fileURL: url)
        t.expectEqual(reloaded.items.map(\.title), ["First"], "reload from disk")
    }

    // update changes matching item
    do {
        let url = tempURL(); defer { try? FileManager.default.removeItem(at: url) }
        let store = TaskStore(fileURL: url)
        var item = TodoItem(title: "Old")
        store.add(item)
        item.title = "New"
        store.update(item)
        t.expectEqual(store.items.first?.title, "New", "update mutates item")
    }

    // toggleDone flips completion
    do {
        let url = tempURL(); defer { try? FileManager.default.removeItem(at: url) }
        let store = TaskStore(fileURL: url)
        let item = TodoItem(title: "Task")
        store.add(item)
        store.toggleDone(item.id)
        t.expectEqual(store.items.first?.isDone, true, "toggleDone -> true")
        store.toggleDone(item.id)
        t.expectEqual(store.items.first?.isDone, false, "toggleDone -> false")
    }

    // delete removes item
    do {
        let url = tempURL(); defer { try? FileManager.default.removeItem(at: url) }
        let store = TaskStore(fileURL: url)
        let item = TodoItem(title: "Doomed")
        store.add(item)
        store.delete(item.id)
        t.expectTrue(store.items.isEmpty, "delete removes item")
    }

    // missing file starts empty
    do {
        let url = tempURL()
        let store = TaskStore(fileURL: url)
        t.expectTrue(store.items.isEmpty, "missing file -> empty")
    }

    // corrupt file is preserved, not silently wiped
    do {
        let url = tempURL()
        let backup = url.appendingPathExtension("corrupt")
        defer {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: backup)
        }
        try! Data("not valid json".utf8).write(to: url)
        let store = TaskStore(fileURL: url)
        t.expectTrue(store.items.isEmpty, "corrupt file -> empty in memory")
        t.expectTrue(FileManager.default.fileExists(atPath: backup.path), "corrupt file backed up to .corrupt")
    }
}
