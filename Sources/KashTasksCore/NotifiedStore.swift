import Foundation

/// Persists which reminders have already fired, keyed by task id with the dueDate
/// value that was notified. Persistence is what lets the scheduler fire reminders
/// that came due while the app was closed *exactly once* instead of re-alerting on
/// every launch. Stored as a small JSON map alongside the tasks file.
public final class NotifiedStore {
    public let fileURL: URL
    public private(set) var entries: [UUID: Date] = [:]

    public init(fileURL: URL) {
        self.fileURL = fileURL
        load()
    }

    /// Record that `id` was notified for the given due date.
    public func markNotified(_ id: UUID, due: Date) {
        entries[id] = due
        save()
    }

    /// Drop entries for tasks that no longer exist so the map can't grow unbounded.
    /// Only writes when something actually changed.
    public func prune(keeping ids: Set<UUID>) {
        let pruned = entries.filter { ids.contains($0.key) }
        guard pruned.count != entries.count else { return }
        entries = pruned
        save()
    }

    public func load() {
        guard let data = try? Data(contentsOf: fileURL) else {
            entries = [:]
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let raw = try? decoder.decode([String: Date].self, from: data) else {
            entries = [:]
            return
        }
        var mapped: [UUID: Date] = [:]
        for (key, value) in raw {
            if let id = UUID(uuidString: key) { mapped[id] = value }
        }
        entries = mapped
    }

    public func save() {
        let raw = Dictionary(uniqueKeysWithValues: entries.map { ($0.key.uuidString, $0.value) })
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(raw)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("KashTasks: failed to save notified state: \(error)")
        }
    }
}
