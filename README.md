# KashTasks

A native macOS **menu bar task tracker with reminders** — local-first, no accounts, no cloud.
Lives in your menu bar, stores everything on your Mac, and notifies you when tasks are due.

![status: working](https://img.shields.io/badge/status-working-brightgreen)

## Features

- **Menu bar popover** — quick-add, live open/overdue counts, and your next tasks at a glance.
- **Dashboard window** — stat cards (Open / Due Today / Overdue / Done), filters, tag-grouped
  task rows with priority pills and due chips, and a full composer.
- **Global quick-capture** — press **⌃⌥Space** (Control+Option+Space) from *any* app to pop a
  capture field, type a task, press Enter. No Accessibility permission required.
- **Reminders** — native macOS notifications fire once at a task's due time. Tasks that came due
  while the app was closed are shown as overdue (red) rather than firing a late notification.
- **Actionable notifications** — each reminder banner has **Done**, **Snooze 10 min**, and
  **Tomorrow 9 AM** buttons; act without opening the app.
- **Recurring tasks** — Daily / Weekdays / Weekly / Monthly. Completing a recurring task rolls it
  forward to the next occurrence (skipping any already-past occurrences).
- **Launch at login** — registers itself so reminders are always active.

## Requirements

- macOS 13 (Ventura) or later.
- **Xcode is NOT required.** Only the Xcode **Command Line Tools** (`xcode-select --install`) and
  Swift 6.x. The project builds entirely from the command line.

## Build & run

```bash
# Build the app bundle (compiles release + wraps + ad-hoc signs KashTasks.app)
./scripts/bundle.sh

# Install and launch
cp -R KashTasks.app /Applications/
open /Applications/KashTasks.app
```

On first launch, approve the notification permission prompt. For the most reliable notifications
and login-item registration, run it from `/Applications` (not from this folder).

To iterate during development without bundling:

```bash
swift build            # compile
swift run KashTasks    # run the app target directly
```

## Tests

This project does **not** use XCTest (it isn't available with Command Line Tools only). Tests are a
small executable target with a custom assertion harness:

```bash
swift run KashTasksTests
```

It exits 0 and prints `✅ All checks passed (N checks)` on success, or lists failures and exits
non-zero.

## Where your data lives

- **Tasks:** `~/Library/Application Support/KashTasks/tasks.json` (plain JSON; created on first run).
  If the file ever becomes unreadable, it is backed up to `tasks.json.corrupt` rather than wiped.

## Project layout

```
KashTasks/
├── Package.swift                 # Swift package manifest (macOS 13+, 3 targets)
├── scripts/bundle.sh             # build + bundle + ad-hoc sign -> KashTasks.app
├── Sources/
│   ├── KashTasksCore/            # pure, unit-tested logic
│   │   ├── TodoItem.swift        #   task model + Priority (+ backward-compatible decoder)
│   │   ├── Recurrence.swift      #   repeat rules + next-occurrence math
│   │   ├── TaskStore.swift       #   JSON persistence + complete/snooze/reschedule
│   │   ├── TaskSorting.swift     #   group-by-tag + priority/due sorting
│   │   └── ReminderLogic.swift   #   "should fire / is overdue" decisions
│   ├── KashTasks/                # the app (SwiftUI + AppKit)
│   │   ├── KashTasksApp.swift    #   @main: menu bar + dashboard scenes, wiring
│   │   ├── MenuBarView.swift     #   compact popover
│   │   ├── DashboardView.swift   #   dashboard window
│   │   ├── DesignSystem.swift    #   shared colors, pills, chips, stat cards
│   │   ├── TaskRow.swift, TaskComposer.swift
│   │   ├── ReminderScheduler.swift   # timer + notification delivery
│   │   ├── NotificationManager.swift # actionable-notification handling
│   │   ├── HotkeyManager.swift   #   global ⌃⌥Space (Carbon)
│   │   └── QuickCapture.swift    #   floating capture panel
│   └── KashTasksTests/           # executable test runner (no XCTest)
└── docs/superpowers/             # design specs + implementation plans
```

## Design notes

- Reminders fire **once** per due date. Changing a task's due date (snooze, reschedule, or a
  recurring roll-forward) re-arms the reminder.
- The reminder scheduler runs while the app is open (it's a menu bar app). Keep it running — or
  let it launch at login — for reminders to fire.

## Contributing / extending

See `AGENTS.md` for conventions, constraints, and the build/test workflow if you (or an AI agent)
are modifying this project. Design specs and step-by-step plans for past work are in
`docs/superpowers/`.
