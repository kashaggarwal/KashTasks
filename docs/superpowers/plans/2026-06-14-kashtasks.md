# KashTasks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS menu bar task tracker (KashTasks) that stores tasks locally as JSON and fires native notifications at each task's due time.

**Architecture:** A Swift Package with two targets. `KashTasksCore` (a library) holds the pure, testable logic — the `TodoItem` model, `TaskStore` (JSON persistence), `TaskSorting` (group/sort), and `ReminderLogic` (fire/overdue decisions). `KashTasks` (an executable) holds the SwiftUI app shell — `KashTasksApp` (MenuBarExtra entry, permissions, login item), `MenuBarView` (UI), and `ReminderScheduler` (timer + UNUserNotificationCenter glue). A shell script bundles the executable into an ad-hoc-signed `.app`.

**Tech Stack:** Swift 6.1, Swift Package Manager, SwiftUI (`MenuBarExtra`), AppKit, `UserNotifications`, `ServiceManagement` (`SMAppService`), XCTest. No Xcode IDE — Command Line Tools only.

---

## File Structure

```
KashTasks/
  Package.swift
  Sources/
    KashTasksCore/
      TodoItem.swift          # model + Priority enum
      TaskStore.swift         # ObservableObject JSON persistence
      TaskSorting.swift       # pure group-by-tag + sort
      ReminderLogic.swift     # pure fire/overdue decisions
    KashTasks/
      AppPaths.swift          # filesystem paths
      ReminderScheduler.swift # timer + notifications (side effects)
      MenuBarView.swift       # SwiftUI popover UI
      KashTasksApp.swift      # @main MenuBarExtra, permissions, login item
  Tests/
    KashTasksCoreTests/
      TodoItemTests.swift
      TaskStoreTests.swift
      TaskSortingTests.swift
      ReminderLogicTests.swift
  scripts/
    bundle.sh                 # build + wrap into KashTasks.app + ad-hoc sign
```

The repository root is `~/Downloads/KashTasks` (already git-initialized; the spec lives under `docs/superpowers/`).

---

### Task 1: Package scaffolding

**Files:**
- Create: `Package.swift`
- Create: `Sources/KashTasksCore/Placeholder.swift` (temporary, removed in Task 2)

- [ ] **Step 1: Write `Package.swift`**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KashTasks",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "KashTasksCore"),
        .executableTarget(
            name: "KashTasks",
            dependencies: ["KashTasksCore"]
        ),
        .testTarget(
            name: "KashTasksCoreTests",
            dependencies: ["KashTasksCore"]
        ),
    ]
)
```

- [ ] **Step 2: Add a temporary placeholder so the library target compiles**

`Sources/KashTasksCore/Placeholder.swift`:

```swift
// Temporary — replaced by real types in Task 2.
enum Placeholder {}
```

- [ ] **Step 3: Add a temporary executable entry so the package builds**

`Sources/KashTasks/main.swift`:

```swift
print("KashTasks placeholder")
```

- [ ] **Step 4: Verify the package builds**

Run: `cd ~/Downloads/KashTasks && swift build`
Expected: `Build complete!` with no errors.

- [ ] **Step 5: Add `.gitignore` and commit**

`.gitignore`:

```
.build/
*.app
.DS_Store
```

```bash
cd ~/Downloads/KashTasks
git add Package.swift Sources .gitignore
git commit -m "chore: scaffold Swift package"
```

---

### Task 2: TodoItem model + Priority enum

**Files:**
- Create: `Sources/KashTasksCore/TodoItem.swift`
- Delete: `Sources/KashTasksCore/Placeholder.swift`
- Test: `Tests/KashTasksCoreTests/TodoItemTests.swift`

- [ ] **Step 1: Write the failing test**

`Tests/KashTasksCoreTests/TodoItemTests.swift`:

```swift
import XCTest
@testable import KashTasksCore

final class TodoItemTests: XCTestCase {
    func testCodableRoundTrip() throws {
        let item = TodoItem(
            title: "Buy milk",
            notes: "2%",
            priority: .high,
            tag: "Errands",
            dueDate: Date(timeIntervalSince1970: 1_000_000),
            isDone: false
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(item)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TodoItem.self, from: data)

        XCTAssertEqual(decoded, item)
    }

    func testPrioritySortRankOrder() {
        XCTAssertLessThan(Priority.high.sortRank, Priority.medium.sortRank)
        XCTAssertLessThan(Priority.medium.sortRank, Priority.low.sortRank)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter TodoItemTests`
Expected: FAIL — `cannot find 'TodoItem' in scope`.

- [ ] **Step 3: Write minimal implementation**

`Sources/KashTasksCore/TodoItem.swift`:

```swift
import Foundation

public enum Priority: String, Codable, CaseIterable, Sendable {
    case high, medium, low

    public var sortRank: Int {
        switch self {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        }
    }

    public var label: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
}

public struct TodoItem: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var notes: String
    public var priority: Priority
    public var tag: String
    public var dueDate: Date?
    public var isDone: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        priority: Priority = .medium,
        tag: String = "",
        dueDate: Date? = nil,
        isDone: Bool = false
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.priority = priority
        self.tag = tag
        self.dueDate = dueDate
        self.isDone = isDone
    }
}
```

- [ ] **Step 4: Delete the placeholder**

```bash
rm Sources/KashTasksCore/Placeholder.swift
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --filter TodoItemTests`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add Sources/KashTasksCore/TodoItem.swift Tests/KashTasksCoreTests/TodoItemTests.swift
git rm Sources/KashTasksCore/Placeholder.swift
git commit -m "feat: add TodoItem model and Priority enum"
```

---

### Task 3: TaskStore (JSON persistence)

**Files:**
- Create: `Sources/KashTasksCore/TaskStore.swift`
- Test: `Tests/KashTasksCoreTests/TaskStoreTests.swift`

- [ ] **Step 1: Write the failing tests**

`Tests/KashTasksCoreTests/TaskStoreTests.swift`:

```swift
import XCTest
@testable import KashTasksCore

final class TaskStoreTests: XCTestCase {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("kashtasks-test-\(UUID().uuidString).json")
    }

    func testAddPersistsAndReloads() {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = TaskStore(fileURL: url)
        store.add(TodoItem(title: "First"))
        XCTAssertEqual(store.items.count, 1)

        let reloaded = TaskStore(fileURL: url)
        XCTAssertEqual(reloaded.items.map(\.title), ["First"])
    }

    func testUpdateChangesMatchingItem() {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = TaskStore(fileURL: url)
        var item = TodoItem(title: "Old")
        store.add(item)
        item.title = "New"
        store.update(item)

        XCTAssertEqual(store.items.first?.title, "New")
    }

    func testToggleDone() {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = TaskStore(fileURL: url)
        let item = TodoItem(title: "Task")
        store.add(item)
        store.toggleDone(item.id)
        XCTAssertEqual(store.items.first?.isDone, true)
        store.toggleDone(item.id)
        XCTAssertEqual(store.items.first?.isDone, false)
    }

    func testDeleteRemovesItem() {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = TaskStore(fileURL: url)
        let item = TodoItem(title: "Doomed")
        store.add(item)
        store.delete(item.id)
        XCTAssertTrue(store.items.isEmpty)
    }

    func testLoadMissingFileStartsEmpty() {
        let url = tempURL()
        let store = TaskStore(fileURL: url)
        XCTAssertTrue(store.items.isEmpty)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter TaskStoreTests`
Expected: FAIL — `cannot find 'TaskStore' in scope`.

- [ ] **Step 3: Write minimal implementation**

`Sources/KashTasksCore/TaskStore.swift`:

```swift
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
        items[index].isDone.toggle()
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
        items = (try? decoder.decode([TodoItem].self, from: data)) ?? []
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter TaskStoreTests`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/KashTasksCore/TaskStore.swift Tests/KashTasksCoreTests/TaskStoreTests.swift
git commit -m "feat: add TaskStore JSON persistence"
```

---

### Task 4: TaskSorting (group-by-tag + sort)

**Files:**
- Create: `Sources/KashTasksCore/TaskSorting.swift`
- Test: `Tests/KashTasksCoreTests/TaskSortingTests.swift`

- [ ] **Step 1: Write the failing tests**

`Tests/KashTasksCoreTests/TaskSortingTests.swift`:

```swift
import XCTest
@testable import KashTasksCore

final class TaskSortingTests: XCTestCase {
    func testEmptyTagBecomesInbox() {
        let groups = TaskSorting.grouped([TodoItem(title: "Loose", tag: "")])
        XCTAssertEqual(groups.map(\.tag), ["Inbox"])
    }

    func testGroupsAlphabeticalByTag() {
        let items = [
            TodoItem(title: "A", tag: "Work"),
            TodoItem(title: "B", tag: "Home"),
        ]
        XCTAssertEqual(TaskSorting.grouped(items).map(\.tag), ["Home", "Work"])
    }

    func testSortsByPriorityThenDueDate() {
        let early = Date(timeIntervalSince1970: 100)
        let late = Date(timeIntervalSince1970: 200)
        let items = [
            TodoItem(title: "low",       priority: .low,    tag: "T"),
            TodoItem(title: "high-late", priority: .high,   tag: "T", dueDate: late),
            TodoItem(title: "high-early",priority: .high,   tag: "T", dueDate: early),
            TodoItem(title: "medium",    priority: .medium, tag: "T"),
        ]
        let sorted = TaskSorting.grouped(items).first!.items.map(\.title)
        XCTAssertEqual(sorted, ["high-early", "high-late", "medium", "low"])
    }

    func testDatedTasksSortBeforeUndatedAtSamePriority() {
        let due = Date(timeIntervalSince1970: 100)
        let items = [
            TodoItem(title: "no-date", priority: .medium, tag: "T"),
            TodoItem(title: "dated",   priority: .medium, tag: "T", dueDate: due),
        ]
        let sorted = TaskSorting.grouped(items).first!.items.map(\.title)
        XCTAssertEqual(sorted, ["dated", "no-date"])
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter TaskSortingTests`
Expected: FAIL — `cannot find 'TaskSorting' in scope`.

- [ ] **Step 3: Write minimal implementation**

`Sources/KashTasksCore/TaskSorting.swift`:

```swift
import Foundation

public enum TaskSorting {
    public struct Group: Equatable {
        public let tag: String
        public let items: [TodoItem]
    }

    public static func grouped(_ items: [TodoItem]) -> [Group] {
        let buckets = Dictionary(grouping: items) { item in
            item.tag.isEmpty ? "Inbox" : item.tag
        }
        return buckets.keys.sorted().map { key in
            Group(tag: key, items: sortedWithin(buckets[key] ?? []))
        }
    }

    public static func sortedWithin(_ items: [TodoItem]) -> [TodoItem] {
        items.sorted { lhs, rhs in
            if lhs.priority.sortRank != rhs.priority.sortRank {
                return lhs.priority.sortRank < rhs.priority.sortRank
            }
            switch (lhs.dueDate, rhs.dueDate) {
            case let (l?, r?): return l < r
            case (_?, nil):    return true
            case (nil, _?):    return false
            case (nil, nil):   return false
            }
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter TaskSortingTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/KashTasksCore/TaskSorting.swift Tests/KashTasksCoreTests/TaskSortingTests.swift
git commit -m "feat: add TaskSorting group-and-sort logic"
```

---

### Task 5: ReminderLogic (fire/overdue decisions)

**Files:**
- Create: `Sources/KashTasksCore/ReminderLogic.swift`
- Test: `Tests/KashTasksCoreTests/ReminderLogicTests.swift`

This is the heart of the "fire once at due time, never late-fire on launch" rule.
`appStart` is the moment the app launched. A task fires only if its due date is at or
after `appStart` and at or before `now` (so it passed *while the app was running*),
it is not done, and it has not already fired.

- [ ] **Step 1: Write the failing tests**

`Tests/KashTasksCoreTests/ReminderLogicTests.swift`:

```swift
import XCTest
@testable import KashTasksCore

final class ReminderLogicTests: XCTestCase {
    private let appStart = Date(timeIntervalSince1970: 1_000)
    private let now      = Date(timeIntervalSince1970: 2_000)

    func testFiresWhenDuePassedWhileRunning() {
        let item = TodoItem(title: "ring", dueDate: Date(timeIntervalSince1970: 1_500))
        let fired = ReminderLogic.tasksToFire([item], now: now, appStart: appStart, notified: [])
        XCTAssertEqual(fired.map(\.id), [item.id])
    }

    func testDoesNotFireWhenDueIsStillFuture() {
        let item = TodoItem(title: "later", dueDate: Date(timeIntervalSince1970: 5_000))
        let fired = ReminderLogic.tasksToFire([item], now: now, appStart: appStart, notified: [])
        XCTAssertTrue(fired.isEmpty)
    }

    func testDoesNotLateFireForTaskDueBeforeLaunch() {
        // due at 500, before appStart (1000) -> missed, must NOT fire
        let item = TodoItem(title: "missed", dueDate: Date(timeIntervalSince1970: 500))
        let fired = ReminderLogic.tasksToFire([item], now: now, appStart: appStart, notified: [])
        XCTAssertTrue(fired.isEmpty)
    }

    func testDoesNotFireAlreadyNotified() {
        let item = TodoItem(title: "again", dueDate: Date(timeIntervalSince1970: 1_500))
        let fired = ReminderLogic.tasksToFire([item], now: now, appStart: appStart, notified: [item.id])
        XCTAssertTrue(fired.isEmpty)
    }

    func testDoesNotFireDoneTask() {
        let item = TodoItem(title: "done", dueDate: Date(timeIntervalSince1970: 1_500), isDone: true)
        let fired = ReminderLogic.tasksToFire([item], now: now, appStart: appStart, notified: [])
        XCTAssertTrue(fired.isEmpty)
    }

    func testDoesNotFireUndatedTask() {
        let item = TodoItem(title: "no date")
        let fired = ReminderLogic.tasksToFire([item], now: now, appStart: appStart, notified: [])
        XCTAssertTrue(fired.isEmpty)
    }

    func testIsOverdueWhenPastDueAndNotDone() {
        let item = TodoItem(title: "x", dueDate: Date(timeIntervalSince1970: 500))
        XCTAssertTrue(ReminderLogic.isOverdue(item, now: now))
    }

    func testIsNotOverdueWhenDone() {
        let item = TodoItem(title: "x", dueDate: Date(timeIntervalSince1970: 500), isDone: true)
        XCTAssertFalse(ReminderLogic.isOverdue(item, now: now))
    }

    func testIsNotOverdueWhenFuture() {
        let item = TodoItem(title: "x", dueDate: Date(timeIntervalSince1970: 5_000))
        XCTAssertFalse(ReminderLogic.isOverdue(item, now: now))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter ReminderLogicTests`
Expected: FAIL — `cannot find 'ReminderLogic' in scope`.

- [ ] **Step 3: Write minimal implementation**

`Sources/KashTasksCore/ReminderLogic.swift`:

```swift
import Foundation

public enum ReminderLogic {
    /// Tasks whose due time passed while the app was running and have not yet fired.
    public static func tasksToFire(
        _ items: [TodoItem],
        now: Date,
        appStart: Date,
        notified: Set<UUID>
    ) -> [TodoItem] {
        items.filter { item in
            guard let due = item.dueDate,
                  !item.isDone,
                  !notified.contains(item.id)
            else { return false }
            return due >= appStart && due <= now
        }
    }

    /// Past-due and not completed — used for the red "missed/overdue" indicator in the UI.
    public static func isOverdue(_ item: TodoItem, now: Date) -> Bool {
        guard let due = item.dueDate, !item.isDone else { return false }
        return due < now
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter ReminderLogicTests`
Expected: PASS (9 tests).

- [ ] **Step 5: Run the whole suite**

Run: `swift test`
Expected: all tests PASS (TodoItem, TaskStore, TaskSorting, ReminderLogic).

- [ ] **Step 6: Commit**

```bash
git add Sources/KashTasksCore/ReminderLogic.swift Tests/KashTasksCoreTests/ReminderLogicTests.swift
git commit -m "feat: add ReminderLogic fire/overdue decisions"
```

---

### Task 6: AppPaths helper

**Files:**
- Create: `Sources/KashTasks/AppPaths.swift`

- [ ] **Step 1: Write the implementation**

`Sources/KashTasks/AppPaths.swift`:

```swift
import Foundation

enum AppPaths {
    static var supportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("KashTasks", isDirectory: true)
    }

    static var tasksFile: URL {
        supportDirectory.appendingPathComponent("tasks.json")
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/KashTasks/AppPaths.swift
git commit -m "feat: add AppPaths for Application Support location"
```

---

### Task 7: ReminderScheduler (timer + notifications)

**Files:**
- Create: `Sources/KashTasks/ReminderScheduler.swift`

This wraps the pure `ReminderLogic` with side effects: it observes the store, keeps a
1-second-granularity repeating timer, and posts a `UNUserNotificationCenter` notification
when `ReminderLogic.tasksToFire` returns a task. It records launch time as `appStart` and
remembers fired IDs so nothing fires twice. UI/notification side effects are verified
manually in Task 11.

- [ ] **Step 1: Write the implementation**

`Sources/KashTasks/ReminderScheduler.swift`:

```swift
import Foundation
import Combine
import UserNotifications
import KashTasksCore

@MainActor
final class ReminderScheduler: ObservableObject {
    private let store: TaskStore
    private let appStart: Date
    private var notified: Set<UUID> = []
    private var timer: Timer?
    private var cancellable: AnyCancellable?

    init(store: TaskStore, appStart: Date = Date()) {
        self.store = store
        self.appStart = appStart
    }

    func start() {
        // Re-evaluate whenever the store changes...
        cancellable = store.$items
            .sink { [weak self] _ in self?.evaluate() }

        // ...and on a steady tick so due times are caught while idle.
        let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.evaluate() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        evaluate()
    }

    private func evaluate() {
        let due = ReminderLogic.tasksToFire(
            store.items, now: Date(), appStart: appStart, notified: notified
        )
        for item in due {
            notified.insert(item.id)
            post(item)
        }
    }

    private func post(_ item: TodoItem) {
        let content = UNMutableNotificationContent()
        content.title = item.title
        content.body = item.notes.isEmpty ? "Task due now" : item.notes
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: item.id.uuidString,
            content: content,
            trigger: nil // deliver immediately
        )
        UNUserNotificationCenter.current().add(request)
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/KashTasks/ReminderScheduler.swift
git commit -m "feat: add ReminderScheduler timer and notifications"
```

---

### Task 8: MenuBarView (SwiftUI UI)

**Files:**
- Create: `Sources/KashTasks/MenuBarView.swift`

Popover content: a scrollable list grouped by tag (via `TaskSorting.grouped`), each row with
a completion toggle, title, due-date label, priority dot, and delete button; plus an add form.
Overdue, not-done tasks show their due date in red (via `ReminderLogic.isOverdue`).

- [ ] **Step 1: Write the implementation**

`Sources/KashTasks/MenuBarView.swift`:

```swift
import SwiftUI
import KashTasksCore

struct MenuBarView: View {
    @EnvironmentObject var store: TaskStore

    // Add-form state
    @State private var newTitle = ""
    @State private var newTag = ""
    @State private var newNotes = ""
    @State private var newPriority: Priority = .medium
    @State private var hasDueDate = false
    @State private var newDueDate = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("KashTasks").font(.headline)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(TaskSorting.grouped(store.items), id: \.tag) { group in
                        Text(group.tag)
                            .font(.caption).bold()
                            .foregroundStyle(.secondary)
                        ForEach(group.items) { item in
                            row(for: item)
                        }
                    }
                    if store.items.isEmpty {
                        Text("No tasks yet").foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxHeight: 280)

            Divider()
            addForm

            Divider()
            Button("Quit KashTasks") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 320)
    }

    @ViewBuilder
    private func row(for item: TodoItem) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Button {
                store.toggleDone(item.id)
            } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
            }
            .buttonStyle(.plain)

            Circle()
                .fill(color(for: item.priority))
                .frame(width: 8, height: 8)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .strikethrough(item.isDone)
                if let due = item.dueDate {
                    Text(due.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(ReminderLogic.isOverdue(item, now: Date()) ? .red : .secondary)
                }
                if !item.notes.isEmpty {
                    Text(item.notes).font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                store.delete(item.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
        }
    }

    private var addForm: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("New task", text: $newTitle)
            HStack {
                TextField("Tag", text: $newTag)
                Picker("", selection: $newPriority) {
                    ForEach(Priority.allCases, id: \.self) { p in
                        Text(p.label).tag(p)
                    }
                }
                .labelsHidden()
            }
            TextField("Notes", text: $newNotes)
            Toggle("Due date", isOn: $hasDueDate)
            if hasDueDate {
                DatePicker("", selection: $newDueDate)
                    .labelsHidden()
            }
            Button("Add") { addTask() }
                .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func addTask() {
        let item = TodoItem(
            title: newTitle.trimmingCharacters(in: .whitespaces),
            notes: newNotes,
            priority: newPriority,
            tag: newTag.trimmingCharacters(in: .whitespaces),
            dueDate: hasDueDate ? newDueDate : nil
        )
        store.add(item)
        newTitle = ""; newTag = ""; newNotes = ""
        newPriority = .medium; hasDueDate = false; newDueDate = Date()
    }

    private func color(for priority: Priority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .gray
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/KashTasks/MenuBarView.swift
git commit -m "feat: add MenuBarView UI"
```

---

### Task 9: KashTasksApp entry (MenuBarExtra, permissions, login item)

**Files:**
- Delete: `Sources/KashTasks/main.swift`
- Create: `Sources/KashTasks/KashTasksApp.swift`

A SwiftUI `@main` App cannot coexist with a top-level `main.swift`, so the placeholder is
removed. `AppDelegate` requests notification permission and registers the login item on launch.

- [ ] **Step 1: Remove the placeholder entry**

```bash
git rm Sources/KashTasks/main.swift
```

- [ ] **Step 2: Write the app entry**

`Sources/KashTasks/KashTasksApp.swift`:

```swift
import SwiftUI
import AppKit
import UserNotifications
import ServiceManagement
import KashTasksCore

@main
struct KashTasksApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var store = TaskStore(fileURL: AppPaths.tasksFile)
    @StateObject private var scheduler: ReminderScheduler

    init() {
        let store = TaskStore(fileURL: AppPaths.tasksFile)
        _store = StateObject(wrappedValue: store)
        _scheduler = StateObject(wrappedValue: ReminderScheduler(store: store))
    }

    var body: some Scene {
        MenuBarExtra("KashTasks", systemImage: "checklist") {
            MenuBarView()
                .environmentObject(store)
                .onAppear { scheduler.start() }
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound]
        ) { granted, error in
            if let error { NSLog("KashTasks: notif auth error \(error)") }
            NSLog("KashTasks: notifications granted=\(granted)")
        }

        do {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("KashTasks: login-item registration failed: \(error)")
        }
    }
}
```

> Note: `init()` constructs the `TaskStore` twice (once for each `@StateObject`). To avoid
> two instances, the property initializer `= TaskStore(...)` on `store` is overridden inside
> `init()` by reassigning `_store`. The earlier inline initializer is required only so the
> stored property has a declared type; the value set in `init()` wins. If the compiler warns
> about the unused inline initializer, replace the `store` declaration with
> `@StateObject private var store: TaskStore` (no inline value) and keep only the `init()` assignment.

- [ ] **Step 3: Verify it compiles**

Run: `swift build`
Expected: `Build complete!` (warnings about the inline initializer are acceptable; apply the note above if it errors).

- [ ] **Step 4: Commit**

```bash
git rm Sources/KashTasks/main.swift
git add Sources/KashTasks/KashTasksApp.swift
git commit -m "feat: add MenuBarExtra app entry with permissions and login item"
```

---

### Task 10: Bundle script (.app + ad-hoc sign)

**Files:**
- Create: `scripts/bundle.sh`

- [ ] **Step 1: Write the script**

`scripts/bundle.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/KashTasks.app"
BIN_NAME="KashTasks"
BUNDLE_ID="com.kashish.kashtasks"

echo "Building release binary..."
swift build -c release --package-path "$ROOT"
BIN_PATH="$(swift build -c release --package-path "$ROOT" --show-bin-path)/$BIN_NAME"

echo "Assembling $APP ..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp "$BIN_PATH" "$APP/Contents/MacOS/$BIN_NAME"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>KashTasks</string>
    <key>CFBundleDisplayName</key><string>KashTasks</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key><string>1.0</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleExecutable</key><string>$BIN_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

echo "Ad-hoc signing..."
codesign --force --deep --sign - "$APP"

echo "Done: $APP"
echo "Move it to /Applications and open it, then approve notifications when prompted."
```

- [ ] **Step 2: Make it executable and run it**

```bash
chmod +x scripts/bundle.sh
./scripts/bundle.sh
```

Expected: ends with `Done: .../KashTasks.app` and no codesign error.

- [ ] **Step 3: Verify the bundle is valid**

Run: `codesign --verify --verbose KashTasks.app && echo OK`
Expected: `KashTasks.app: valid on disk` ... `OK`.

- [ ] **Step 4: Commit**

```bash
git add scripts/bundle.sh
git commit -m "build: add app bundling and ad-hoc signing script"
```

---

### Task 11: Manual verification

**Files:** none (manual checklist).

- [ ] **Step 1: Full test suite green**

Run: `swift test`
Expected: all tests pass.

- [ ] **Step 2: Install and launch**

```bash
cp -R KashTasks.app /Applications/
open /Applications/KashTasks.app
```

Expected: a checklist icon appears in the menu bar; a macOS prompt asks to allow notifications — click Allow.

- [ ] **Step 3: Add-and-persist check**

- Click the menu bar icon → add a task titled "Test", tag "Work", priority High.
- Confirm it appears under a "Work" group with a red priority dot.
- Run: `cat ~/Library/Application\ Support/KashTasks/tasks.json`
- Expected: JSON contains the "Test" task.

- [ ] **Step 4: Reminder fire check**

- Add a task with a due date ~1 minute in the future and the app left running.
- Wait. Expected: a native notification appears at the due time with the task title.

- [ ] **Step 5: Missed (no late-fire) check**

- Quit KashTasks. Add nothing.
- Reopen `tasks.json` is not needed; instead: with the app quit, wait until a previously-future
  due time passes, then relaunch the app.
- Expected: NO notification fires for the now-past task; its due date shows in red in the list.

- [ ] **Step 6: Login-item check**

- Open System Settings → General → Login Items.
- Expected: KashTasks is listed under "Open at Login".

- [ ] **Step 7: Final commit (docs/state, if any changes)**

```bash
git add -A
git commit -m "docs: record manual verification results" || echo "nothing to commit"
```

---

## Notes on Risk (from spec)

If notifications do not appear even after approval (ad-hoc-signed apps occasionally need to
live in `/Applications` and be relaunched), the fallback is to replace the body of
`ReminderScheduler.post(_:)` with an `osascript` shell-out:

```swift
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
p.arguments = ["-e", "display notification \"\(item.title)\" with title \"KashTasks\""]
try? p.run()
```

This is a contingency only — try `UNUserNotificationCenter` first.
