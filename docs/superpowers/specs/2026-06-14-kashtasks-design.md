# KashTasks — Design Spec

**Date:** 2026-06-14
**Status:** Approved (ready for implementation planning)

## Overview

KashTasks is a native macOS menu bar app for tracking tasks and getting reminders.
It runs locally, stores data on disk as JSON, and fires native macOS notifications
when a task is due. It lives in the menu bar (no Dock icon) and auto-launches at login.

Built with Swift/SwiftUI via Swift Package Manager — no full Xcode IDE required, only
the Command Line Tools (Swift 6.1.2 confirmed available).

## Goals

- Quick task capture and review from the menu bar.
- Reliable native notifications at a task's due time.
- Zero external services; everything local.
- Lean, shippable v1.

## Non-Goals (v1, deferred)

- Recurring reminders.
- Lead-time / "X minutes before" warnings.
- iCloud / iPhone sync.
- Drag-to-reorder, search.

## Task Model

A `Task` holds:

| Field      | Type            | Notes                                  |
|------------|-----------------|----------------------------------------|
| `id`       | UUID            | Stable identity.                       |
| `title`    | String          | Required.                              |
| `notes`    | String          | Optional free text.                    |
| `priority` | enum            | `.high` / `.medium` / `.low`.          |
| `tag`      | String          | Free-text list/category name.          |
| `dueDate`  | Date?           | Optional; drives reminders.            |
| `isDone`   | Bool            | Completion flag.                       |

## Architecture (4 focused units)

### 1. `Task` model + `TaskStore`
- `Task`: `Codable`, `Identifiable` struct as above.
- `TaskStore`: `ObservableObject`, single source of truth. Loads/saves `[Task]` as JSON to
  `~/Library/Application Support/KashTasks/tasks.json`. Exposes add/update/complete/delete.
  Writes on every mutation. Creates the directory/file on first run.

### 2. `MenuBarView` (SwiftUI)
- Popover UI shown when the menu bar icon is clicked.
- Lists tasks grouped by `tag`, sorted by priority (High→Low) then `dueDate` (soonest first).
- Each row: completion checkbox, title, due date label, priority color dot, delete control.
- Inline "Add task" affordance: title field, date picker (optional), priority menu, tag field, notes field.

### 3. `ReminderScheduler`
- Observes `TaskStore`. Because the app is always running, it maintains a timer and fires a
  notification the moment a task's `dueDate` is reached, via `UNUserNotificationCenter`.
- Tracks already-notified task IDs to prevent duplicate fires.
- Re-arms upcoming reminders on launch from the reloaded store.

### 4. App entry (`KashTasksApp` / `AppDelegate`)
- Sets up the `MenuBarExtra` (SwiftUI) with `LSUIElement = true` (no Dock icon).
- Requests notification permission on first launch.
- Registers login item via `SMAppService.mainApp`.

## Data Flow

Add/edit in `MenuBarView` → mutate `TaskStore` → store writes JSON + publishes change →
`ReminderScheduler` re-reads upcoming due dates and re-arms its timer.

Restart-safe: on launch the store reloads JSON and the scheduler re-arms still-future reminders.

## Reminders Behavior

- Fire **once, at the due time**.
- **Missed handling:** if a task's `dueDate` already passed while the app was closed, it does
  NOT fire a late notification. Instead it is shown in the list as "missed" (red indicator).
  A due date in the future is armed normally.
- **Known limitation:** a reminder fires at most once per task per app session. If you edit an
  already-fired task's due date to a new time, it will not re-fire in the same session
  (it re-arms on next launch). Re-arming on due-date edit (snooze/reschedule) is a deferred
  enhancement.

## Build & Packaging

- Swift Package Manager builds a release executable: `swift build -c release`.
- A shell/`make` script wraps the binary into `KashTasks.app`:
  - Generated `Info.plist` with bundle id `com.kashish.kashtasks`, `LSUIElement = true`,
    and notification usage entries.
  - Ad-hoc code-sign: `codesign --sign - --force --deep KashTasks.app` (enables notifications).
- Output to `~/Downloads/KashTasks/` (project convention).
- User drags `KashTasks.app` to `/Applications` (or runs in place). First launch requests
  notification permission and registers the login item.

## Testing

> **Toolchain note:** Command Line Tools ship no XCTest/swift-testing (those require full
> Xcode), so `swift test` cannot run. Tests therefore live in a small executable target
> `KashTasksTests` with a minimal assertion harness, run via `swift run KashTasksTests`,
> which exits non-zero on failure. Same TDD discipline, CLT-compatible.

Unit tests (via `swift run KashTasksTests`) for the pure logic:
- `TaskStore`: JSON round-trip (encode/decode), add/update/complete/delete mutations.
- Sorting/grouping: group-by-tag, priority-then-dueDate ordering.
- `ReminderScheduler` decisions: "should notify now?", "missed vs upcoming" classification,
  duplicate-fire prevention.

UI is verified manually.

## Open Risks

- Notification permission for ad-hoc-signed local apps can require the app to be moved to
  `/Applications` and re-launched. Fallback if `UNUserNotificationCenter` is blocked:
  `osascript -e 'display notification …'`. Decided during implementation if needed.
