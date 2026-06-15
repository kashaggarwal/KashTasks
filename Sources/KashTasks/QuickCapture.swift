import SwiftUI
import AppKit
import KashTasksCore

/// Borderless NSPanel subclass that can become key.
/// Without this override, borderless windows return false from canBecomeKey
/// and the text field never receives focus.
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// The minimal capture field shown by the global hotkey.
struct QuickCaptureView: View {
    @ObservedObject var store: TaskStore
    var onClose: () -> Void

    @State private var title = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(Theme.accent)
            TextField("Add a task…", text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .focused($focused)
                .onSubmit(add)
            Text("⮐")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(width: 460)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.08)))
        .onAppear { focused = true }
        .onExitCommand(perform: onClose)
    }

    private func add() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { onClose(); return }
        store.add(TodoItem(title: trimmed))
        title = ""
        onClose()
    }
}

/// Owns the floating panel that hosts QuickCaptureView.
@MainActor
final class QuickCaptureController {
    private let store: TaskStore
    private var panel: NSPanel?

    init(store: TaskStore) {
        self.store = store
    }

    func show() {
        if panel == nil { panel = makePanel() }
        guard let panel else { return }
        positionTopCenter(panel)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 60),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.worksWhenModal = true

        let root = QuickCaptureView(store: store, onClose: { [weak self] in self?.close() })
        let hosting = NSHostingView(rootView: root)
        hosting.frame = panel.contentLayoutRect
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        return panel
    }

    private func positionTopCenter(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let frame = panel.frame
        let x = screen.frame.midX - frame.width / 2
        let y = screen.frame.maxY - frame.height - 160
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
