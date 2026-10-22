import CoreGraphics

/// One physical key on a MacBook-style keyboard.
struct KeyDef: Identifiable {
    let code: String           // Karabiner key_code
    let legend: String         // what's printed on the key (US English)
    var width: CGFloat = 1     // in key units
    var modifier: Mods? = nil  // set for ⇧ ⌃ ⌥ ⌘ fn keys

    var id: String { code }
}

enum KeySlot: Identifiable {
    case key(KeyDef)
    case stacked(top: KeyDef, bottom: KeyDef)   // half-height ↑/↓ pair
    /// ISO Return: `top` units wide in its own row, reaching down into the
    /// next row `bottom` units wide (an upside-down L).
    case isoReturn(KeyDef, top: CGFloat, bottom: CGFloat)
    /// Empty space where the ISO Return reaches into the row.
    case spacer(CGFloat)

    var id: String {
        switch self {
        case .key(let k): return k.code
        case .stacked(let top, let bottom): return top.code + "+" + bottom.code
        case .isoReturn(let k, _, _): return k.code
        case .spacer: return "spacer"
        }
    }
}

/// The physical shape of the keyboard.
enum PhysicalLayout: String, CaseIterable, Identifiable {
    /// US style: wide Return, \ above it, short left ⇧.
    case ansi
    /// European style: tall L-shaped Return, § left of 1, an extra key
    /// (` on Apple keyboards) left of Z.
    case iso

    var id: String { rawValue }
    var title: String { self == .ansi ? "ANSI" : "ISO" }
}

/// What the "Keyboard Shape" menu is set to. Remembered between launches.
enum PhysicalLayoutSetting: String, CaseIterable, Identifiable {
    case automatic, ansi, iso

    var id: String { rawValue }
    var title: String {
        switch self {
        case .automatic: return "Automatic"
        case .ansi: return "ANSI (US)"
        case .iso: return "ISO (European)"
        }
    }
}

/// MacBook layouts. Every row totals 14.5 units so the right edges line up.
/// Key names are Karabiner's: on ISO keyboards the § key is
/// `non_us_backslash` and the key left of Z is `grave_accent_and_tilde`.
enum KeyboardLayout {
    static func rows(for layout: PhysicalLayout) -> [[KeySlot]] {
        switch layout {
        case .ansi: return [functionRow, numberRow(first: ansiFirst), ansiTopRow, ansiHomeRow, ansiBottomRow, spaceRow]
        case .iso: return [functionRow, numberRow(first: isoFirst), isoTopRow, isoHomeRow, isoBottomRow, spaceRow]
        }
    }

    /// Rendered shorter than the other rows, like the MacBook function row.
    static let functionRow: [KeySlot] =
        [k("escape", "esc", 1.5)]
        + (1...12).map { k("f\($0)", "F\($0)") }
        + [k("power", "", 1)]

    private static let ansiFirst = k("grave_accent_and_tilde", "`")
    private static let isoFirst = k("non_us_backslash", "§")

    private static func numberRow(first: KeySlot) -> [KeySlot] {
        [first]
        + letters("1234567890")
        + [k("hyphen", "-"), k("equal_sign", "="), k("delete_or_backspace", "⌫", 1.5)]
    }

    // MARK: ANSI

    static let ansiTopRow: [KeySlot] =
        [k("tab", "⇥", 1.5)]
        + letters("qwertyuiop")
        + [k("open_bracket", "["), k("close_bracket", "]"), k("backslash", "\\")]

    static let ansiHomeRow: [KeySlot] =
        [k("caps_lock", "⇪", 1.75)]   // "Hyper" when it is one (OverlayState.legend)
        + letters("asdfghjkl")
        + [k("semicolon", ";"), k("quote", "'"), k("return_or_enter", "↩", 1.75)]

    static let ansiBottomRow: [KeySlot] =
        [mod("left_shift", "⇧", 2.25, .shift)]
        + letters("zxcvbnm")
        + [k("comma", ","), k("period", "."), k("slash", "/"), mod("right_shift", "⇧", 2.25, .shift)]

    // MARK: ISO

    static let isoTopRow: [KeySlot] =
        [k("tab", "⇥", 1.5)]
        + letters("qwertyuiop")
        + [k("open_bracket", "["), k("close_bracket", "]"),
           .isoReturn(KeyDef(code: "return_or_enter", legend: "↩"), top: 1, bottom: 0.75)]

    static let isoHomeRow: [KeySlot] =
        [k("caps_lock", "⇪", 1.75)]
        + letters("asdfghjkl")
        + [k("semicolon", ";"), k("quote", "'"), k("backslash", "\\"), .spacer(0.75)]

    static let isoBottomRow: [KeySlot] =
        [mod("left_shift", "⇧", 1.25, .shift), k("grave_accent_and_tilde", "`")]
        + letters("zxcvbnm")
        + [k("comma", ","), k("period", "."), k("slash", "/"), mod("right_shift", "⇧", 2.25, .shift)]

    // MARK: Both

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
