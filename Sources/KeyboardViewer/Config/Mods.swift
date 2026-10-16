import AppKit

/// The real (OS-visible) modifiers the overlay tracks alongside Hyper.
/// Left/right variants are folded together, matching how Karabiner treats
/// the generic names ("shift", "command", ...) in `from.modifiers`.
struct Mods: OptionSet, Hashable {
    let rawValue: Int

    // Declared explicitly: the other initializers below suppress the
    // automatically generated one, which OptionSet requires.
    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    static let control = Mods(rawValue: 1 << 0)
    static let option  = Mods(rawValue: 1 << 1)
    static let shift   = Mods(rawValue: 1 << 2)
    static let command = Mods(rawValue: 1 << 3)
    static let fn      = Mods(rawValue: 1 << 4)

    /// Maps a Karabiner modifier name. Returns nil for names that aren't
    /// tracked modifiers (`caps_lock`, `any`).
    init?(karabinerName name: String) {
        switch name {
        case "control", "left_control", "right_control": self = .control
        case "option", "left_option", "right_option", "left_alt", "right_alt": self = .option
        case "shift", "left_shift", "right_shift": self = .shift
        case "command", "left_command", "right_command", "left_gui", "right_gui": self = .command
        case "fn": self = .fn
        default: return nil
        }
    }

    init(flags: NSEvent.ModifierFlags) {
        var m: Mods = []
        if flags.contains(.control) { m.insert(.control) }
        if flags.contains(.option) { m.insert(.option) }
        if flags.contains(.shift) { m.insert(.shift) }
        if flags.contains(.command) { m.insert(.command) }
        if flags.contains(.function) { m.insert(.fn) }
        self = m
    }

    /// fn first, then the Mac-standard order ⌃ ⌥ ⇧ ⌘ (e.g. "fn ⌃F3").
    var symbols: String {
        var s = contains(.fn) ? "fn " : ""
        if contains(.control) { s += "⌃" }
        if contains(.option) { s += "⌥" }
        if contains(.shift) { s += "⇧" }
        if contains(.command) { s += "⌘" }
        return s
    }

    var count: Int { rawValue.nonzeroBitCount }
}
