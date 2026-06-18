# Changelog

All notable changes to KashTasks are documented here.

## v2.0.0 — Aurora dashboard

A ground-up redesign of the dashboard window. No data, reminder, hotkey, or notification behavior
changed — this release is purely the UI.

### Added
- **Aurora dashboard.** A deep-green, slowly drifting aurora gradient — a true `MeshGradient` on
  macOS 15+, with a static layered fallback on macOS 13–14. Fully opaque, so it reads the same over
  any window or wallpaper.
- **Two-card layout.** A subdued dark **hero card** (app glyph, "Today", date pill, an inline stat
  strip, and the composer) above a highlighted **aurora list panel** (pill filters + grouped tasks).
- **Inline stat strip** (`StatItem`) replacing the boxed stat tiles.
- **Collapsible composer.** Title field + Add pill by default; a toggle reveals tag / priority /
  repeat / due controls so the hero card stays compact.
- **Signature CTA.** A dark gradient "Add" pill with a circular-arrow badge, plus a pill filter bar.
- New `Aurora.swift` (mesh, dark canvas, `AuroraCard`, window chrome) and `Theme` design tokens
  (canvas, hero, aurora palette).

### Changed
- Dashboard foreground text is now light-on-dark throughout; the window is pinned to a dark
  appearance with a transparent, edge-to-edge title bar.

## v1.0.0 — Initial release

- Menu bar popover with quick-add and at-a-glance counts.
- Dashboard window with stats, filters, tag-grouped task rows, and a full composer.
- Global quick-capture hotkey (⌃⌥Space) via Carbon — no Accessibility permission.
- Local-first JSON storage; reminders via native notifications (fire-once, overdue on launch).
- Actionable notifications (Done / Snooze 10 min / Tomorrow 9 AM).
- Recurring tasks (Daily / Weekdays / Weekly / Monthly) with roll-forward on completion.
- Launch at login.
