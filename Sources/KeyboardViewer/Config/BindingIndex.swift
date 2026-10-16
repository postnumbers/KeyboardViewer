import Foundation

enum BindingKind {
    case app        // launches or focuses an app (open -a, or a global ⌃⌥⌘ hotkey)
    case keystroke  // sends keys (navigation, editing)
    case mouse      // mouse movement, scroll or clicks
    case other
}

/// One Hyper-layer manipulator, flattened for display.
struct KeyBinding: Identifiable {
    let id = UUID()
    let keyCode: String
    let mandatory: Mods
    let allowsAnyExtra: Bool   // `"optional": ["any"]`
    let title: String          // e.g. "Safari", "delete word left"
    let detail: String         // e.g. "⌃⌥⇧⌘W", "open -a"
    let kind: BindingKind
    let ruleName: String
    /// The rule's "color" key, or one picked automatically if it has none.
    var ruleColor: String?
    /// True for unconditional rules (e.g. shift + spacebar -> underscore) that
    /// fire with or without Hyper, and can therefore take over a Hyper chord.
    let isGlobal: Bool
    /// SF Symbol drawn instead of the title, as printed on the key (top row).
    var symbol: String? = nil
    /// Just the character the key types: drawn on a plain, untinted key.
    var isTypedCharacter = false
    /// The title is a character the key types (plain, ⇧, ⌥ or ⇧⌥): drawn
    /// large, like the glyph on a keycap.
    var isCharacter = false
}

/// All Hyper bindings in file order, plus lookup of the active layer.
struct BindingIndex {
    private(set) var bindings: [KeyBinding] = []

    /// Keys that set the Hyper variable when held (usually just caps_lock).
    /// Without one, no Hyper binding can be triggered, so none are listed.
    private(set) var hyperKeys: [String] = []

    /// Keys karabiner.json turns into ⌃⌥⇧⌘ (the other common way of making
    /// a Hyper key). They're labelled "Hyper" but don't open the Hyper layer,
    /// since the bindings here depend on the variable.
    private(set) var fourModifierKeys: [String] = []

    /// Keys to label "Hyper" on the keyboard.
    var hyperLabelKeys: Set<String> { Set(hyperKeys).union(fourModifierKeys) }

    /// karabiner.json's function key settings: "f4" → "vk_launchpad".
    /// Keys not listed keep the default (see FunctionKeys).
    private(set) var functionKeyOverrides: [String: String] = [:]

    /// True when some key can open the Hyper layer.
    var hasHyperKey: Bool { !hyperKeys.isEmpty }

    /// Builds the index from the selected profile, keeping file order.
    ///
    /// Two kinds of manipulator are included:
    /// - Hyper bindings: conditions are exactly `variable_if <variable> == 1`.
    /// - Global bindings: no conditions at all, on a non-modifier key. Karabiner
    ///   applies these while Hyper is held too, so when they come first in the
    ///   file they win the chord.
    /// Manipulators with other conditions (frontmost app, device, other
    /// variables) are skipped, because whether they apply depends on runtime state.
    static func build(from config: KarabinerConfig, variable: String = "HYPER") -> BindingIndex {
        var index = BindingIndex()
        let rules = config.activeProfile?.complexModifications?.rules ?? []

        for entry in config.activeProfile?.fnFunctionKeys ?? [] {
            guard let from = entry.from?.keyCode, let to = entry.to?.items.first else { continue }
            let name = to.keyCode ?? to.consumerKeyCode ?? to.appleVendorKeyboardKeyCode
                ?? to.appleVendorTopCaseKeyCode ?? (to.shellCommand != nil ? "shell_command" : "")
            index.functionKeyOverrides[from] = name
        }

        for rule in rules where rule.isEnabled {
            for m in rule.manipulators ?? [] {
                guard (m.type ?? "basic") == "basic",
                      let key = m.from?.keyCode
                else { continue }

                let conditions = m.conditions ?? []
                let tos = m.to?.items ?? []

                // Which key is the Hyper key, if any.
                let requiresHyper = conditions.contains { $0.name == variable }
                if !requiresHyper {
                    if tos.contains(where: { $0.setVariable?.name == variable && $0.setVariable?.value == .int(1) }),
                       !index.hyperKeys.contains(key) {
                        index.hyperKeys.append(key)
                    }
                    if conditions.isEmpty, Self.sendsAllFourModifiers(tos),
                       !index.fourModifierKeys.contains(key) {
                        index.fourModifierKeys.append(key)
                    }
                }

                let isHyper = !conditions.isEmpty
                    && conditions.allSatisfy { Self.isHyperCondition($0, variable) }
                let isGlobal = conditions.isEmpty && !Self.isModifierOrHyperKey(key)
                guard isHyper || isGlobal else { continue }

                let mandatoryNames = m.from?.modifiers?.mandatory?.items ?? []
                let optionalNames = m.from?.modifiers?.optional?.items ?? []
                var mandatory: Mods = []
                for name in mandatoryNames {
                    if let mod = Mods(karabinerName: name) { mandatory.insert(mod) }
                }

                let output = Describe.output(tos)
                // Fall back to the rule's description: the underscore rule's
                // manipulators have none, but the rule is "shift + spacebar -> underscore".
                let title = Describe.title(
                    description: m.description ?? rule.description,
                    fallback: output.detail
                )

                index.bindings.append(KeyBinding(
                    keyCode: key,
                    mandatory: mandatory,
                    allowsAnyExtra: optionalNames.contains("any"),
                    title: title,
                    detail: output.detail,
                    kind: output.kind,
                    ruleName: rule.description ?? "",
                    ruleColor: rule.color,
                    isGlobal: isGlobal
                ))
            }
        }
        // Hyper bindings no key can reach aren't shown; global ones still are.
        if !index.hasHyperKey {
            index.bindings.removeAll { !$0.isGlobal }
        }
        // The Hyper key's own manipulator isn't a binding to show on it.
        let hyperLabelKeys = index.hyperLabelKeys
        index.bindings.removeAll { $0.isGlobal && hyperLabelKeys.contains($0.keyCode) }
        index.assignMissingColors()
        return index
    }

    /// Gives every rule that has bindings but no usable `color` its own colour,
    /// different from the ones set in the file. Assigned in file order, so a
    /// rule keeps its colour unless rules are added or coloured above it.
    private mutating func assignMissingColors() {
        var used = Set<String>()
        var needing: [String] = []
        for b in bindings {
            if let hex = SectionPalette.canonicalHex(b.ruleColor) {
                used.insert(hex)
            } else if !needing.contains(b.ruleName) {
                needing.append(b.ruleName)
            }
        }
        guard !needing.isEmpty else { return }
        let assigned = SectionPalette.assignAutomatic(to: needing, avoiding: used)
        for i in bindings.indices where SectionPalette.canonicalHex(bindings[i].ruleColor) == nil {
            bindings[i].ruleColor = assigned[bindings[i].ruleName]
        }
    }

    /// `to` is one modifier key held with the other three, e.g.
    /// `{"key_code": "left_shift", "modifiers": ["left_command", "left_control", "left_option"]}`.
    private static func sendsAllFourModifiers(_ tos: [ToEvent]) -> Bool {
        let keys = tos.filter { $0.keyCode != nil }
        guard keys.count == 1, let t = keys.first, let code = t.keyCode,
              let mod = Mods(karabinerName: code) else { return false }
        var all: Mods = mod
        for name in t.modifiers?.items ?? [] {
            if let m = Mods(karabinerName: name) { all.insert(m) }
        }
        return all.isSuperset(of: [.control, .option, .shift, .command])
    }

    private static func isHyperCondition(_ c: Condition, _ variable: String) -> Bool {
        c.type == "variable_if" && c.name == variable && c.value == .int(1)
    }

    /// Rules triggered by modifier keys themselves (double-tap shift, command
    /// toggles) or by Caps Lock aren't key bindings the overlay can show.
    private static func isModifierOrHyperKey(_ key: String) -> Bool {
        key == "caps_lock" || Mods(karabinerName: key) != nil
    }

    /// The binding each key would trigger with Hyper plus `held`.
    ///
    /// Mirrors Karabiner's matching: a manipulator matches when every mandatory
    /// modifier is held and no other tracked modifier is held (unless its optional
    /// list contains "any"). The first matching manipulator in file order wins.
    func layer(for held: Mods) -> [String: KeyBinding] {
        var result: [String: KeyBinding] = [:]
        for b in orderedLayer(for: held) { result[b.keyCode] = b }
        return result
    }

    /// Same as `layer(for:)`, as a list in file order (one binding per key).
    func orderedLayer(for held: Mods, globalOnly: Bool = false) -> [KeyBinding] {
        var seen = Set<String>()
        var result: [KeyBinding] = []
        for b in bindings where (!globalOnly || b.isGlobal) && Self.matches(b, held) {
            if seen.insert(b.keyCode).inserted { result.append(b) }
        }
        return result
    }

    /// Karabiner's rule: every mandatory modifier held, and nothing else held
    /// unless the manipulator allows "any" extra modifiers.
    static func matches(_ b: KeyBinding, _ held: Mods) -> Bool {
        b.allowsAnyExtra ? held.isSuperset(of: b.mandatory) : held == b.mandatory
    }

    /// Modifier combinations that have at least one binding, for the legend.
    var populatedLayers: [Mods] {
        var seen: [Mods] = []
        for b in bindings where !seen.contains(b.mandatory) { seen.append(b.mandatory) }
        return seen.sorted { ($0.count, $0.rawValue) < ($1.count, $1.rawValue) }
    }
}
