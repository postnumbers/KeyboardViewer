import Foundation

/// Everything the keyboard view renders from.
@MainActor
final class OverlayState: ObservableObject {
    @Published var index = BindingIndex()
    @Published var hyperHeld = false
    @Published var heldMods: Mods = []

    /// Keeps the window on screen when Hyper isn't held. Toggled by the pin
    /// button on the window, the menu bar, or Hyper + /. Remembered between launches.
    @Published var pinned = UserDefaults.standard.bool(forKey: "pinned") {
        didSet { UserDefaults.standard.set(pinned, forKey: "pinned") }
    }
    /// Also pop the window up while Hyper is held. Remembered between launches.
    @Published var autoShowOnHyper = UserDefaults.standard.object(forKey: "autoShowOnHyper") as? Bool ?? true {
        didSet { UserDefaults.standard.set(autoShowOnHyper, forKey: "autoShowOnHyper") }
    }

    /// Show what ⌘ ⌥ ⌃ ⇧ do in the frontmost app (menus, macOS shortcuts,
    /// characters) when held without Hyper. Toggled from the menu bar or
    /// Hyper + ⇧ + /. Remembered between launches.
    @Published var appShortcutsEnabled = UserDefaults.standard.object(forKey: "appShortcutsEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(appShortcutsEnabled, forKey: "appShortcutsEnabled") }
    }

    /// Pop the window up after ⌘, ⌥ or ⌃ has been held for a moment, to show
    /// what they do in the frontmost app. Off by default. Remembered.
    @Published var showWhileModifiersHeld = UserDefaults.standard.bool(forKey: "showWhileModifiersHeld") {
        didSet { UserDefaults.standard.set(showWhileModifiersHeld, forKey: "showWhileModifiersHeld") }
    }

    /// The built-in ⌃⌥⇧K / ⌃⌥⇧L shortcuts. On by default. Remembered.
    @Published var builtInShortcutsEnabled = UserDefaults.standard.object(forKey: "builtInShortcutsEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(builtInShortcutsEnabled, forKey: "builtInShortcutsEnabled") }
    }

    /// False when there's no karabiner.json: the app then works as an app and
    /// system shortcut viewer, with the Hyper parts hidden.
    @Published var karabinerAvailable = true

    /// What Caps Lock is labelled. Remembered between launches.
    @Published var capsLockLabel = CapsLockLabel(rawValue: UserDefaults.standard.string(forKey: "capsLockLabel") ?? "") ?? .automatic {
        didSet { UserDefaults.standard.set(capsLockLabel.rawValue, forKey: "capsLockLabel") }
    }

    /// Name of a running app that makes Caps Lock a Hyper key (Hyperkey…).
    @Published var hyperKeyApp: String?

    /// True when karabiner.json has a key that opens the Hyper layer.
    var hyperAvailable: Bool {
        karabinerAvailable && index.hasHyperKey
    }

    /// Whether `code` is drawn as a Hyper key.
    func isHyperKey(_ code: String) -> Bool {
        if code == "caps_lock" {
            switch capsLockLabel {
            case .hyper: return true
            case .capsLock: return false
            case .automatic: return index.hyperLabelKeys.contains(code) || hyperKeyApp != nil
            }
        }
        return index.hyperLabelKeys.contains(code)
    }

    /// What's printed on the key.
    func legend(for def: KeyDef) -> String {
        isHyperKey(def.code) ? "Hyper" : def.legend
    }

    /// A Hyper key is lit while the Hyper layer is open, or, when it works by
    /// sending ⌃⌥⇧⌘ (Hyperkey and similar), while all four are held.
    func isHyperKeyActive(_ code: String) -> Bool {
        if index.hyperKeys.contains(code) { return hyperHeld }
        return heldMods.isSuperset(of: [.control, .option, .shift, .command])
    }

    /// "Caps Lock", or the name of whichever key opens the Hyper layer.
    var hyperKeyName: String {
        guard let key = index.hyperKeys.first, key != "caps_lock" else { return "Caps Lock" }
        return Describe.keyName(key)
    }

    @Published var statusMessage: String?

    /// App shortcuts are always on without a Hyper key, since there's no
    /// Hyper layer to show instead.
    var appShortcutsActive: Bool {
        appShortcutsEnabled || !hyperAvailable
    }

    // MARK: - What the system and the frontmost app do

    /// Name of the frontmost app whose menus were read.
    @Published var frontAppName = ""
    /// Shortcuts from the frontmost app's menus, enabled items first.
    @Published var appShortcuts: [KeyBinding] = []
    /// Why there are no menu shortcuts, if there's a reason to show.
    @Published var appShortcutsNote: String?
    /// macOS's own shortcuts (Mission Control, screenshots, Spotlight…).
    @Published var systemShortcuts: [KeyBinding] = []
    /// "Use F1, F2, etc. keys as standard function keys" (Keyboard settings).
    @Published var standardFunctionKeys = false
    /// What each key types on its own and with ⇧, with the current layout.
    @Published var typedCharacters: [KeyBinding] = []
    /// What ⌥ and ⇧⌥ type with the current keyboard layout.
    @Published var optionCharacters: [KeyBinding] = []

    // MARK: - The layer on screen

    /// The keyboard always shows what pressing a key does right now: the
    /// Hyper layer only while Hyper is held, otherwise the held modifiers on
    /// their own (or no modifiers), where a key with no action shows just
    /// its name.
    var showsHyperLayer: Bool {
        hyperAvailable && hyperHeld
    }

    /// One binding per key, in the order sources get the keypress.
    var currentLayerOrdered: [KeyBinding] {
        showsHyperLayer ? index.orderedLayer(for: heldMods) : systemLayer(for: heldMods)
    }

    var currentLayer: [String: KeyBinding] {
        var result: [String: KeyBinding] = [:]
        for b in currentLayerOrdered { result[b.keyCode] = b }
        return result
    }

    /// What the held modifiers do without Hyper. Each key shows the first
    /// match, in the order the keypress reaches them:
    /// 1. Karabiner rules that apply without Hyper (Karabiner sees keys first)
    /// 2. macOS shortcuts
    /// 3. the frontmost app's menu shortcuts
    /// 4. for ⌥ and ⇧⌥ alone, the character the key types
    /// 5. on its own or with ⇧, the character the key types
    /// The top row's brightness/volume/media actions come after Karabiner.
    /// With app shortcuts switched off, only the Karabiner rules are shown.
    func systemLayer(for held: Mods) -> [KeyBinding] {
        var seen = Set<String>()
        var result: [KeyBinding] = []
        func add(_ b: KeyBinding) {
            if seen.insert(b.keyCode).inserted { result.append(b) }
        }
        index.orderedLayer(for: held, globalOnly: true).forEach(add)

        // The top row: brightness, volume, media… on their own (or with fn
        // if standard function keys are on). Where the plain key does one of
        // these, F-key shortcuts on it need fn as well.
        let overrides = index.functionKeyOverrides
        FunctionKeys.bindings(overrides: overrides, standardKeys: standardFunctionKeys)
            .filter { $0.mandatory == held }.forEach(add)
        let mediaKeys = standardFunctionKeys ? [] : FunctionKeys.mediaKeys(overrides: overrides)
        func needs(_ b: KeyBinding) -> Mods {
            mediaKeys.contains(b.keyCode) ? b.mandatory.union(.fn) : b.mandatory
        }

        if appShortcutsActive {
            systemShortcuts.filter { needs($0) == held }.forEach(add)
            appShortcuts.filter { needs($0) == held }.forEach(add)
            if held == [.option] || held == [.option, .shift] {
                optionCharacters.filter { $0.mandatory == held }.forEach(add)
            }
        }
        // Anything left types a character: "a", or "A" and "{" with ⇧.
        typedCharacters.filter { $0.mandatory == held }.forEach(add)
        return result
    }

    /// Sections for the legend: every Karabiner section in Hyper mode, and
    /// the sections on screen otherwise.
    var legendBindings: [KeyBinding] {
        showsHyperLayer ? index.bindings : currentLayerOrdered
    }

    var layerTitle: String {
        let mods = heldMods.symbols.trimmingCharacters(in: .whitespaces)
        if !showsHyperLayer && mods.isEmpty {
            return frontAppName.isEmpty ? "KeyboardViewer" : frontAppName
        }
        if showsHyperLayer {
            return mods.isEmpty ? "Hyper" : "Hyper + \(mods)"
        }
        return frontAppName.isEmpty ? mods : "\(mods)  ·  \(frontAppName)"
    }
}
