import AppKit
import ApplicationServices

/// Reads the keyboard shortcuts listed in an app's menu bar through the
/// Accessibility API. Needs the Device Control and Data Access (Accessibility)
/// permission. Safe to call off the main thread; large apps take a moment.
enum MenuShortcutReader {
    static let sectionColor = "#14B8A6"   // teal
    static let maxItems = 4000
    static let maxDepth = 5

    enum Failure: Error {
        case notTrusted
        /// The app didn't hand over its menu bar; carries the AXError code.
        case noMenuBar(Int32)
    }

    /// What a read found, for explaining an empty result.
    struct Report {
        var bindings: [KeyBinding] = []
        var menus = 0              // top-level menus
        var items = 0              // menu items looked at
        var withShortcut = 0       // items that report a shortcut at all
        var unplaced: [String] = [] // shortcuts on keys that couldn't be matched to the keyboard

        /// One line for the header when nothing usable was found.
        func summary(appName: String) -> String? {
            guard bindings.isEmpty else { return nil }
            if menus == 0 { return "\(appName) shows no menus to KeyboardViewer" }
            if items == 0 { return "\(appName)'s \(menus) menus came back empty" }
            if withShortcut == 0 { return "\(appName): \(items) menu items, none with a shortcut" }
            let sample = unplaced.prefix(3).joined(separator: ", ")
            return "\(appName): \(withShortcut) shortcuts on keys KeyboardViewer can't place (\(sample))"
        }
    }

    static func read(pid: pid_t, appName: String, keys: KeyCharacterMap) -> Result<Report, Failure> {
        guard AXIsProcessTrusted() else { return .failure(.notTrusted) }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 2.0)
        var menuBarRef: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(app, "AXMenuBar" as CFString, &menuBarRef)
        guard status == .success, let menuBarRef, CFGetTypeID(menuBarRef) == AXUIElementGetTypeID() else {
            return .failure(.noMenuBar(status.rawValue))
        }
        let menuBar = menuBarRef as! AXUIElement

        var report = Report()
        var found: [(binding: KeyBinding, enabled: Bool)] = []
        var visited = 0
        let section = "\(appName) menus"

        func walk(_ menu: AXUIElement, path: [String], depth: Int) {
            guard depth <= maxDepth else { return }
            for item in elements(menu, "AXChildren") {
                visited += 1
                guard visited <= maxItems else { return }
                let title = string(item, "AXTitle") ?? ""
                report.items += 1
                if hasShortcut(item) {
                    report.withShortcut += 1
                }

                if let shortcut = shortcut(of: item, keys: keys), !title.isEmpty {
                    let enabled = (bool(item, "AXEnabled") ?? true)
                    found.append((KeyBinding(
                        keyCode: shortcut.key,
                        mandatory: shortcut.mods,
                        allowsAnyExtra: false,
                        title: title,
                        detail: (path + [title]).joined(separator: " › "),
                        kind: .keystroke,
                        ruleName: section,
                        ruleColor: sectionColor,
                        isGlobal: false
                    ), enabled))
                } else if hasShortcut(item), report.unplaced.count < 5 {
                    report.unplaced.append(rawShortcut(item))
                }
                // A submenu is the item's own child menu.
                for submenu in elements(item, "AXChildren") {
                    walk(submenu, path: path + [title], depth: depth + 1)
                }
            }
        }

        for top in elements(menuBar, "AXChildren") {
            report.menus += 1
            let topTitle = string(top, "AXTitle") ?? ""
            for menu in elements(top, "AXChildren") {
                walk(menu, path: [topTitle.isEmpty ? "Apple" : topTitle], depth: 1)
            }
        }

        // Where two items claim the same shortcut, the enabled one is the one
        // that runs, so list enabled items first (the sort is stable).
        let ordered = found.enumerated()
            .sorted { a, b in
                if a.element.enabled != b.element.enabled { return a.element.enabled }
                return a.offset < b.offset
            }
            .map { $0.element.binding }
        report.bindings = ordered
        return .success(report)
    }

    private static func hasShortcut(_ item: AXUIElement) -> Bool {
        !(string(item, "AXMenuItemCmdChar") ?? "").isEmpty
            || int(item, "AXMenuItemCmdVirtualKey") != nil
            || (int(item, "AXMenuItemCmdGlyph") ?? 0) != 0
    }

    /// What the app reported, e.g. "char \"N\" mods 0", for the summary.
    private static func rawShortcut(_ item: AXUIElement) -> String {
        let c = string(item, "AXMenuItemCmdChar") ?? ""
        let vk = int(item, "AXMenuItemCmdVirtualKey").map(String.init) ?? "-"
        let g = int(item, "AXMenuItemCmdGlyph").map(String.init) ?? "-"
        let unicode = c.unicodeScalars.map { String(format: "U+%04X", $0.value) }.joined()
        return c.isEmpty ? "key \(vk) glyph \(g)" : "\(unicode)"
    }

    // MARK: - Shortcut decoding

    private static func shortcut(of item: AXUIElement, keys: KeyCharacterMap) -> (key: String, mods: Mods)? {
        let character = string(item, "AXMenuItemCmdChar") ?? ""
        let virtualKey = int(item, "AXMenuItemCmdVirtualKey")
        let glyph = int(item, "AXMenuItemCmdGlyph")
        let flags = int(item, "AXMenuItemCmdModifiers") ?? 0

        var key: String?
        var needsShift = false
        if !character.isEmpty {
            if let scalar = character.unicodeScalars.first,
               character.unicodeScalars.count == 1,
               let special = KeyCodes.specialCharacters[scalar.value] {
                key = special
            } else if let match = keys.key(for: character) {
                key = match.code
                needsShift = match.needsShift
            }
        } else if let vk = virtualKey, let name = KeyCodes.byCode[UInt16(truncatingIfNeeded: vk)] {
            key = name
        } else if let g = glyph, let name = KeyCodes.menuGlyphs[g] {
            key = name
        }
        guard let key else { return nil }

        // kAXMenuItemModifier…: 0 means ⌘ alone; Shift = 1, Option = 2,
        // Control = 4, NoCommand = 8. Globe (fn) shortcuts, which macOS
        // added to menus later, set 16.
        var mods: Mods = []
        if flags & 8 == 0 { mods.insert(.command) }
        if flags & 1 != 0 || needsShift { mods.insert(.shift) }
        if flags & 2 != 0 { mods.insert(.option) }
        if flags & 4 != 0 { mods.insert(.control) }
        if flags & 16 != 0 { mods.insert(.fn) }
        // No modifiers at all is fine: single-key shortcuts such as J for
        // "Next Article" are menu items with the NoCommand flag set.
        return (key, mods)
    }

    // MARK: - AX helpers

    private static func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value
    }

    private static func element(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let v = value(element, attribute), CFGetTypeID(v) == AXUIElementGetTypeID() else { return nil }
        return (v as! AXUIElement)
    }

    private static func elements(_ element: AXUIElement, _ attribute: String) -> [AXUIElement] {
        (value(element, attribute) as? [AXUIElement]) ?? []
    }

    private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        value(element, attribute) as? String
    }

    private static func int(_ element: AXUIElement, _ attribute: String) -> Int? {
        (value(element, attribute) as? NSNumber)?.intValue
    }

    private static func bool(_ element: AXUIElement, _ attribute: String) -> Bool? {
        (value(element, attribute) as? NSNumber)?.boolValue
    }
}
