import Foundation
import Carbon.HIToolbox

/// Registers a single global hot key (⌃⌥Space) via the Carbon API, which works
/// system-wide without Accessibility permission. Calls `handler` on each press.
@MainActor
final class HotkeyManager {
    static let shared = HotkeyManager()

    private var handler: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var installed = false

    func register(handler: @escaping () -> Void) {
        self.handler = handler

        if !installed {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                          eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
                DispatchQueue.main.async { HotkeyManager.shared.handler?() }
                return noErr
            }, 1, &eventType, nil, nil)
            installed = true
        }

        // Don't register a second hot key if one is already live (would leak the prior ref).
        guard hotKeyRef == nil else { return }

        let hotKeyID = EventHotKeyID(signature: OSType(0x4B415348), id: 1) // 'KASH'
        let modifiers = UInt32(controlKey | optionKey)
        let keyCode = UInt32(kVK_Space) // 49
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                                         GetApplicationEventTarget(), 0, &ref)
        if status == noErr {
            hotKeyRef = ref
        } else {
            NSLog("KashTasks: failed to register hotkey (status \(status))")
        }
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }
}
