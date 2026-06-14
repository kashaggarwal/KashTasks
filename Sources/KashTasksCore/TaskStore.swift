import Foundation
import Combine

public final class TaskStore: ObservableObject {
    @Published public private(set) var items: [TodoItem] = []

    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
        load()
    }

    public func add(_ item: TodoItem) {
        items.append(item)
        save()
    }

    public func update(_ item: TodoItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = item
        save()
    }

    public func toggleDone(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        if items[index].isDone {
            items[index].isDone = false
            save()
        } else {
            completeAt(index, now: Date())
        }
    }

    /// Complete a task. Recurring dated tasks roll forward instead of being marked done.
    public func complete(_ id: UUID, now: Date = Date()) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        completeAt(index, now: now)
    }

    private func completeAt(_ index: Int, now: Date) {
        let item = items[index]
        if item.recurrence != .none {
            let base = item.dueDate ?? now
            var next = Recurrence.nextDate(after: base, rule: item.recurrence)
            // Skip occurrences already in the past so a long-overdue recurring task
            // lands in the future instead of staying overdue (and re-notifying).
            while let candidate = next, candidate <= now {
                next = Recurrence.nextDate(after: candidate, rule: item.recurrence)
            }
            if let next {
                items[index].dueDate = next
                items[index].isDone = false
                save()
                return
            }
        }
        items[index].isDone = true
        save()
    }

    public func snooze(_ id: UUID, by interval: TimeInterval, from now: Date = Date()) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].dueDate = now.addingTimeInterval(interval)
        items[index].isDone = false
        save()
    }

    public func reschedule(_ id: UUID, to date: Date) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].dueDate = date
        items[index].isDone = false
        save()
    }

    public func delete(_ id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    public func load() {
        guard let data = try? Data(contentsOf: fileURL) else {
            items = []
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            items = try decoder.decode([TodoItem].self, from: data)
        } catch {
            // The file exists but is unreadable (corrupt or partially written).
            // Preserve it for recovery instead of silently overwriting it with an
            // empty list on the next save.
            let backup = fileURL.appendingPathExtension("corrupt")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: fileURL, to: backup)
            NSLog("KashTasks: tasks file unreadable; backed up to \(backup.lastPathComponent): \(error)")
            items = []
        }
    }

    public func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(items)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("KashTasks: failed to save tasks: \(error)")
        }
    }
}
