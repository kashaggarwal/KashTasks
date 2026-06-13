import SwiftUI
import AppKit
import KashTasksCore

struct MenuBarView: View {
    @EnvironmentObject var store: TaskStore

    // Add-form state
    @State private var newTitle = ""
    @State private var newTag = ""
    @State private var newNotes = ""
    @State private var newPriority: Priority = .medium
    @State private var hasDueDate = false
    @State private var newDueDate = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("KashTasks").font(.headline)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(TaskSorting.grouped(store.items), id: \.tag) { group in
                        Text(group.tag)
                            .font(.caption).bold()
                            .foregroundStyle(.secondary)
                        ForEach(group.items) { item in
                            row(for: item)
                        }
                    }
                    if store.items.isEmpty {
                        Text("No tasks yet").foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxHeight: 280)

            Divider()
            addForm

            Divider()
            Button("Quit KashTasks") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 320)
    }

    @ViewBuilder
    private func row(for item: TodoItem) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Button {
                store.toggleDone(item.id)
            } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
            }
            .buttonStyle(.plain)

            Circle()
                .fill(color(for: item.priority))
                .frame(width: 8, height: 8)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .strikethrough(item.isDone)
                if let due = item.dueDate {
                    Text(due.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(ReminderLogic.isOverdue(item, now: Date()) ? .red : .secondary)
                }
                if !item.notes.isEmpty {
                    Text(item.notes).font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                store.delete(item.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
        }
    }

    private var addForm: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("New task", text: $newTitle)
            HStack {
                TextField("Tag", text: $newTag)
                Picker("", selection: $newPriority) {
                    ForEach(Priority.allCases, id: \.self) { p in
                        Text(p.label).tag(p)
                    }
                }
                .labelsHidden()
            }
            TextField("Notes", text: $newNotes)
            Toggle("Due date", isOn: $hasDueDate)
            if hasDueDate {
                DatePicker("", selection: $newDueDate)
                    .labelsHidden()
            }
            Button("Add") { addTask() }
                .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func addTask() {
        let item = TodoItem(
            title: newTitle.trimmingCharacters(in: .whitespaces),
            notes: newNotes,
            priority: newPriority,
            tag: newTag.trimmingCharacters(in: .whitespaces),
            dueDate: hasDueDate ? newDueDate : nil
        )
        store.add(item)
        newTitle = ""; newTag = ""; newNotes = ""
        newPriority = .medium; hasDueDate = false; newDueDate = Date()
    }

    private func color(for priority: Priority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .gray
        }
    }
}
