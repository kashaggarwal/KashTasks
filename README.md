# KashTasks

A native macOS **menu bar task tracker with reminders** — local-first, no accounts, no cloud.
Lives in your menu bar, stores everything on your Mac, and notifies you when tasks are due.

[![release](https://img.shields.io/github/v/release/kashaggarwal/KashTasks?sort=semver)](https://github.com/kashaggarwal/KashTasks/releases/latest)
![status: working](https://img.shields.io/badge/status-working-brightgreen)

## What's new in v2 — the "Aurora" dashboard

v2 is a ground-up redesign of the dashboard around a distinctive **deep-green aurora** look,
inspired by a custom UI reference rather than the usual list-app template:

- A **slowly drifting aurora gradient** (a true `MeshGradient` on macOS 15+, with a static
  fallback on older systems) — alive but calm, and fully opaque so it looks the same over any
  window or wallpaper.
- A **two-card layout**: a subdued dark **hero card** on top (app glyph, date, an inline
  stat strip, and a collapsible composer with a gradient "Add" pill) sitting above a highlighted
  **aurora list panel** that holds the filters and your grouped tasks.
- An **inline stat strip** (Open · Due Today · Overdue · Done) instead of boxed tiles, a
  **pill filter bar**, and the signature **circular-arrow gradient CTA** from the reference.

The data model, reminders, hotkey, and notifications are unchanged from v1 — this release is the UI.

## Features

- **Menu bar popover** — quick-add, live open/overdue counts, and your next tasks at a glance.
- **Aurora dashboard window** — a dark hero card with an inline stat strip
  (Open / Due Today / Overdue / Done) and a collapsible composer, above an aurora-highlighted
  panel with pill filters and tag-grouped task rows (priority pills, due chips).
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

- macOS 13 (Ventura) or later. The aurora dashboard uses a `MeshGradient` on **macOS 15+** and
  automatically falls back to a static layered gradient on macOS 13–14.
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
│   │   ├── DashboardView.swift   #   aurora dashboard: hero card + list panel
│   │   ├── Aurora.swift          #   drifting MeshGradient, dark canvas, AuroraCard, window chrome
│   │   ├── DesignSystem.swift    #   theme tokens (aurora palette), pills, chips, StatItem, CTA
│   │   ├── TaskRow.swift, TaskComposer.swift   # row + collapsible composer
│   │   ├── ReminderScheduler.swift   # timer + notification delivery
│   │   ├── NotificationManager.swift # actionable-notification handling
│   │   ├── HotkeyManager.swift   #   global ⌃⌥Space (Carbon)
│   │   └── QuickCapture.swift    #   floating capture panel
│   └── KashTasksTests/           # executable test runner (no XCTest)
├── docs/superpowers/             # design specs + implementation plans
└── docs/mockups/                 # design-exploration HTML mockups
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
