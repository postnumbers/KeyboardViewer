import Carbon
import Foundation

/// System-wide keyboard shortcuts via Carbon's RegisterEventHotKey. They work
/// whichever app is in front, need no permission, and don't depend on
/// Karabiner. If another app already owns a combination, registering it fails
/// and `register` returns false.
final class GlobalHotKeys {
    struct Shortcut {
        let keyCode: UInt16      // virtual key code (KeyCodes.byName)
        let modifiers: Mods

        /// e.g. "⌃⌥⇧K"
        var display: String {
            let key = KeyCodes.byCode[keyCode].map { Describe.keyName($0) } ?? "?"
            return modifiers.symbols + key
        }
    }

    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var actions: [UInt32: () -> Void] = [:]
    private var handler: EventHandlerRef?
    private var nextID: UInt32 = 1
    private static let signature: OSType = 0x4B62_5677   // "KbVw"

    init() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
            )
            guard status == noErr else { return status }
            Unmanaged<GlobalHotKeys>.fromOpaque(userData).takeUnretainedValue().fire(hotKeyID.id)
            return noErr
        }
        InstallEventHandler(
            GetApplicationEventTarget(), callback, 1, &eventType,
            Unmanaged.passUnretained(self).toOpaque(), &handler
        )
    }

    deinit {
        unregisterAll()
        if let handler { RemoveEventHandler(handler) }
    }

    /// Registers `shortcut`; `action` runs on the main thread when it's pressed.
    @discardableResult
    func register(_ shortcut: Shortcut, action: @escaping () -> Void) -> Bool {
        let id = nextID
        nextID += 1

        var carbon = 0
        if shortcut.modifiers.contains(.command) { carbon |= cmdKey }
        if shortcut.modifiers.contains(.option) { carbon |= optionKey }
        if shortcut.modifiers.contains(.control) { carbon |= controlKey }
        if shortcut.modifiers.contains(.shift) { carbon |= shiftKey }

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode), UInt32(carbon),
            EventHotKeyID(signature: Self.signature, id: id),
            GetApplicationEventTarget(), 0, &ref
        )
        guard status == noErr, let ref else { return false }
        refs[id] = ref
        actions[id] = action
        return true
    }

    func unregisterAll() {
        for ref in refs.values { UnregisterEventHotKey(ref) }
        refs.removeAll()
        actions.removeAll()
    }

    private func fire(_ id: UInt32) {
        guard let action = actions[id] else { return }
        DispatchQueue.main.async { action() }
    }
}
