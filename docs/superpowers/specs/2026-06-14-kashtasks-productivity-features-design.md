# KashTasks Productivity Features — Design Spec

**Date:** 2026-06-14
**Status:** Approved (ready for implementation planning)
**Builds on:** `2026-06-14-kashtasks-design.md` (base app) + the dashboard redesign.

## Overview

Three features that make KashTasks materially more productive:

1. **Global quick-capture** — a system-wide hotkey (⌃⌥Space) opens a small floating
   capture panel to add a task from any app.
2. **Actionable notifications** — reminder banners carry **Done / Snooze 10m / Tomorrow**
   actions, handled without opening the app.
3. **Recurrence** — tasks repeat (Daily / Weekdays / Weekly / Monthly); completing a
   recurring task rolls it forward to the next occurrence.

All local, no new third-party dependencies, builds under Command Line Tools only.

## Decisions (locked)

- Hotkey: **⌃⌥Space, fixed** (not user-rebindable in this version), via the Carbon
  `RegisterEventHotKey` API — works system-wide with **no Accessibility permission**.
- Recurrence set: **Daily / Weekdays / Weekly / Monthly**. Completing a recurring task
  **advances its due date** to the next occurrence and keeps it open (does not mark done).
- Notification actions: **Done**, **Snooze 10m**, **Tomorrow** (= next day 09:00 local).
- No natural-language parsing in this version.

## Core architectural change: notified tracking

The reminder scheduler currently tracks fired tasks as `Set<UUID>`. Change this to a
**`[UUID: Date]` map** of `id → the dueDate value we fired for`.

`ReminderLogic.tasksToFire` becomes: a task fires when it is not done, has a `dueDate` in
`(appStart, now]`, and `notified[id] != dueDate` (i.e. it has never fired, or its due date
has changed since it last fired).

This single change powers Snooze, Tomorrow, and recurrence re-arming — and also fixes the
previously-deferred limitation where editing a fired task's due date would not re-fire.

## Data model changes

### New `Recurrence` enum (KashTasksCore)

```
public enum Recurrence: String, Codable, CaseIterable, Sendable {
    case none, daily, weekdays, weekly, monthly
    var label: String   // "None", "Daily", "Weekdays", "Weekly", "Monthly"
}
```

Pure advance function (tested):

```
static func nextDate(after date: Date, rule: Recurrence, calendar: Calendar = .current) -> Date?
```

- `.none` → `nil`.
- `.daily` → +1 day.
- `.weekly` → +1 week.
- `.monthly` → +1 month (calendar handles month-end clamping).
- `.weekdays` → next day, skipping Saturday/Sunday (Fri → Mon).

Preserves the original clock time of `date`.

### `TodoItem` gains `recurrence`

Add `var recurrence: Recurrence` (default `.none`) with `init(...)` default. Because existing
`tasks.json` files have no `recurrence` key, add a **custom `init(from decoder:)`** that uses
`decodeIfPresent` for `recurrence` (defaulting to `.none`) while decoding all other fields
normally. Encoding stays synthesized-compatible (explicit `encode(to:)` matching keys).

## TaskStore additions (KashTasksCore)

- `complete(_ id: UUID)` — completion semantics:
  - If the item's `recurrence != .none` **and** it has a `dueDate`: advance `dueDate` via
    `Recurrence.nextDate(after: dueDate)`, keep `isDone == false` (rolls forward). If it has
    no `dueDate`, advance from "now" passed in by the caller (see note) — to keep the store
    testable and deterministic, `complete` takes `now: Date = Date()`.
  - Otherwise: set `isDone = true`.
- `snooze(_ id: UUID, by interval: TimeInterval, from now: Date = Date())` — sets
  `dueDate = now + interval`, `isDone = false`.
- `reschedule(_ id: UUID, to date: Date)` — sets `dueDate = date`, `isDone = false`.
- Existing `toggleDone` stays for the checkbox UI but is updated to route a
  not-done → done transition through the same recurrence-aware logic as `complete`
  (so checking off a recurring task also rolls it forward). Un-checking a non-recurring
  done task still works.

All mutations call `save()` as today.

## ReminderScheduler changes (executable)

- `notified` becomes `[UUID: Date]`.
- On firing, record `notified[item.id] = dueDate`.
- `post(_:)` attaches `content.categoryIdentifier = NotificationManager.categoryID` and
  `content.userInfo = ["taskId": item.id.uuidString]` so actions can resolve the task.
- Keep the async `add(_:)` call (no completion-handler closures — Swift 6 main-actor safety).

## NotificationManager (executable, new)

`@MainActor final class NotificationManager: NSObject, UNUserNotificationCenterDelegate`,
constructed with the `TaskStore`.

- `register()`:
  - Sets `UNUserNotificationCenter.current().delegate = self`.
  - Registers a category `"TASK_DUE"` with actions:
    - `DONE` ("Done"), `SNOOZE` ("Snooze 10 min"), `TOMORROW` ("Tomorrow 9 AM").
- `userNotificationCenter(_:willPresent:withCompletionHandler:)` → `[.banner, .sound]`
  (show while foreground).
- `userNotificationCenter(_:didReceive:withCompletionHandler:)`:
  - Resolve `taskId` from `response.notification.request.content.userInfo`.
  - `DONE` → `store.complete(id)`; `SNOOZE` → `store.snooze(id, by: 600)`;
    `TOMORROW` → `store.reschedule(id, to: <tomorrow 09:00 local>)`;
    default tap → no-op.
  - Mutations on the main actor; the scheduler re-arms automatically because the due date
    changed (the `[UUID:Date]` map).

"Tomorrow 9 AM" computed via `Calendar.current` (next day, `hour = 9, minute = 0`).

## HotkeyManager + quick-capture (executable, new)

### HotkeyManager (Carbon)
`@MainActor final class HotkeyManager` that:
- `register(handler: @escaping () -> Void)` installs a Carbon hot key for keycode `49`
  (Space) with modifiers `controlKey | optionKey` via `RegisterEventHotKey`, plus an
  `InstallEventHandler` for `kEventHotKeyPressed`.
- Uses a `static` shared reference so the C event-handler callback (which can't capture Swift
  context) can route back to the instance's stored handler.
- `unregister()` cleans up on teardown (best-effort).

### Quick-capture panel
- A controller `QuickCaptureController` owns a borderless, non-activating `NSPanel`
  (`.nonactivatingPanel`, floating window level, `canBecomeKey == true`) hosting an
  `NSHostingView` of `QuickCaptureView`.
- `toggle()` / `show()`: positions the panel near top-center, `NSApp.activate(...)`, makes it
  key so the field receives focus and typing.
- `QuickCaptureView`: a single focused `TextField`. **Enter** → `store.add(TodoItem(title:))`
  then close; **Esc** → close. Trimmed-empty input does nothing. Clean, minimal styling
  consistent with the design system.

## Composer change (executable)

`TaskComposer` gains a **Recurrence picker** (menu) alongside priority, defaulting to `None`.
The created `TodoItem` includes the selected `recurrence`. The dashboard `TaskRow` shows a
small repeat glyph (e.g. `arrow.triangle.2.circlepath`) when `recurrence != .none`.

## App wiring (KashTasksApp)

In `init()` (already main-actor): construct `store`, `scheduler`, `NotificationManager`,
`HotkeyManager`, `QuickCaptureController`. Start the scheduler. Register the notification
manager. Register the hotkey with a handler that calls `quickCapture.show()`.
(Login-item registration + notification authorization remain in `AppDelegate`.)

## Testing (via `swift run KashTasksTests`)

New/updated pure-logic tests:
- **RecurrenceTests:** `nextDate` for daily (+1d), weekly (+7d), monthly (+1 month incl.
  Jan 31 → Feb), weekdays (Fri → Mon, Wed → Thu), and `.none → nil`. Verify clock time preserved.
- **ReminderLogicTests (updated):** `[UUID:Date]` semantics — fires when unseen; does not
  fire when `notified[id] == dueDate`; **re-fires when the due date changed** since last fire;
  still respects appStart gating, done, and undated.
- **TaskStoreTests (added):** `complete` on a recurring dated task advances the due date and
  leaves it open; `complete` on a non-recurring task marks done; `snooze` sets due = now+interval
  and clears done; `reschedule` sets the due date; tolerant decode of legacy JSON without a
  `recurrence` key yields `.none`.

UI (hotkey panel, notification actions in the live notification center) verified manually.

## Manual verification

- Press ⌃⌥Space from another app → capture panel appears, type + Enter adds a task.
- Fire a reminder; banner shows Done / Snooze / Tomorrow; each acts correctly and the task's
  due date / state updates in the dashboard.
- Create a Daily recurring task due in ~1 min; complete it → it reappears with tomorrow's date.
- Legacy `tasks.json` (no `recurrence`) still loads.

## Out of scope (deferred)

Rebindable hotkey + Settings window; natural-language parsing; custom "every N" intervals;
per-occurrence history for recurring tasks (single rolling task only); subtasks.
