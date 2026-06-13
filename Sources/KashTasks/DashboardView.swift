import SwiftUI
import KashTasksCore

enum TaskFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case today = "Today"
    case overdue = "Overdue"
    case done = "Done"
    var id: String { rawValue }
}

/// The standalone dashboard window: stat cards, filter bar, grouped task list,
/// and the full composer. Opened from the menu-bar popover.
struct DashboardView: View {
    @EnvironmentObject var store: TaskStore
    @State private var filter: TaskFilter = .all

    private var now: Date { Date() }

    private var openCount: Int { store.items.filter { !$0.isDone }.count }
    private var doneCount: Int { store.items.filter { $0.isDone }.count }
    private var overdueCount: Int { store.items.filter { ReminderLogic.isOverdue($0, now: now) }.count }
    private var todayCount: Int {
        store.items.filter { item in
            guard !item.isDone, let due = item.dueDate else { return false }
            return Calendar.current.isDateInToday(due)
        }.count
    }

    private var filteredGroups: [TaskSorting.Group] {
        let items: [TodoItem]
        switch filter {
        case .all:
            items = store.items.filter { !$0.isDone }
        case .today:
            items = store.items.filter { item in
                guard !item.isDone, let due = item.dueDate else { return false }
                return Calendar.current.isDateInToday(due)
            }
        case .overdue:
            items = store.items.filter { ReminderLogic.isOverdue($0, now: now) }
        case .done:
            items = store.items.filter { $0.isDone }
        }
        return TaskSorting.grouped(items)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)
            filterBar
            taskList
            Divider().opacity(0.5)
            TaskComposer()
        }
        .frame(minWidth: 640, minHeight: 540)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "checklist")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Text("Dashboard")
                    .font(.system(size: 19, weight: .bold))
                Spacer()
                Text(now.formatted(date: .complete, time: .omitted))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                StatCard(value: openCount, label: "Open", systemImage: "tray.full", tint: Theme.accent)
                StatCard(value: todayCount, label: "Due Today", systemImage: "sun.max", tint: Color(red: 0.95, green: 0.62, blue: 0.20))
                StatCard(value: overdueCount, label: "Overdue", systemImage: "exclamationmark.triangle", tint: Color(red: 0.93, green: 0.34, blue: 0.31))
                StatCard(value: doneCount, label: "Done", systemImage: "checkmark.seal", tint: Color(red: 0.30, green: 0.72, blue: 0.45))
            }
        }
        .padding(18)
    }

    private var filterBar: some View {
        Picker("", selection: $filter) {
            ForEach(TaskFilter.allCases) { f in
                Text(f.rawValue).tag(f)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var taskList: some View {
        ScrollView {
            if filteredGroups.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(filteredGroups, id: \.tag) { group in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(group.tag.uppercased())
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(0.7)
                                    .foregroundStyle(.secondary)
                                Text("\(group.items.count)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.primary.opacity(0.07), in: Capsule())
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 2)

                            ForEach(group.items) { item in
                                TaskRow(item: item)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .animation(.easeOut(duration: 0.2), value: store.items)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: filter == .done ? "checkmark.circle" : "sparkles")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.secondary)
            Text(emptyTitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 70)
    }

    private var emptyTitle: String {
        switch filter {
        case .all:     return "All clear — add a task below"
        case .today:   return "Nothing due today"
        case .overdue: return "No overdue tasks 🎉"
        case .done:    return "No completed tasks yet"
        }
    }
}
