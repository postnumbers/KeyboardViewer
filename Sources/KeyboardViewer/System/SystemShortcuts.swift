import Foundation

/// macOS's own keyboard shortcuts (System Settings › Keyboard › Keyboard
/// Shortcuts), read from the `com.apple.symbolichotkeys` preferences.
///
/// The file stores entries by numeric ID with no names, and shortcuts that
/// were never changed may be missing from it. So known IDs have built-in names
/// and defaults below, and the file's entries override them. Enabled entries
/// with unknown IDs are listed as "macOS shortcut".
enum SystemShortcuts {
    static let sectionName = "macOS"
    static let sectionColor = "#6366F1"   // indigo

    private struct Known {
        let name: String
        let key: String
        let mods: Mods
        let enabledByDefault: Bool
    }

    private static let known: [Int: Known] = {
        var table: [Int: Known] = [
            7: Known(name: "Focus menu bar", key: "f2", mods: [.control], enabledByDefault: true),
            8: Known(name: "Focus Dock", key: "f3", mods: [.control], enabledByDefault: true),
            9: Known(name: "Focus window", key: "f4", mods: [.control], enabledByDefault: true),
            10: Known(name: "Focus toolbar", key: "f5", mods: [.control], enabledByDefault: true),
            11: Known(name: "Focus floating window", key: "f6", mods: [.control], enabledByDefault: true),
            27: Known(name: "Next window", key: "grave_accent_and_tilde", mods: [.command], enabledByDefault: true),
            57: Known(name: "Focus status menus", key: "f8", mods: [.control], enabledByDefault: true),
            28: Known(name: "Screenshot to file", key: "3", mods: [.shift, .command], enabledByDefault: true),
            29: Known(name: "Screenshot to clipboard", key: "3", mods: [.control, .shift, .command], enabledByDefault: true),
            30: Known(name: "Selection to file", key: "4", mods: [.shift, .command], enabledByDefault: true),
            31: Known(name: "Selection to clipboard", key: "4", mods: [.control, .shift, .command], enabledByDefault: true),
            184: Known(name: "Screenshot options", key: "5", mods: [.shift, .command], enabledByDefault: true),
            32: Known(name: "Mission Control", key: "up_arrow", mods: [.control], enabledByDefault: true),
            33: Known(name: "App windows", key: "down_arrow", mods: [.control], enabledByDefault: true),
            36: Known(name: "Show Desktop", key: "f11", mods: [], enabledByDefault: true),
            79: Known(name: "Space left", key: "left_arrow", mods: [.control], enabledByDefault: true),
            81: Known(name: "Space right", key: "right_arrow", mods: [.control], enabledByDefault: true),
            64: Known(name: "Spotlight", key: "spacebar", mods: [.command], enabledByDefault: true),
            65: Known(name: "Finder search", key: "spacebar", mods: [.option, .command], enabledByDefault: true),
            60: Known(name: "Previous input source", key: "spacebar", mods: [.control], enabledByDefault: true),
            61: Known(name: "Next input source", key: "spacebar", mods: [.control, .option], enabledByDefault: true),
            52: Known(name: "Dock hiding", key: "d", mods: [.option, .command], enabledByDefault: true),
            98: Known(name: "Help menu", key: "slash", mods: [.shift, .command], enabledByDefault: true),
        ]
        // 118… = Switch to Desktop 1…9 (⌃1…⌃9), off by default.
        for n in 1...9 {
            table[117 + n] = Known(name: "Desktop \(n)", key: String(n), mods: [.control], enabledByDefault: false)
        }
        // Window › Move & Resize (macOS 15 and later). Names are matched to
        // the IDs by their default shortcuts; the quarters have none.
        let tiling: [(Int, String, String, Mods)] = [
            (237, "Fill", "f", [.fn, .control]),
            (238, "Center", "c", [.fn, .control]),
            (239, "Return to Previous Size", "r", [.fn, .control]),
            (240, "Tile Left", "left_arrow", [.fn, .control]),
            (241, "Tile Right", "right_arrow", [.fn, .control]),
            (242, "Tile Top", "up_arrow", [.fn, .control]),
            (243, "Tile Bottom", "down_arrow", [.fn, .control]),
            (248, "Left & Right", "left_arrow", [.fn, .control, .shift]),
            (249, "Right & Left", "right_arrow", [.fn, .control, .shift]),
            (250, "Top & Bottom", "up_arrow", [.fn, .control, .shift]),
            (251, "Bottom & Top", "down_arrow", [.fn, .control, .shift]),
        ]
        for (id, name, key, mods) in tiling {
            table[id] = Known(name: name, key: key, mods: mods, enabledByDefault: true)
        }
        for (id, name) in [(244, "Top Left"), (245, "Top Right"), (246, "Bottom Left"), (247, "Bottom Right"), (256, "Quarters")] {
            table[id] = Known(name: name, key: "", mods: [], enabledByDefault: false)
        }
        return table
    }()

    /// Window tiling IDs, where fn (Globe) is part of the shortcut even on
    /// arrow keys. Elsewhere macOS sets the fn bit on every arrow and F-key.
    private static let tilingIDs = 233...260

    static func read() -> [KeyBinding] {
        let stored = UserDefaults(suiteName: "com.apple.symbolichotkeys")?
            .dictionary(forKey: "AppleSymbolicHotKeys") ?? [:]

        var result: [KeyBinding] = []
        var ids = Set(known.keys)
        for key in stored.keys { if let id = Int(key) { ids.insert(id) } }

        for id in ids.sorted() {
            let entry = stored[String(id)] as? [String: Any]
            let defaults = known[id]

            let enabled = (entry?["enabled"] as? NSNumber)?.boolValue ?? defaults?.enabledByDefault ?? false
            guard enabled else { continue }

            var keyName = defaults?.key.isEmpty == false ? defaults?.key : nil
            var mods = defaults?.mods ?? []
            if let value = entry?["value"] as? [String: Any],
               let parameters = value["parameters"] as? [NSNumber], parameters.count >= 3 {
                // parameters: [character or 65535, virtual key code, modifier flags]
                let code = parameters[1].intValue
                if code != 65535, let name = KeyCodes.byCode[UInt16(truncatingIfNeeded: code)] {
                    keyName = name
                    mods = decode(parameters[2].intValue, keyName: name, tiling: tilingIDs.contains(id))
                } else if code != 65535 {
                    keyName = nil   // a key the overlay doesn't draw
                }
            }
            guard let keyName else { continue }

            result.append(KeyBinding(
                keyCode: keyName,
                mandatory: mods,
                allowsAnyExtra: false,
                title: defaults?.name ?? "macOS shortcut #\(id)",
                detail: "System Settings › Keyboard Shortcuts (#\(id))",
                kind: .other,
                ruleName: sectionName,
                ruleColor: sectionColor,
                isGlobal: false
            ))
        }
        return result
    }

    /// NSEvent modifier flag bits as stored in the file. macOS also sets fn
    /// (0x800000) on every arrow and F-key shortcut, so there it only counts
    /// for window tiling, which really uses Globe.
    private static func decode(_ flags: Int, keyName: String, tiling: Bool) -> Mods {
        var mods: Mods = []
        let fnImplied = keyName.hasSuffix("_arrow") || (keyName.hasPrefix("f") && Int(keyName.dropFirst()) != nil)
        if flags & 0x800000 != 0 && (tiling || !fnImplied) { mods.insert(.fn) }
        if flags & 0x20000 != 0 { mods.insert(.shift) }
        if flags & 0x40000 != 0 { mods.insert(.control) }
        if flags & 0x80000 != 0 { mods.insert(.option) }
        if flags & 0x100000 != 0 { mods.insert(.command) }
        return mods
    }
}
