import SwiftUI
import KashTasksCore

/// The "add a task" composer in the hero card. Collapsed by default — just the
/// title field and the Add pill — with a toggle that reveals tag / priority /
/// repeat / due so the hero card stays compact.
struct TaskComposer: View {
    @EnvironmentObject var store: TaskStore

    @State private var title = ""
    @State private var tag = ""
    @State private var notes = ""
    @State private var priority: Priority = .medium
    @State private var hasDue = false
    @State private var due = Date()
    @State private var recurrence: Recurrence = .none
    @State private var expanded = false
    @FocusState private var titleFocused: Bool

    private var canAdd: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 9) {
            HStack(spacing: 9) {
                HStack(spacing: 9) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Theme.accent)
                        .font(.system(size: 16))
                    TextField("Add a task…", text: $title)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                        .focused($titleFocused)
                        .onSubmit(add)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.surfaceStroke, lineWidth: 1))

                optionsToggle

                GradientPillButton(title: "Add", action: add)
                    .disabled(!canAdd)
                    .opacity(canAdd ? 1 : 0.5)
            }

            if expanded {
                detailRow
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.top, 2)
    }

    private var optionsToggle: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { expanded.toggle() }
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(expanded ? .white : .white.opacity(0.65))
                .frame(width: 38, height: 38)
                .background(.white.opacity(expanded ? 0.18 : 0.08), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
        .help("Tag, priority, repeat, due date")
    }

    private var detailRow: some View {
        HStack(spacing: 8) {
            TextField("Tag", text: $tag)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(width: 110)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Picker("", selection: $priority) {
                ForEach(Priority.allCases, id: \.self) { p in
                    Text(p.label).tag(p)
                }
            }
            .labelsHidden()
            .frame(width: 110)

            Picker("", selection: $recurrence) {
                ForEach(Recurrence.allCases, id: \.self) { r in
                    Text(r == .none ? "No repeat" : r.label).tag(r)
                }
            }
            .labelsHidden()
            .frame(width: 120)

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
        }
    }

    private func add() {
        guard canAdd else { return }
        let item = TodoItem(
            title: title.trimmingCharacters(in: .whitespaces),
            notes: notes,
            priority: priority,
            tag: tag.trimmingCharacters(in: .whitespaces),
            dueDate: hasDue ? due : nil,
            recurrence: recurrence
        )
        withAnimation(.easeOut(duration: 0.18)) { store.add(item) }
        title = ""; tag = ""; notes = ""
        priority = .medium; hasDue = false; due = Date(); recurrence = .none
        titleFocused = true
    }
}
