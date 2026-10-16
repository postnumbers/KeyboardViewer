import Foundation

/// What the top row does: brightness, Mission Control, media, volume…
///
/// With "Use F1, F2, etc. keys as standard function keys" off (the macOS
/// default), F1–F12 do these on their own and act as F-keys with fn (Globe)
/// held. With it on, it's the other way round. Karabiner-Elements, when
/// installed, decides the top row itself from its "Function keys" settings.
enum FunctionKeys {
    static let sectionName = "Top row"
    static let sectionColor = "#64748B"   // slate

    /// Apple silicon MacBook top row, which is also Karabiner's default.
    static let defaults: [String: String] = [
        "f1": "display_brightness_decrement", "f2": "display_brightness_increment",
        "f3": "mission_control", "f4": "spotlight",
        "f5": "dictation", "f6": "do_not_disturb",
        "f7": "rewind", "f8": "play_or_pause", "f9": "fast_forward",
        "f10": "mute", "f11": "volume_decrement", "f12": "volume_increment",
    ]

    /// Karabiner and Apple key names → what's printed on the key.
    static let titles: [String: String] = [
        "display_brightness_decrement": "Brightness −",
        "display_brightness_increment": "Brightness +",
        "mission_control": "Mission Control",
        "launchpad": "Launchpad", "vk_launchpad": "Launchpad",
        "spotlight": "Spotlight",
        "dictation": "Dictation",
        "do_not_disturb": "Do Not Disturb",
        "illumination_decrement": "Keyboard light −",
        "illumination_increment": "Keyboard light +",
        "rewind": "Previous", "scan_previous_track": "Previous",
        "play_or_pause": "Play / Pause",
        "fast_forward": "Next", "fastforward": "Next", "scan_next_track": "Next",
        "mute": "Mute",
        "volume_decrement": "Volume −", "volume_increment": "Volume +",
        "dashboard": "Dashboard", "eject": "Eject",
        "apple_top_case_display_brightness_decrement": "Brightness −",
        "apple_top_case_display_brightness_increment": "Brightness +",
        "apple_top_case_illumination_decrement": "Keyboard light −",
        "apple_top_case_illumination_increment": "Keyboard light +",
        "shell_command": "Shell command",
    ]

    /// The symbols printed on Mac keyboards' top row, as SF Symbols.
    static let symbols: [String: String] = [
        "Brightness −": "sun.min", "Brightness +": "sun.max",
        "Mission Control": "rectangle.3.group",
        "Launchpad": "square.grid.3x2",
        "Spotlight": "magnifyingglass",
        "Dictation": "mic",
        "Do Not Disturb": "moon",
        "Keyboard light −": "light.min", "Keyboard light +": "light.max",
        "Previous": "backward", "Play / Pause": "playpause", "Next": "forward",
        "Mute": "speaker", "Volume −": "speaker.wave.1", "Volume +": "speaker.wave.3",
        "Eject": "eject",
    ]

    /// True when F1–F12 act as standard function keys without fn.
    static func standardFunctionKeys() -> Bool {
        let global = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)
        return (global?["com.apple.keyboard.fnState"] as? NSNumber)?.boolValue ?? false
    }

    /// The top-row actions, each on the layer where it happens: no modifiers
    /// normally, fn with standard function keys on. Keys set to plain F-keys
    /// (or to something unnamed) are left out.
    static func bindings(overrides: [String: String], standardKeys: Bool) -> [KeyBinding] {
        (1...12).compactMap { n in
            let key = "f\(n)"
            let target = overrides[key] ?? defaults[key] ?? ""
            guard let title = titles[target] else { return nil }
            return KeyBinding(
                keyCode: key,
                mandatory: standardKeys ? [.fn] : [],
                allowsAnyExtra: false,
                title: title,
                detail: overrides[key] != nil ? "Karabiner function keys" : "Top row",
                kind: .other,
                ruleName: sectionName,
                ruleColor: sectionColor,
                isGlobal: false,
                symbol: symbols[title]
            )
        }
    }

    /// Keys whose plain press is a top-row action, so their F-key shortcuts
    /// need fn held.
    static func mediaKeys(overrides: [String: String]) -> Set<String> {
        Set((1...12).map { "f\($0)" }.filter { titles[overrides[$0] ?? defaults[$0] ?? ""] != nil })
    }
}
