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
        VStack(spacing: 14) {
            heroCard
            listPanel
        }
        .padding(.horizontal, 18)
        .padding(.top, 30)   // clear the traffic-light buttons under the transparent title bar
        .padding(.bottom, 18)
        .frame(minWidth: 660, minHeight: 600)
        .background(DashboardBackground())
    }

    // MARK: Hero card — banner glyph, identity, inline stat strip, composer/CTA.
    private var heroCard: some View {
        AuroraCard(cornerRadius: 26, dark: true) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 11) {
                    Image(systemName: "checklist")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.14), in: Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Today")
                            .font(.system(size: 21, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Your tasks at a glance")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer()
                    Text(now.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.horizontal, 11).padding(.vertical, 6)
                        .background(.white.opacity(0.10), in: Capsule())
                }

                HStack(spacing: 0) {
                    StatItem(value: openCount, label: "Open", systemImage: "tray.full", tint: Theme.accent)
                    StatItem(value: todayCount, label: "Due Today", systemImage: "sun.max", tint: Color(red: 0.98, green: 0.74, blue: 0.30))
                    StatItem(value: overdueCount, label: "Overdue", systemImage: "exclamationmark.triangle", tint: Color(red: 0.97, green: 0.45, blue: 0.42))
                    StatItem(value: doneCount, label: "Done", systemImage: "checkmark.seal", tint: Color(red: 0.40, green: 0.85, blue: 0.55))
                }

                TaskComposer()
            }
            .padding(22)
        }
    }

    // MARK: List panel — filter pills + the scrolling grouped task list.
    private var listPanel: some View {
        AuroraCard(cornerRadius: 22) {
            VStack(spacing: 0) {
                filterBar
                taskList
            }
        }
    }

    private var filterBar: some View {
        HStack(spacing: 4) {
            ForEach(TaskFilter.allCases) { f in
                let active = (f == filter)
                Text(f.rawValue)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(active ? .black.opacity(0.85) : .white.opacity(0.65))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background {
                        if active {
                            Capsule().fill(.white.opacity(0.92))
                                .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
                        }
                    }
                    .contentShape(Capsule())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { filter = f }
                    }
            }
        }
        .padding(4)
        .background(.black.opacity(0.22), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.10), lineWidth: 1))
        .padding(16)
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
                                    .foregroundStyle(.white.opacity(0.5))
                                Text("\(group.items.count)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(.white.opacity(0.12), in: Capsule())
                            }
                            .padding(.horizontal, 14)
                            .padding(.bottom, 2)

                            ForEach(group.items) { item in
                                TaskRow(item: item)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 2)
                .padding(.bottom, 14)
                .animation(.easeOut(duration: 0.2), value: store.items)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: filter == .done ? "checkmark.circle" : "sparkles")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.white.opacity(0.5))
            Text(emptyTitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
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
