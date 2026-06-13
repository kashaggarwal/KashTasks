import SwiftUI
import AppKit
import KashTasksCore

/// Compact menu-bar popover: quick capture + a glance at what's next,
/// with a button into the full dashboard window.
struct MenuBarView: View {
    @EnvironmentObject var store: TaskStore
    @Environment(\.openWindow) private var openWindow

    @State private var quickTitle = ""

    private var now: Date { Date() }
    private var openCount: Int { store.items.filter { !$0.isDone }.count }
    private var overdueCount: Int { store.items.filter { ReminderLogic.isOverdue($0, now: now) }.count }

    /// Next few open tasks, soonest/highest-priority first.
    private var upcoming: [TodoItem] {
        TaskSorting.sortedWithin(store.items.filter { !$0.isDone })
    }

    private var canAdd: Bool { !quickTitle.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            header
            quickAdd
            list
            Divider().opacity(0.5)
            footer
        }
        .padding(13)
        .frame(width: 308)
    }

    private var header: some View {
        HStack(spacing: 7) {
            Image(systemName: "checklist")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.accent)
            Text("KashTasks")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            if overdueCount > 0 {
                Text("\(overdueCount) overdue")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(red: 0.93, green: 0.34, blue: 0.31))
            }
            Text("\(openCount) open")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var quickAdd: some View {
        HStack(spacing: 6) {
            TextField("Quick add a task…", text: $quickTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .onSubmit(addQuick)
            Button(action: addQuick) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(canAdd ? Theme.accent : Color.secondary.opacity(0.5))
            }
            .buttonStyle(PressableStyle(scale: 0.88))
            .disabled(!canAdd)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private var list: some View {
        if upcoming.isEmpty {
            HStack {
                Spacer()
                Text("No open tasks")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.vertical, 10)
        } else {
            VStack(spacing: 2) {
                ForEach(upcoming.prefix(5)) { item in
                    compactRow(item)
                }
            }
            if upcoming.count > 5 {
                Text("+\(upcoming.count - 5) more")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 2)
            }
        }
    }

    private func compactRow(_ item: TodoItem) -> some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.easeOut(duration: 0.15)) { store.toggleDone(item.id) }
            } label: {
                Image(systemName: "circle")
                    .font(.system(size: 13))
                    .foregroundStyle(item.priority.color.opacity(0.9))
            }
            .buttonStyle(PressableStyle(scale: 0.88))

            Text(item.title)
                .font(.system(size: 12))
                .lineLimit(1)

            Spacer(minLength: 6)

            if let due = item.dueDate {
                Text(due.formatted(.relative(presentation: .named)))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(ReminderLogic.isOverdue(item, now: now)
                                     ? Color(red: 0.93, green: 0.34, blue: 0.31) : .secondary)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }

    private var footer: some View {
        HStack {
            FilledButton(title: "Open Dashboard", systemImage: "square.grid.2x2", action: openDashboard)
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private func addQuick() {
        guard canAdd else { return }
        withAnimation(.easeOut(duration: 0.18)) {
            store.add(TodoItem(title: quickTitle.trimmingCharacters(in: .whitespaces)))
        }
        quickTitle = ""
    }

    private func openDashboard() {
        openWindow(id: "dashboard")
        // LSUIElement apps don't auto-activate; bring the window to the front.
        NSApp.activate(ignoringOtherApps: true)
    }
}
