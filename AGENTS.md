# AGENTS.md — KashTasks

Guidance for AI agents (and humans) working on this repository. Read this before making changes.

## What this is

KashTasks is a **native macOS menu bar task tracker with reminders**, written in Swift 6 /
SwiftUI + AppKit, built with Swift Package Manager. It is local-first: tasks are stored as JSON on
disk, no network, no accounts.

## Hard constraints (do not violate)

1. **No Xcode. Command Line Tools only.** This machine has the Xcode Command Line Tools, not the
   full Xcode IDE. Therefore:
   - Build with `swift build`. Do **not** assume `xcodebuild` or an `.xcodeproj`.
   - **XCTest and swift-testing are unavailable.** Do not add XCTest tests or a `.testTarget` —
     they will fail to compile (`no such module 'XCTest'`). See the testing section below.
2. **UserNotifications: use async/await, never completion handlers from `@MainActor` code.**
   The completion-handler variants of `requestAuthorization` and `UNUserNotificationCenter.add`
   invoke their closures on a background queue; called from `@MainActor`-isolated code, Swift 6
   inserts an executor assertion that **crashes the app with SIGTRAP** (EXC_BREAKPOINT). Always use
   `try await UNUserNotificationCenter.current().requestAuthorization(...)` / `.add(request)` inside
   a `Task`. This bug already bit us once — see `git log` for "main-actor SIGTRAP".
3. **No Claude / AI attribution in commits, PRs, or releases.** Do not add "Generated with Claude
   Code" or `Co-Authored-By` lines. (User preference.)

## Build, run, test, package

```bash
swift build                 # compile (debug)
swift run KashTasks         # run the app target directly during development
swift run KashTasksTests    # run the test suite (see below)
./scripts/bundle.sh         # build release + wrap + ad-hoc sign -> ./KashTasks.app
```

`bundle.sh` produces `KashTasks.app` in the repo root with `LSUIElement=true` (menu bar app, no
Dock icon), bundle id `com.kashish.kashtasks`, ad-hoc signed so notifications work. Install with
`cp -R KashTasks.app /Applications/ && open /Applications/KashTasks.app`.

## Testing convention (important — no XCTest)

Tests live in the **`KashTasksTests` executable target** and use a tiny custom harness:

- `Sources/KashTasksTests/TestHarness.swift` defines `final class TestRunner` with:
  `expectEqual(_ actual:_ expected:_ context:)`, `expectTrue(_:_ context:)`,
  `expectFalse(_:_ context:)`, `expectLessThan`, `check`, and `summarize() -> Never`.
- Each group of tests is a free function `runXxxTests(_ t: TestRunner)` in its own file.
- `Sources/KashTasksTests/main.swift` calls each `runXxxTests(t)` then `t.summarize()`.
- Run with `swift run KashTasksTests`; it prints `✅ All checks passed (N checks)` and exits 0, or
  lists failures and exits non-zero.

**To add tests:** create `Sources/KashTasksTests/MyFeatureTests.swift` with
`func runMyFeatureTests(_ t: TestRunner) { ... }`, then add `runMyFeatureTests(t)` to `main.swift`
before `t.summarize()`.

Only **pure logic in `KashTasksCore`** is unit-tested. UI / system glue in the `KashTasks`
executable target (views, hotkey, notification handling, panels) is verified by `swift build` +
manual testing. After UI changes, **bundle and launch the app** and confirm it doesn't crash:

```bash
./scripts/bundle.sh
pkill -f "KashTasks.app/Contents/MacOS/KashTasks"; sleep 1; open KashTasks.app; sleep 4
pgrep -f "KashTasks.app/Contents/MacOS/KashTasks" && echo ALIVE || echo CRASHED
```
Test launching **twice** — some crashes (e.g. the notification SIGTRAP) only appear on the second
launch once permissions are already resolved. Crash reports land in
`~/Library/Logs/DiagnosticReports/KashTasks-*.ips`.

## Architecture

Two targets:

- **`KashTasksCore`** (library, pure + tested):
  - `TodoItem` — model (`id, title, notes, priority, tag, dueDate, isDone, recurrence`).
    Has a **custom `init(from:)`** so legacy `tasks.json` without a `recurrence` key still loads.
    If you add fields, keep decoding tolerant (`decodeIfPresent`) for backward compatibility.
  - `Priority`, `Recurrence` — enums (string-Codable, with `.label`).
  - `Recurrence.nextDate(after:rule:calendar:)` — pure next-occurrence math.
  - `TaskStore` — `ObservableObject`, single source of truth, JSON persistence to
    `~/Library/Application Support/KashTasks/tasks.json` (atomic write; corrupt file backed up to
    `.corrupt`, never silently wiped). Methods: `add/update/delete/toggleDone/complete/snooze/
    reschedule`. `complete`/`toggleDone` are **recurrence-aware** (rolls a recurring task forward
    past any past-due occurrences instead of marking it done).
  - `TaskSorting` — group by tag, sort by priority then due date.
  - `ReminderLogic` — `tasksToFire(_:now:appStart:notified:)` and `isOverdue`. `notified` is a
    **`[UUID: Date]`** map (id → due date last fired for) so changing a due date re-arms the
    reminder. A task fires only if its due date is in `(appStart, now]`, not done, and not already
    fired for that exact due date (no late-fire on launch).

- **`KashTasks`** (executable, app):
  - `KashTasksApp` — `@main`. Constructs the store, scheduler, `NotificationManager`,
    `QuickCaptureController`, and registers the hotkey **in `init()`** (runs on the main actor).
    Two scenes: `MenuBarExtra` (popover) + `Window(id: "dashboard")`.
  - `ReminderScheduler` — `@MainActor`; observes the store + a 15s timer; posts notifications via
    the async API; prunes its `notified` map to live task ids each tick.
  - `NotificationManager` — `UNUserNotificationCenterDelegate`; registers the `TASK_DUE` category
    with `DONE` / `SNOOZE` / `TOMORROW` actions and routes them to store mutations on the main actor.
  - `HotkeyManager` — global ⌃⌥Space via **Carbon `RegisterEventHotKey`** (no Accessibility
    permission). The C callback is non-capturing and dispatches to the main thread.
  - `QuickCapture` — a borderless floating `NSPanel` (uses a `KeyablePanel` subclass overriding
    `canBecomeKey` so the text field can focus) hosting a SwiftUI capture field.
  - `DesignSystem`, `MenuBarView`, `DashboardView`, `TaskRow`, `TaskComposer` — UI + shared visual
    vocabulary (priority colors, pills, due chips, stat cards, press-feedback button style).

## Conventions

- **TDD for `KashTasksCore`:** write the failing test in `KashTasksTests`, run it, implement, re-run.
- **Small, focused files**, one responsibility each. Follow existing patterns.
- **Commit per logical change** with a clear message; no AI attribution (see constraint 3).
- Current development branch: **`build-kashtasks`** (off `master`).
- Design specs + step-by-step implementation plans for completed work live in
  `docs/superpowers/specs/` and `docs/superpowers/plans/`. Add new ones there for substantial work.

## Known limitations / deferred ideas

- Hotkey is fixed (⌃⌥Space), not user-rebindable; no Settings window yet.
- No natural-language date parsing on input.
- Recurrence is the four fixed rules (Daily/Weekdays/Weekly/Monthly); no "every N days".
- Single rolling task per recurrence (no per-occurrence history).
- Candidate next features: rebindable hotkey + Settings, natural-language capture, subtasks,
  productivity insights, calendar/Reminders (EventKit) sync.
