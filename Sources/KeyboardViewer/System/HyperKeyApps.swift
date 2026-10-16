import AppKit

/// Apps other than Karabiner-Elements that turn Caps Lock into a Hyper key.
/// When one is running, Caps Lock is labelled "Hyper". For anything not
/// listed (BetterTouchTool, Keyboard Maestro, a hidutil script…), set
/// "Caps Lock Label" to Hyper in the menu bar.
enum HyperKeyApps {
    /// Bundle identifiers, then app names as a fallback.
    static let bundleIDs: Set<String> = [
        "com.knollsoft.Hyperkey",
        "com.knollsoft.Superkey",
    ]
    static let names: Set<String> = ["Hyperkey", "Superkey"]

    /// The name of a running Hyper key app, if there is one.
    static func running() -> String? {
        for app in NSWorkspace.shared.runningApplications {
            let name = app.localizedName ?? ""
            if let id = app.bundleIdentifier, bundleIDs.contains(id) { return name.isEmpty ? id : name }
            if names.contains(name) { return name }
        }
        return nil
    }
}

/// What Caps Lock is labelled. Remembered between launches.
enum CapsLockLabel: String, CaseIterable, Identifiable {
    case automatic   // "Hyper" if karabiner.json or a Hyper key app makes it one
    case hyper
    case capsLock

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: return "Automatic"
        case .hyper: return "Hyper"
        case .capsLock: return "Caps Lock"
        }
    }
}
