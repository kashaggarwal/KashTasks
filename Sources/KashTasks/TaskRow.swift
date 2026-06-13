import SwiftUI
import KashTasksCore

/// One task line, used in the dashboard list. Hover reveals the delete control;
/// the whole row gets a soft highlight on hover for affordance.
struct TaskRow: View {
    let item: TodoItem
    @EnvironmentObject var store: TaskStore
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 11) {
            Button {
                withAnimation(.easeOut(duration: 0.15)) { store.toggleDone(item.id) }
            } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17))
                    .foregroundStyle(item.isDone ? Theme.accent : Color.secondary.opacity(0.7))
            }
            .buttonStyle(PressableStyle(scale: 0.9))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .medium))
                        .strikethrough(item.isDone, color: .secondary)
                        .foregroundStyle(item.isDone ? .secondary : .primary)
                        .lineLimit(1)
                    PriorityPill(priority: item.priority)
                }
                if !item.notes.isEmpty {
                    Text(item.notes)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if let due = item.dueDate {
                DueChip(date: due, overdue: ReminderLogic.isOverdue(item, now: Date()))
            }

            Button {
                withAnimation(.easeOut(duration: 0.15)) { store.delete(item.id) }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle(scale: 0.85))
            .opacity(hovering ? 1 : 0)
            .help("Delete task")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: Theme.rowCorner, style: .continuous)
                .fill(Color.primary.opacity(hovering ? 0.05 : 0))
        )
        .onHover { hovering = $0 }
    }
}
