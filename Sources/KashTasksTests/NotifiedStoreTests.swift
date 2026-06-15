import Foundation
import KashTasksCore

func runNotifiedStoreTests(_ t: TestRunner) {
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent("notified-test-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: tmp) }

    let id = UUID()
    let due = Date(timeIntervalSince1970: 1_500)

    do {
        let store = NotifiedStore(fileURL: tmp)
        t.expectTrue(store.entries.isEmpty, "starts empty")
        store.markNotified(id, due: due)
        t.expectEqual(store.entries[id], due, "records entry")
    }

    do {
        // A fresh instance reading the same file simulates a relaunch.
        let reloaded = NotifiedStore(fileURL: tmp)
        t.expectEqual(reloaded.entries[id], due, "persists across launches")
    }

    do {
        let store = NotifiedStore(fileURL: tmp)
        let other = UUID()
        store.markNotified(other, due: due)
        store.prune(keeping: [id])
        t.expectTrue(store.entries[other] == nil, "prunes entries for deleted tasks")
        t.expectEqual(store.entries[id], due, "keeps entries for live tasks")
    }
}
