import Foundation

/// Turns Karabiner events into short human-readable labels.
enum Describe {

    /// Uses the manipulator description when it follows the "keys -> action"
    /// convention (all of Marco's rules do), otherwise the output summary.
    static func title(description: String?, fallback: String) -> String {
        guard let d = description, let arrow = d.range(of: "->") else { return fallback }
        let t = d[arrow.upperBound...].trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? fallback : t
    }

    static func output(_ tos: [ToEvent]) -> (kind: BindingKind, detail: String) {
        if let shell = tos.compactMap(\.shellCommand).first {
            if let app = appName(fromOpenCommand: shell) {
                return (.app, "open \(app)")
            }
            return (.other, shell)
        }

        if tos.contains(where: { $0.pointingButton != nil || $0.mouseKey != nil }) {
            return (.mouse, mouseDetail(tos))
        }

        let strokes: [(String, Mods)] = tos.compactMap { t in
            guard let key = t.keyCode else { return nil }
            var mods: Mods = []
            for name in t.modifiers?.items ?? [] {
                if let m = Mods(karabinerName: name) { mods.insert(m) }
            }
            return (key, mods)
        }
        if !strokes.isEmpty {
            let text = strokes.map { keystroke($0.0, $0.1) }.joined(separator: " ")
            // Three or more modifiers is almost always a global hotkey an app
            // listens for (Moom, Raindrop, NotePlan...), so classify it as an app.
            let isHotkey = strokes.count == 1 && strokes[0].1.count >= 3
            return (isHotkey ? .app : .keystroke, text)
        }

        if tos.contains(where: { $0.softwareFunction != nil }) { return (.other, "software function") }
        if tos.contains(where: { $0.sendUserCommand != nil }) { return (.other, "user command") }
        return (.other, "")
    }

    /// `open -a 'Font Book'` → "Font Book"
    static func appName(fromOpenCommand command: String) -> String? {
        let trimmed = command.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("open -a ") else { return nil }
        var name = String(trimmed.dropFirst("open -a ".count)).trimmingCharacters(in: .whitespaces)
        if let q = name.first, q == "'" || q == "\"", name.last == q, name.count >= 2 {
            name = String(name.dropFirst().dropLast())
        }
        return name.isEmpty ? nil : name
    }

    static func keystroke(_ keyCode: String, _ mods: Mods) -> String {
        mods.symbols + keyName(keyCode)
    }

    static func keyName(_ code: String) -> String {
        if let name = keyNames[code] { return name }
        if code.count == 1 { return code.uppercased() }
        if code.hasPrefix("f"), Int(code.dropFirst()) != nil { return code.uppercased() }
        return code.replacingOccurrences(of: "_", with: " ")
    }

    private static func mouseDetail(_ tos: [ToEvent]) -> String {
        if let button = tos.compactMap(\.pointingButton).first {
            switch button {
            case "button1": return "left click"
            case "button2": return "right click"
            case "button3": return "middle click"
            default: return button
            }
        }
        if let keys = tos.compactMap(\.mouseKey).first {
            if keys["vertical_wheel"] != nil || keys["horizontal_wheel"] != nil { return "scroll" }
            return "move pointer"
        }
        return "mouse"
    }

    static let keyNames: [String: String] = [
        "up_arrow": "↑", "down_arrow": "↓", "left_arrow": "←", "right_arrow": "→",
        "delete_or_backspace": "⌫", "delete_forward": "⌦",
        "return_or_enter": "↩", "tab": "⇥", "escape": "⎋", "spacebar": "Space",
        "caps_lock": "⇪", "page_up": "PgUp", "page_down": "PgDn",
        "home": "Home", "end": "End",
        "grave_accent_and_tilde": "`", "hyphen": "-", "equal_sign": "=",
        "open_bracket": "[", "close_bracket": "]", "backslash": "\\",
        "semicolon": ";", "quote": "'", "comma": ",", "period": ".", "slash": "/",
    ]
}
