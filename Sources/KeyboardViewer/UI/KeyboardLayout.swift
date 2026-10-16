import CoreGraphics

/// One physical key on the ANSI MacBook-style layout.
struct KeyDef: Identifiable {
    let code: String           // Karabiner key_code
    let legend: String         // what's printed on the key
    var width: CGFloat = 1     // in key units
    var modifier: Mods? = nil  // set for ⇧ ⌃ ⌥ ⌘ fn keys

    var id: String { code }
}

enum KeySlot: Identifiable {
    case key(KeyDef)
    case stacked(top: KeyDef, bottom: KeyDef)   // half-height ↑/↓ pair

    var id: String {
        switch self {
        case .key(let k): return k.code
        case .stacked(let top, let bottom): return top.code + "+" + bottom.code
        }
    }
}

/// ANSI layout (matches `"keyboard_type_v2": "ansi"` in the profile).
/// Every row totals 14.5 units so the right edges line up.
enum KeyboardLayout {
    static let rows: [[KeySlot]] = [functionRow, numberRow, topRow, homeRow, bottomRow, spaceRow]

    /// Rendered shorter than the other rows, like the MacBook function row.
    static let functionRow: [KeySlot] =
        [k("escape", "esc", 1.5)]
        + (1...12).map { k("f\($0)", "F\($0)") }
        + [k("power", "", 1)]

    static let numberRow: [KeySlot] =
        [k("grave_accent_and_tilde", "`")]
        + letters("1234567890")
        + [k("hyphen", "-"), k("equal_sign", "="), k("delete_or_backspace", "⌫", 1.5)]

    static let topRow: [KeySlot] =
        [k("tab", "⇥", 1.5)]
        + letters("qwertyuiop")
        + [k("open_bracket", "["), k("close_bracket", "]"), k("backslash", "\\")]

    static let homeRow: [KeySlot] =
        [k("caps_lock", "⇪", 1.75)]   // "Hyper" when it is one (OverlayState.legend)
        + letters("asdfghjkl")
        + [k("semicolon", ";"), k("quote", "'"), k("return_or_enter", "↩", 1.75)]

    static let bottomRow: [KeySlot] =
        [mod("left_shift", "⇧", 2.25, .shift)]
        + letters("zxcvbnm")
        + [k("comma", ","), k("period", "."), k("slash", "/"), mod("right_shift", "⇧", 2.25, .shift)]

    static let spaceRow: [KeySlot] = [
            mod("fn", "fn", 1, .fn),
            mod("left_control", "⌃", 1, .control),
            mod("left_option", "⌥", 1, .option),
            mod("left_command", "⌘", 1.25, .command),
            k("spacebar", "", 5),
            mod("right_command", "⌘", 1.25, .command),
            mod("right_option", "⌥", 1, .option),
            k("left_arrow", "←"),
            .stacked(top: KeyDef(code: "up_arrow", legend: "↑"),
                     bottom: KeyDef(code: "down_arrow", legend: "↓")),
            k("right_arrow", "→"),
        ]

    private static func letters(_ chars: String) -> [KeySlot] {
        chars.map { c in
            let s = String(c)
            return k(s, s.uppercased())
        }
    }

    private static func k(_ code: String, _ legend: String, _ width: CGFloat = 1) -> KeySlot {
        .key(KeyDef(code: code, legend: legend, width: width))
    }

    private static func mod(_ code: String, _ legend: String, _ width: CGFloat, _ m: Mods) -> KeySlot {
        .key(KeyDef(code: code, legend: legend, width: width, modifier: m))
    }
}
