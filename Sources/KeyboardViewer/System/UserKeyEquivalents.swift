import Foundation

/// Shortcuts set in System Settings › Keyboard › Keyboard Shortcuts › App
/// Shortcuts, for all apps or for one. macOS keeps them in the
/// `NSUserKeyEquivalents` preference, keyed by menu item title (or by menu
/// path, e.g. "\u{1B}Window\u{1B}Move & Resize\u{1B}Top Left").
///
/// Reading them here catches shortcuts on items the Accessibility API can't
/// see, such as those in submenus an app only fills in when they're opened.
enum UserKeyEquivalents {
    static let sectionColor = "#0EA5E9"   // sky

    /// The user's shortcuts for `bundleID`, plus the ones for all apps.
    /// The app's own settings win where both name the same item.
    static func bindings(bundleID: String?, appName: String, keys: KeyCharacterMap) -> [KeyBinding] {
        var entries: [String: String] = [:]
        if let global = dictionary(CFPreferencesCopyAppValue("NSUserKeyEquivalents" as CFString, kCFPreferencesAnyApplication)) {
            entries.merge(global) { _, new in new }
        }
        if let bundleID {
            entries.merge(appEntries(bundleID)) { _, new in new }
        }

        let section = "\(appName) shortcuts you set"
        return entries.sorted { $0.key < $1.key }.compactMap { path, value in
            guard let (key, mods) = parse(value, keys: keys) else { return nil }
            let parts = path.split(separator: "\u{1B}").map(String.init).filter { !$0.isEmpty }
            guard let title = parts.last else { return nil }
            return KeyBinding(
                keyCode: key,
                mandatory: mods,
                allowsAnyExtra: false,
                title: title,
                detail: (parts.count > 1 ? parts.joined(separator: " › ") : title) + " (App Shortcut)",
                kind: .keystroke,
                ruleName: section,
                ruleColor: sectionColor,
                isGlobal: false
            )
        }
    }

    /// Sandboxed apps keep their preferences in their container, so look there too.
    private static func appEntries(_ bundleID: String) -> [String: String] {
        var result: [String: String] = [:]
        let home = FileManager.default.homeDirectoryForCurrentUser
        let container = home.appendingPathComponent("Library/Containers/\(bundleID)/Data/Library/Preferences/\(bundleID).plist")
        if let plist = NSDictionary(contentsOf: container),
           let d = dictionary(plist["NSUserKeyEquivalents"] as CFTypeRef?) {
            result.merge(d) { _, new in new }
        }
        if let d = dictionary(CFPreferencesCopyAppValue("NSUserKeyEquivalents" as CFString, bundleID as CFString)) {
            result.merge(d) { _, new in new }
        }
        return result
    }

    private static func dictionary(_ value: CFTypeRef?) -> [String: String]? {
        value as? [String: String]
    }

    /// "@~^$q" → (q, ⌃⌥⇧⌘). @ ⌘, ~ ⌥, ^ ⌃, $ ⇧; # marks a keypad key.
    static func parse(_ value: String, keys: KeyCharacterMap) -> (String, Mods)? {
        var mods: Mods = []
        var rest = Substring(value)
        while rest.count > 1, let c = rest.first, "@~^$#".contains(c) {
            switch c {
            case "@": mods.insert(.command)
            case "~": mods.insert(.option)
            case "^": mods.insert(.control)
            case "$": mods.insert(.shift)
            default: break   // keypad: drawn on the main key
            }
            rest = rest.dropFirst()
        }
        let character = String(rest)
        guard !character.isEmpty else { return nil }
        if character.unicodeScalars.count == 1, let scalar = character.unicodeScalars.first,
           let special = KeyCodes.specialCharacters[scalar.value] {
            return (special, mods)
        }
        guard let match = keys.key(for: character) else { return nil }
        // A capital letter or shifted symbol means ⇧, as in AppKit key equivalents.
        if match.needsShift || (character != character.lowercased() && character.lowercased() != character.uppercased()) {
            mods.insert(.shift)
        }
        return (match.code, mods)
    }
}
