import Carbon
import Foundation

/// Which character each key types in the current keyboard layout, both ways:
/// key → character (for the ⌥ and ⇧⌥ layers) and character → key (to place
/// menu shortcuts like ⌘, or ⌘{ on the right key).
struct KeyCharacterMap: Sendable {
    /// "w" → "w", "," → "comma", "[" → "open_bracket"
    var unshifted: [String: String] = [:]
    /// "W" → "w", "<" → "comma", "{" → "open_bracket"
    var shifted: [String: String] = [:]

    /// The key that types `character`, and whether ⇧ is needed for it.
    /// Letters match case-insensitively, since menus list them in capitals.
    func key(for character: String) -> (code: String, needsShift: Bool)? {
        if let code = unshifted[character] { return (code, false) }
        if let code = unshifted[character.lowercased()] { return (code, false) }
        if let code = shifted[character] { return (code, true) }
        return nil
    }
}

/// Reads the current keyboard layout with UCKeyTranslate. Text Input Source
/// calls must run on the main thread.
@MainActor
enum KeyboardLayoutReader {
    static let characterSectionName = "Option characters"
    static let characterSectionColor = "#6B7280"

    static func characterMap() -> KeyCharacterMap {
        var map = KeyCharacterMap()
        withLayout { layout in
            for name in KeyCodes.characterKeys {
                guard let code = KeyCodes.byName[name] else { continue }
                let plain = translate(layout, key: code, modifiers: [], noDeadKeys: true).text
                let shift = translate(layout, key: code, modifiers: [.shift], noDeadKeys: true).text
                if isPrintable(plain), map.unshifted[plain] == nil { map.unshifted[plain] = name }
                if isPrintable(shift), map.shifted[shift] == nil { map.shifted[shift] = name }
            }
        }
        return map
    }

    /// The shape of the keyboard last typed on: ISO or ANSI. JIS and unknown
    /// keyboards are drawn as ANSI. With Karabiner-Elements running, this is
    /// the type its virtual keyboard is set to.
    static func detectedPhysicalLayout() -> PhysicalLayout {
        let type = KBGetLayoutType(Int16(LMGetKbdType()))
        return type == PhysicalKeyboardLayoutType(kKeyboardISO) ? .iso : .ansi
    }

    /// What's printed on each character key for the current input layout:
    /// "A" for a, "Q" on the A key with AZERTY, "§" on the ISO key left of 1.
    static func keyLegends() -> [String: String] {
        var result: [String: String] = [:]
        withLayout { layout in
            for name in KeyCodes.characterKeys {
                guard let code = KeyCodes.byName[name] else { continue }
                let text = translate(layout, key: code, modifiers: [], noDeadKeys: true).text
                guard isPrintable(text) else { continue }
                result[name] = text.uppercased().count == 1 ? text.uppercased() : text
            }
        }
        return result
    }

    /// One binding per key on its own and with ⇧: the character it types,
    /// e.g. "a" and "A", "[" and "{".
    static func typedCharacterBindings() -> [KeyBinding] {
        var result: [KeyBinding] = []
        withLayout { layout in
            for mods: Mods in [[], [.shift]] {
                for name in KeyCodes.characterKeys {
                    guard let code = KeyCodes.byName[name] else { continue }
                    let text = translate(layout, key: code, modifiers: mods, noDeadKeys: true).text
                    guard isPrintable(text) else { continue }
                    var binding = KeyBinding(
                        keyCode: name,
                        mandatory: mods,
                        allowsAnyExtra: false,
                        title: text,
                        detail: "Types \(text)",
                        kind: .other,
                        ruleName: "",
                        ruleColor: nil,
                        isGlobal: false
                    )
                    binding.isTypedCharacter = true
                    binding.isCharacter = true
                    result.append(binding)
                }
            }
        }
        return result
    }

    /// One binding per key for ⌥ and for ⇧⌥: the character it types.
    static func optionCharacterBindings() -> [KeyBinding] {
        var result: [KeyBinding] = []
        withLayout { layout in
            let layers: [Mods] = [[.option], [.option, .shift]]
            for mods in layers {
                for name in KeyCodes.characterKeys {
                    guard let code = KeyCodes.byName[name] else { continue }
                    let isDead = translate(layout, key: code, modifiers: mods, noDeadKeys: false).isDead
                    let text = translate(layout, key: code, modifiers: mods, noDeadKeys: true).text
                    guard isPrintable(text) else { continue }
                    var binding = KeyBinding(
                        keyCode: name,
                        mandatory: mods,
                        allowsAnyExtra: false,
                        title: text,
                        detail: isDead ? "Dead key: type a letter next to add \(text)" : "Types \(text)",
                        kind: .other,
                        ruleName: characterSectionName,
                        ruleColor: characterSectionColor,
                        isGlobal: false
                    )
                    binding.isCharacter = true
                    result.append(binding)
                }
            }
        }
        return result
    }

    // MARK: - UCKeyTranslate

    private static func withLayout(_ body: (UnsafePointer<UCKeyboardLayout>) -> Void) {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return }
        let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue()
        guard let bytes = CFDataGetBytePtr(data) else { return }
        bytes.withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { body($0) }
    }

    private static func translate(
        _ layout: UnsafePointer<UCKeyboardLayout>,
        key: UInt16,
        modifiers: Mods,
        noDeadKeys: Bool
    ) -> (text: String, isDead: Bool) {
        // UCKeyTranslate takes Carbon modifier bits shifted right by 8.
        var carbon = 0
        if modifiers.contains(.shift) { carbon |= shiftKey }
        if modifiers.contains(.option) { carbon |= optionKey }
        let modifierState = UInt32((carbon >> 8) & 0xFF)

        var deadKeyState: UInt32 = 0
        var length = 0
        var chars = [UniChar](repeating: 0, count: 8)
        let options: OptionBits = noDeadKeys ? OptionBits(1 << kUCKeyTranslateNoDeadKeysBit) : 0
        let status = UCKeyTranslate(
            layout, key, UInt16(kUCKeyActionDown), modifierState,
            UInt32(LMGetKbdType()), options, &deadKeyState, chars.count, &length, &chars
        )
        guard status == noErr else { return ("", false) }
        return (String(utf16CodeUnits: chars, count: length), deadKeyState != 0)
    }

    private static func isPrintable(_ s: String) -> Bool {
        guard let scalar = s.unicodeScalars.first, !s.isEmpty else { return false }
        return !CharacterSet.controlCharacters.contains(scalar)
            && !CharacterSet.whitespacesAndNewlines.contains(scalar)
    }
}
