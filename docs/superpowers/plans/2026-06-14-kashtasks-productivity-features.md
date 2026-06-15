# KashTasks Productivity Features Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add global quick-capture (⌃⌥Space), actionable reminder notifications (Done/Snooze/Tomorrow), and recurring tasks to KashTasks.

**Architecture:** Pure, tested logic in `KashTasksCore` (`Recurrence`, updated `TodoItem`/`ReminderLogic`/`TaskStore`); system glue in the `KashTasks` executable (`HotkeyManager` via Carbon, `QuickCaptureController`/`QuickCaptureView`, `NotificationManager` as the `UNUserNotificationCenter` delegate). The scheduler's notified-tracking changes from `Set<UUID>` to `[UUID: Date]` so due-date changes re-arm reminders.

**Tech Stack:** Swift 6.1, SwiftPM, SwiftUI/AppKit, Carbon (`RegisterEventHotKey`), `UserNotifications`. Command Line Tools only. Tests run via `swift run KashTasksTests` (no XCTest); each test group is a `runXxxTests(_ t: TestRunner)` function added to `Sources/KashTasksTests/main.swift`.

**Test harness reminder:** `Sources/KashTasksTests/TestHarness.swift` defines `TestRunner` with `expectEqual(_ actual:_ expected:_ context:)`, `expectTrue`, `expectFalse`, `expectLessThan`, `check`, and `summarize()`. Add new group functions and call them from `main.swift` before `t.summarize()`.

---

### Task 1: Recurrence enum + nextDate logic

**Files:**
- Create: `Sources/KashTasksCore/Recurrence.swift`
- Create: `Sources/KashTasksTests/RecurrenceTests.swift`
- Modify: `Sources/KashTasksTests/main.swift`

- [ ] **Step 1: Write the failing tests** — `Sources/KashTasksTests/RecurrenceTests.swift`:

```swift
import Foundation
import KashTasksCore

func runRecurrenceTests(_ t: TestRunner) {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 9, _ min: Int = 30) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    // none -> nil
    t.expectTrue(Recurrence.nextDate(after: date(2026, 6, 14), rule: .none, calendar: cal) == nil, "none -> nil")

    // daily -> +1 day, preserves time
    t.expectEqual(Recurrence.nextDate(after: date(2026, 6, 14, 9, 30), rule: .daily, calendar: cal),
                  date(2026, 6, 15, 9, 30), "daily +1d")

    // weekly -> +7 days
    t.expectEqual(Recurrence.nextDate(after: date(2026, 6, 14), rule: .weekly, calendar: cal),
                  date(2026, 6, 21), "weekly +7d")

    // monthly -> +1 month
    t.expectEqual(Recurrence.nextDate(after: date(2026, 6, 14), rule: .monthly, calendar: cal),
                  date(2026, 7, 14), "monthly +1m")

    // monthly clamps Jan 31 -> Feb 28 (2026 not leap)
    let jan31 = date(2026, 1, 31, 8, 0)
    let nextFromJan31 = Recurrence.nextDate(after: jan31, rule: .monthly, calendar: cal)!
    let comps = cal.dateComponents([.year, .month, .day], from: nextFromJan31)
    t.expectEqual(comps.month, 2, "monthly from Jan31 -> February")
    t.expectEqual(comps.day, 28, "monthly from Jan31 -> day 28")

    // weekdays: Friday 2026-06-19 -> Monday 2026-06-22
    t.expectEqual(Recurrence.nextDate(after: date(2026, 6, 19), rule: .weekdays, calendar: cal),
                  date(2026, 6, 22), "weekdays Fri -> Mon")
    // weekdays: Wednesday 2026-06-17 -> Thursday 2026-06-18
    t.expectEqual(Recurrence.nextDate(after: date(2026, 6, 17), rule: .weekdays, calendar: cal),
                  date(2026, 6, 18), "weekdays Wed -> Thu")
    // weekdays: Saturday 2026-06-20 -> Monday 2026-06-22
    t.expectEqual(Recurrence.nextDate(after: date(2026, 6, 20), rule: .weekdays, calendar: cal),
                  date(2026, 6, 22), "weekdays Sat -> Mon")
}
```

- [ ] **Step 2: Add the call** to `Sources/KashTasksTests/main.swift` — add `runRecurrenceTests(t)` before `t.summarize()`.

- [ ] **Step 3: Run tests, verify they fail** — `swift run KashTasksTests` → compile error "cannot find 'Recurrence'".

- [ ] **Step 4: Implement** — `Sources/KashTasksCore/Recurrence.swift`:

```swift
import Foundation

public enum Recurrence: String, Codable, CaseIterable, Sendable {
    case none, daily, weekdays, weekly, monthly

    public var label: String {
        switch self {
        case .none:     return "None"
        case .daily:    return "Daily"
        case .weekdays: return "Weekdays"
        case .weekly:   return "Weekly"
        case .monthly:  return "Monthly"
        }
    }

    /// The next occurrence after `date`, preserving the original clock time.
    /// Returns nil for `.none`.
    public static func nextDate(after date: Date, rule: Recurrence, calendar: Calendar = .current) -> Date? {
        switch rule {
        case .none:
            return nil
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date)
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date)
        case .weekdays:
            var next = date
            repeat {
                guard let advanced = calendar.date(byAdding: .day, value: 1, to: next) else { return nil }
                next = advanced
            } while calendar.isDateInWeekend(next)
            return next
        }
    }
}
```

- [ ] **Step 5: Run tests, verify pass** — `swift run KashTasksTests` → "✅ All checks passed".

- [ ] **Step 6: Commit**

```bash
git add Sources/KashTasksCore/Recurrence.swift Sources/KashTasksTests/RecurrenceTests.swift Sources/KashTasksTests/main.swift
git commit -m "feat: add Recurrence enum and nextDate logic"
```

---

### Task 2: Add recurrence to TodoItem with tolerant decoding

**Files:**
- Modify: `Sources/KashTasksCore/TodoItem.swift`
- Create: `Sources/KashTasksTests/TodoItemRecurrenceTests.swift`
- Modify: `Sources/KashTasksTests/main.swift`

- [ ] **Step 1: Write the failing tests** — `Sources/KashTasksTests/TodoItemRecurrenceTests.swift`:

```swift
import Foundation
import KashTasksCore

func runTodoItemRecurrenceTests(_ t: TestRunner) {
    // default recurrence is .none
    t.expectEqual(TodoItem(title: "x").recurrence, Recurrence.none, "default recurrence none")

    // round-trip with a recurrence value
    let item = TodoItem(title: "standup", priority: .medium, tag: "Work",
                        dueDate: Date(timeIntervalSince1970: 1_000), recurrence: .weekdays)
    let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
    let data = try! enc.encode(item)
    let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
    let decoded = try! dec.decode(TodoItem.self, from: data)
    t.expectEqual(decoded, item, "recurrence survives round-trip")

    // legacy JSON without a "recurrence" key decodes to .none
    let legacy = """
    {"id":"\(UUID().uuidString)","title":"legacy","notes":"","priority":"high","tag":"","isDone":false}
    """.data(using: .utf8)!
    let legacyDecoded = try! dec.decode(TodoItem.self, from: legacy)
    t.expectEqual(legacyDecoded.recurrence, Recurrence.none, "legacy JSON -> recurrence none")
    t.expectEqual(legacyDecoded.title, "legacy", "legacy JSON decodes other fields")
}
```

- [ ] **Step 2: Add the call** to `main.swift` — `runTodoItemRecurrenceTests(t)` before `t.summarize()`.

- [ ] **Step 3: Run tests, verify they fail** — `swift run KashTasksTests` → error: `TodoItem` has no member `recurrence` / extra arg `recurrence`.

- [ ] **Step 4: Implement** — replace `Sources/KashTasksCore/TodoItem.swift` entirely with:

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
    public var recurrence: Recurrence

    public init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        priority: Priority = .medium,
        tag: String = "",
        dueDate: Date? = nil,
        isDone: Bool = false,
        recurrence: Recurrence = .none
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.priority = priority
        self.tag = tag
        self.dueDate = dueDate
        self.isDone = isDone
        self.recurrence = recurrence
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, notes, priority, tag, dueDate, isDone, recurrence
    }

    // Custom decode so legacy tasks.json files (no "recurrence" key) still load.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        priority = try c.decodeIfPresent(Priority.self, forKey: .priority) ?? .medium
        tag = try c.decodeIfPresent(String.self, forKey: .tag) ?? ""
        dueDate = try c.decodeIfPresent(Date.self, forKey: .dueDate)
        isDone = try c.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
        recurrence = try c.decodeIfPresent(Recurrence.self, forKey: .recurrence) ?? .none
    }
}
```

- [ ] **Step 5: Run tests, verify pass** — `swift run KashTasksTests`. (All prior tests must still pass; `TodoItem` Equatable/Codable still hold.)

- [ ] **Step 6: Commit**

```bash
git add Sources/KashTasksCore/TodoItem.swift Sources/KashTasksTests/TodoItemRecurrenceTests.swift Sources/KashTasksTests/main.swift
git commit -m "feat: add recurrence field to TodoItem with backward-compatible decoding"
```

---

### Task 3: ReminderLogic uses [UUID: Date] notified map

**Files:**
- Modify: `Sources/KashTasksCore/ReminderLogic.swift`
- Modify: `Sources/KashTasksTests/ReminderLogicTests.swift`

This changes the `tasksToFire` signature. The scheduler (Task 6) is updated to match.

- [ ] **Step 1: Replace the test group** — overwrite `Sources/KashTasksTests/ReminderLogicTests.swift`:

```swift
import Foundation
import KashTasksCore

func runReminderLogicTests(_ t: TestRunner) {
    let appStart = Date(timeIntervalSince1970: 1_000)
    let now      = Date(timeIntervalSince1970: 2_000)
    let dueWhileRunning = Date(timeIntervalSince1970: 1_500)

    // fires when due passed while running and never notified
    do {
        let item = TodoItem(title: "ring", dueDate: dueWhileRunning)
        let fired = ReminderLogic.tasksToFire([item], now: now, appStart: appStart, notified: [:])
        t.expectEqual(fired.map(\.id), [item.id], "fires when unseen")
    }

    // does not fire when already notified for this exact dueDate
    do {
        let item = TodoItem(title: "again", dueDate: dueWhileRunning)
        let fired = ReminderLogic.tasksToFire([item], now: now, appStart: appStart,
                                              notified: [item.id: dueWhileRunning])
        t.expectTrue(fired.isEmpty, "no fire when notified for same dueDate")
    }

    // RE-FIRES when the dueDate changed since last fire (snooze/reschedule/recurrence)
    do {
        let newDue = Date(timeIntervalSince1970: 1_800)
        let item = TodoItem(title: "snoozed", dueDate: newDue)
        let fired = ReminderLogic.tasksToFire([item], now: now, appStart: appStart,
                                              notified: [item.id: dueWhileRunning])
        t.expectEqual(fired.map(\.id), [item.id], "re-fires when dueDate changed")
    }

    // future, missed (pre-launch), done, undated -> no fire
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

    // isOverdue unchanged
    do {
        let item = TodoItem(title: "x", dueDate: Date(timeIntervalSince1970: 500))
        t.expectTrue(ReminderLogic.isOverdue(item, now: now), "overdue past+not done")
        let doneItem = TodoItem(title: "x", dueDate: Date(timeIntervalSince1970: 500), isDone: true)
        t.expectFalse(ReminderLogic.isOverdue(doneItem, now: now), "not overdue when done")
        let futureItem = TodoItem(title: "x", dueDate: Date(timeIntervalSince1970: 5_000))
        t.expectFalse(ReminderLogic.isOverdue(futureItem, now: now), "not overdue when future")
    }
}
```

- [ ] **Step 2: Run tests, verify they fail** — `swift run KashTasksTests` → type error: `tasksToFire` expects `Set<UUID>`, got `[UUID: Date]`.

- [ ] **Step 3: Implement** — overwrite `Sources/KashTasksCore/ReminderLogic.swift`:

```swift
import Foundation

public enum ReminderLogic {
    /// Tasks whose due time passed while the app was running and that have not been
    /// notified for their *current* due date. `notified` maps a task id to the dueDate
    /// value it last fired for, so changing a due date (snooze / reschedule / recurrence)
    /// re-arms the reminder.
    public static func tasksToFire(
        _ items: [TodoItem],
        now: Date,
        appStart: Date,
        notified: [UUID: Date]
    ) -> [TodoItem] {
        items.filter { item in
            guard let due = item.dueDate, !item.isDone else { return false }
            guard due >= appStart && due <= now else { return false }
            return notified[item.id] != due
        }
    }

    /// Past-due and not completed — used for the red "missed/overdue" indicator in the UI.
    public static func isOverdue(_ item: TodoItem, now: Date) -> Bool {
        guard let due = item.dueDate, !item.isDone else { return false }
        return due < now
    }
}
```

- [ ] **Step 4: Tests will not fully pass yet** — the scheduler (`ReminderScheduler.swift`) still passes a `Set`. That's compiled in the executable target, not the test target, so `swift run KashTasksTests` builds only `KashTasksCore` + tests and should pass. Verify: `swift run KashTasksTests` → "✅ All checks passed". (If `swift build` is run it will fail until Task 6; that's expected and fixed there.)

- [ ] **Step 5: Commit**

```bash
git add Sources/KashTasksCore/ReminderLogic.swift Sources/KashTasksTests/ReminderLogicTests.swift
git commit -m "feat: track notified reminders by due date to support re-arming"
```

---

### Task 4: TaskStore recurrence-aware completion + snooze/reschedule

**Files:**
- Modify: `Sources/KashTasksCore/TaskStore.swift`
- Create: `Sources/KashTasksTests/TaskStoreMutationTests.swift`
- Modify: `Sources/KashTasksTests/main.swift`

- [ ] **Step 1: Write the failing tests** — `Sources/KashTasksTests/TaskStoreMutationTests.swift`:

```swift
import Foundation
import KashTasksCore

func runTaskStoreMutationTests(_ t: TestRunner) {
    func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("kashtasks-mut-\(UUID().uuidString).json")
    }

    // complete a non-recurring task -> marked done
    do {
        let url = tempURL(); defer { try? FileManager.default.removeItem(at: url) }
        let store = TaskStore(fileURL: url)
        let item = TodoItem(title: "once", dueDate: Date(timeIntervalSince1970: 100))
        store.add(item)
        store.complete(item.id, now: Date(timeIntervalSince1970: 200))
        t.expectEqual(store.items.first?.isDone, true, "non-recurring complete -> done")
    }

    // complete a recurring dated task -> rolls forward, stays open
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

    // complete a recurring task with NO dueDate -> advances from `now`
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

    // snooze sets due = now + interval and clears done
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

    // reschedule sets the due date and clears done
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

    // toggleDone on a recurring open task rolls it forward (does not mark done)
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
```

- [ ] **Step 2: Add the call** to `main.swift` — `runTaskStoreMutationTests(t)` before `t.summarize()`.

- [ ] **Step 3: Run tests, verify they fail** — `swift run KashTasksTests` → "value of type 'TaskStore' has no member 'complete'".

- [ ] **Step 4: Implement** — in `Sources/KashTasksCore/TaskStore.swift`, replace the existing `toggleDone(_:)` method and add the new methods. The full replacement for the mutation section (keep `add`, `update`, `delete`, `load`, `save` as-is):

```swift
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
            if let next = Recurrence.nextDate(after: base, rule: item.recurrence) {
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
```

Note: the existing `toggleDone` (which used `items[index].isDone.toggle()`) is being replaced by the version above. Make sure there is only one `toggleDone` after editing.

- [ ] **Step 5: Run tests, verify pass** — `swift run KashTasksTests` → "✅ All checks passed".

- [ ] **Step 6: Commit**

```bash
git add Sources/KashTasksCore/TaskStore.swift Sources/KashTasksTests/TaskStoreMutationTests.swift Sources/KashTasksTests/main.swift
git commit -m "feat: recurrence-aware completion plus snooze and reschedule in TaskStore"
```

---

### Task 5: NotificationManager (delegate, categories, actions)

**Files:**
- Create: `Sources/KashTasks/NotificationManager.swift`

No unit tests (system glue); verified by build + manual. Built before the scheduler change so the scheduler can reference `NotificationManager.categoryID`.

- [ ] **Step 1: Implement** — `Sources/KashTasks/NotificationManager.swift`:

```swift
import Foundation
import UserNotifications
import KashTasksCore

@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let categoryID = "TASK_DUE"

    private let store: TaskStore

    init(store: TaskStore) {
        self.store = store
        super.init()
    }

    /// Become the delegate and register the actionable category.
    func register() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let done = UNNotificationAction(identifier: "DONE", title: "Done", options: [])
        let snooze = UNNotificationAction(identifier: "SNOOZE", title: "Snooze 10 min", options: [])
        let tomorrow = UNNotificationAction(identifier: "TOMORROW", title: "Tomorrow 9 AM", options: [])
        let category = UNNotificationCategory(
            identifier: Self.categoryID,
            actions: [done, snooze, tomorrow],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    // Show banners even while the app is frontmost.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let actionID = response.actionIdentifier
        Task { @MainActor in
            self.handle(actionID: actionID, userInfo: userInfo)
            completionHandler()
        }
    }

    private func handle(actionID: String, userInfo: [AnyHashable: Any]) {
        guard let idString = userInfo["taskId"] as? String,
              let id = UUID(uuidString: idString) else { return }
        switch actionID {
        case "DONE":
            store.complete(id)
        case "SNOOZE":
            store.snooze(id, by: 600)
        case "TOMORROW":
            store.reschedule(id, to: Self.tomorrowMorning())
        default:
            break // plain tap / dismiss
        }
    }

    private static func tomorrowMorning() -> Date {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return cal.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }
}
```

- [ ] **Step 2: Verify it compiles** — `swift build`. Expected: still fails ONLY if other files reference it; on its own this file compiles. Run `swift build` and confirm `NotificationManager.swift` compiles (the build may still succeed entirely at this point). If `swift build` succeeds: `Build complete!`.

- [ ] **Step 3: Commit**

```bash
git add Sources/KashTasks/NotificationManager.swift
git commit -m "feat: add NotificationManager with Done/Snooze/Tomorrow actions"
```

---

### Task 6: Update ReminderScheduler for [UUID: Date] + category/userInfo

**Files:**
- Modify: `Sources/KashTasks/ReminderScheduler.swift`

- [ ] **Step 1: Implement** — overwrite `Sources/KashTasks/ReminderScheduler.swift`:

```swift
import Foundation
import Combine
import UserNotifications
import KashTasksCore

@MainActor
final class ReminderScheduler: ObservableObject {
    private let store: TaskStore
    private let appStart: Date
    private var notified: [UUID: Date] = [:]
    private var timer: Timer?
    private var cancellable: AnyCancellable?

    init(store: TaskStore, appStart: Date = Date()) {
        self.store = store
        self.appStart = appStart
    }

    func start() {
        // Idempotent: start() may be called more than once.
        guard timer == nil else { return }

        cancellable = store.$items
            .sink { [weak self] _ in
                Task { @MainActor in self?.evaluate() }
            }

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
            notified[item.id] = item.dueDate
            post(item)
        }
    }

    private func post(_ item: TodoItem) {
        let content = UNMutableNotificationContent()
        content.title = item.title
        content.body = item.notes.isEmpty ? "Task due now" : item.notes
        content.sound = .default
        content.categoryIdentifier = NotificationManager.categoryID
        content.userInfo = ["taskId": item.id.uuidString]

        let request = UNNotificationRequest(
            identifier: item.id.uuidString,
            content: content,
            trigger: nil
        )
        let title = item.title
        Task {
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                NSLog("KashTasks: failed to deliver notification for \(title): \(error)")
            }
        }
    }
}
```

- [ ] **Step 2: Verify build** — `swift build` → `Build complete!`.

- [ ] **Step 3: Run full test suite** — `swift run KashTasksTests` → "✅ All checks passed".

- [ ] **Step 4: Commit**

```bash
git add Sources/KashTasks/ReminderScheduler.swift
git commit -m "feat: scheduler tracks notified by due date and tags notifications for actions"
```

---

### Task 7: HotkeyManager (Carbon ⌃⌥Space)

**Files:**
- Create: `Sources/KashTasks/HotkeyManager.swift`

No unit tests (system glue). The C-callback ↔ Swift bridge is the tricky part; build-iterate as needed.

- [ ] **Step 1: Implement** — `Sources/KashTasks/HotkeyManager.swift`:

```swift
import Foundation
import Carbon.HIToolbox

/// Registers a single global hot key (⌃⌥Space) via the Carbon API, which works
/// system-wide without Accessibility permission. Calls `handler` on each press.
@MainActor
final class HotkeyManager {
    static let shared = HotkeyManager()

    private var handler: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var installed = false

    func register(handler: @escaping () -> Void) {
        self.handler = handler

        if !installed {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                          eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
                Task { @MainActor in HotkeyManager.shared.handler?() }
                return noErr
            }, 1, &eventType, nil, nil)
            installed = true
        }

        let hotKeyID = EventHotKeyID(signature: OSType(0x4B415348), id: 1) // 'KASH'
        let modifiers = UInt32(controlKey | optionKey)
        let keyCode = UInt32(kVK_Space) // 49
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                                         GetApplicationEventTarget(), 0, &ref)
        if status == noErr {
            hotKeyRef = ref
        } else {
            NSLog("KashTasks: failed to register hotkey (status \(status))")
        }
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }
}
```

- [ ] **Step 2: Verify build** — `swift build`. If the C function-pointer closure errors under Swift 6 (it must be a non-capturing closure — the body above only references the global `HotkeyManager.shared`, so it is non-capturing), resolve minimally while keeping behavior. Expected: `Build complete!`.

- [ ] **Step 3: Commit**

```bash
git add Sources/KashTasks/HotkeyManager.swift
git commit -m "feat: add global hotkey manager (Control+Option+Space via Carbon)"
```

---

### Task 8: Quick-capture panel + view

**Files:**
- Create: `Sources/KashTasks/QuickCapture.swift`

No unit tests (UI). Contains both the SwiftUI view and the NSPanel controller.

- [ ] **Step 1: Implement** — `Sources/KashTasks/QuickCapture.swift`:

```swift
import SwiftUI
import AppKit
import KashTasksCore

/// The minimal capture field shown by the global hotkey.
struct QuickCaptureView: View {
    @ObservedObject var store: TaskStore
    var onClose: () -> Void

    @State private var title = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(Theme.accent)
            TextField("Add a task…", text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .focused($focused)
                .onSubmit(add)
            Text("⮐")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(width: 460)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.08)))
        .onAppear { focused = true }
        .onExitCommand(perform: onClose) // Esc
    }

    private func add() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { onClose(); return }
        store.add(TodoItem(title: trimmed))
        title = ""
        onClose()
    }
}

/// Owns the floating panel that hosts QuickCaptureView.
@MainActor
final class QuickCaptureController {
    private let store: TaskStore
    private var panel: NSPanel?

    init(store: TaskStore) {
        self.store = store
    }

    func show() {
        if panel == nil { panel = makePanel() }
        guard let panel else { return }
        positionTopCenter(panel)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 60),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.worksWhenModal = true

        let root = QuickCaptureView(store: store, onClose: { [weak self] in self?.close() })
        let hosting = NSHostingView(rootView: root)
        hosting.frame = panel.contentLayoutRect
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        return panel
    }

    private func positionTopCenter(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let frame = panel.frame
        let x = screen.frame.midX - frame.width / 2
        let y = screen.frame.maxY - frame.height - 160
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
```

Note: `NSPanel` with `.nonactivatingPanel` can become key for text entry; combined with
`NSApp.activate` the field receives focus. `hidesOnDeactivate` dismisses it when the user
clicks elsewhere.

- [ ] **Step 2: Verify build** — `swift build` → `Build complete!`. (`Theme.accent` comes from `DesignSystem.swift`.)

- [ ] **Step 3: Commit**

```bash
git add Sources/KashTasks/QuickCapture.swift
git commit -m "feat: add global quick-capture panel"
```

---

### Task 9: Composer + row recurrence UI

**Files:**
- Modify: `Sources/KashTasks/TaskComposer.swift`
- Modify: `Sources/KashTasks/TaskRow.swift`

- [ ] **Step 1: Add recurrence to the composer** — in `Sources/KashTasks/TaskComposer.swift`:

Add state near the other `@State` properties:

```swift
    @State private var recurrence: Recurrence = .none
```

Add a recurrence `Picker` in the detail `HStack` (after the priority `Picker`):

```swift
                Picker("", selection: $recurrence) {
                    ForEach(Recurrence.allCases, id: \.self) { r in
                        Text(r == .none ? "No repeat" : r.label).tag(r)
                    }
                }
                .labelsHidden()
                .frame(width: 120)
```

Include `recurrence` when building the item in `add()`:

```swift
        let item = TodoItem(
            title: title.trimmingCharacters(in: .whitespaces),
            notes: notes,
            priority: priority,
            tag: tag.trimmingCharacters(in: .whitespaces),
            dueDate: hasDue ? due : nil,
            recurrence: recurrence
        )
```

And reset it in the post-add cleanup (where `priority = .medium` etc. are reset):

```swift
        recurrence = .none
```

- [ ] **Step 2: Add a repeat glyph to the row** — in `Sources/KashTasks/TaskRow.swift`, inside the title `HStack(spacing: 6)` (after `PriorityPill`):

```swift
                    if item.recurrence != .none {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .help(item.recurrence.label)
                    }
```

- [ ] **Step 3: Verify build** — `swift build` → `Build complete!`.

- [ ] **Step 4: Commit**

```bash
git add Sources/KashTasks/TaskComposer.swift Sources/KashTasks/TaskRow.swift
git commit -m "feat: recurrence picker in composer and repeat glyph in task rows"
```

---

### Task 10: Wire everything in KashTasksApp

**Files:**
- Modify: `Sources/KashTasks/KashTasksApp.swift`

- [ ] **Step 1: Implement** — overwrite `Sources/KashTasks/KashTasksApp.swift`:

```swift
import SwiftUI
import AppKit
import UserNotifications
import ServiceManagement
import KashTasksCore

@main
struct KashTasksApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var store: TaskStore
    @StateObject private var scheduler: ReminderScheduler

    private let notifications: NotificationManager
    private let quickCapture: QuickCaptureController

    init() {
        let store = TaskStore(fileURL: AppPaths.tasksFile)
        _store = StateObject(wrappedValue: store)

        let scheduler = ReminderScheduler(store: store)
        _scheduler = StateObject(wrappedValue: scheduler)

        let notifications = NotificationManager(store: store)
        self.notifications = notifications
        let quickCapture = QuickCaptureController(store: store)
        self.quickCapture = quickCapture

        // Start subsystems (init runs on the main actor for a SwiftUI App).
        scheduler.start()
        notifications.register()
        HotkeyManager.shared.register { quickCapture.show() }
    }

    var body: some Scene {
        MenuBarExtra("KashTasks", systemImage: "checklist") {
            MenuBarView()
                .environmentObject(store)
        }
        .menuBarExtraStyle(.window)

        Window("KashTasks Dashboard", id: "dashboard") {
            DashboardView()
                .environmentObject(store)
        }
        .defaultSize(width: 720, height: 580)
        .windowResizability(.contentMinSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task {
            do {
                let granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound])
                NSLog("KashTasks: notifications granted=\(granted)")
            } catch {
                NSLog("KashTasks: notif auth error \(error)")
            }
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

- [ ] **Step 2: Verify build** — `swift build` → `Build complete!`.

- [ ] **Step 3: Run full test suite** — `swift run KashTasksTests` → "✅ All checks passed".

- [ ] **Step 4: Commit**

```bash
git add Sources/KashTasks/KashTasksApp.swift
git commit -m "feat: wire notifications, hotkey, and quick-capture into the app"
```

---

### Task 11: Bundle + manual verification

**Files:** none (build + manual).

- [ ] **Step 1: Full build + tests green** — `swift build` and `swift run KashTasksTests`.

- [ ] **Step 2: Bundle and relaunch**

```bash
./scripts/bundle.sh
pkill -f "KashTasks.app/Contents/MacOS/KashTasks" 2>/dev/null; sleep 1
open KashTasks.app
```

Confirm the process stays alive (no crash): `pgrep -f "KashTasks.app/Contents/MacOS/KashTasks"`.

- [ ] **Step 3: Manual checks** (interactive — requires the user):
  - From another app, press **⌃⌥Space** → capture panel appears; type a title + Enter → task added (verify in the dashboard).
  - Create a task due ~1 min out, app running → notification fires with **Done / Snooze 10 min / Tomorrow 9 AM**. Tap **Snooze** → due date moves to ~10 min later (visible in dashboard); a new notification fires then.
  - Create a **Daily** recurring task, complete it from the dashboard checkbox → it stays open with tomorrow's date and a repeat glyph.
  - Legacy check: existing tasks (added before this build) still appear (backward-compatible decode).

- [ ] **Step 4: Final commit (if any doc/state changes)**

```bash
git add -A && git commit -m "docs: record productivity-features manual verification" || echo "nothing to commit"
```

---

## Self-Review notes

- Spec coverage: quick-capture (Tasks 7, 8, 10), actionable notifications (Tasks 5, 6, 10),
  recurrence (Tasks 1, 2, 4, 9), `[UUID:Date]` re-arm change (Tasks 3, 6), backward-compatible
  decode (Task 2). All covered.
- Type consistency: `tasksToFire(..., notified: [UUID: Date])` defined in Task 3 and used in
  Task 6; `NotificationManager.categoryID` defined in Task 5 and used in Task 6;
  `store.complete/snooze/reschedule` defined in Task 4 and used in Task 5; `Theme.accent` /
  `QuickCaptureController.show()` / `HotkeyManager.shared.register` consistent across Tasks 8, 10.
- Test-target vs build-target nuance called out in Task 3 (tests build only Core; the executable
  scheduler is fixed in Task 6).
