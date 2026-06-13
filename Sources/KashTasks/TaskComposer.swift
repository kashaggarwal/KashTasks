import SwiftUI
import KashTasksCore

/// The full "add a task" composer used at the bottom of the dashboard.
/// Title is always visible; the detail row (tag, priority, due) sits beneath it.
struct TaskComposer: View {
    @EnvironmentObject var store: TaskStore

    @State private var title = ""
    @State private var tag = ""
    @State private var notes = ""
    @State private var priority: Priority = .medium
    @State private var hasDue = false
    @State private var due = Date()
    @FocusState private var titleFocused: Bool

    private var canAdd: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(Theme.accent)
                    .font(.system(size: 15))
                TextField("Add a task…", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($titleFocused)
                    .onSubmit(add)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            HStack(spacing: 8) {
                TextField("Tag", text: $tag)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .frame(width: 110)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                Picker("", selection: $priority) {
                    ForEach(Priority.allCases, id: \.self) { p in
                        Text(p.label).tag(p)
                    }
                }
                .labelsHidden()
                .frame(width: 110)

                Toggle(isOn: $hasDue) {
                    Image(systemName: "calendar")
                }
                .toggleStyle(.button)
                .help("Set a due date")

                if hasDue {
                    DatePicker("", selection: $due)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }

                Spacer(minLength: 6)

                FilledButton(title: "Add", systemImage: "return", action: add)
                    .disabled(!canAdd)
                    .opacity(canAdd ? 1 : 0.5)
            }
        }
        .padding(12)
    }

    private func add() {
        guard canAdd else { return }
        let item = TodoItem(
            title: title.trimmingCharacters(in: .whitespaces),
            notes: notes,
            priority: priority,
            tag: tag.trimmingCharacters(in: .whitespaces),
            dueDate: hasDue ? due : nil
        )
        withAnimation(.easeOut(duration: 0.18)) { store.add(item) }
        title = ""; tag = ""; notes = ""
        priority = .medium; hasDue = false; due = Date()
        titleFocused = true
    }
}
