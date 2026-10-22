import AppKit
import SwiftUI

/// The colour for one section (rule) of karabiner.json.
struct SectionStyle: Hashable {
    let name: String    // shown in the legend
    let base: Color     // key tint and border
    let text: Color     // description text: the colour darkened in Light Mode, lightened in Dark Mode
}

/// Colours bindings by the rule they come from.
///
/// Each rule in karabiner.json carries its colour:
///
///     { "description": "Applications",
///       "color name": "blue",        ← for your reference only
///       "color": "#3B82F6",          ← what the overlay uses
///       "manipulators": [...] }
///
/// `color` is a hex value. For older files it may also be one of the names in
/// `named`. Rules without a usable colour get one from `automatic` (see
/// `BindingIndex.build`).
enum SectionPalette {
    /// Colours handed out, in this order, to rules without a `color`. Ones
    /// another rule already uses are skipped. Grey, teal and indigo come last
    /// because the option-character, app-menu and macOS sections use them.
    static let automatic: [String] = [
        "#3B82F6", "#22C55E", "#F97316", "#A855F7", "#EC4899", "#06B6D4",
        "#EAB308", "#EF4444", "#10B981", "#A0703C", "#84CC16", "#F43F5E",
        "#14B8A6", "#6366F1", "#6B7280",
    ]

    /// The colour as "#RRGGBB", or nil if it isn't a hex value or known name.
    static func canonicalHex(_ value: String?) -> String? {
        guard let value else { return nil }
        let key = value.trimmingCharacters(in: .whitespaces).lowercased()
        if let hex = named[key] { return String(format: "#%06X", hex) }
        let digits = key.hasPrefix("#") ? String(key.dropFirst()) : key
        guard digits.count == 6, let hex = UInt32(digits, radix: 16) else { return nil }
        return String(format: "#%06X", hex)
    }

    /// Picks a colour for each rule name in `needing`, in order, avoiding
    /// `used`. Wraps around the palette if there are more rules than colours.
    static func assignAutomatic(to needing: [String], avoiding used: Set<String>) -> [String: String] {
        var taken = used
        var result: [String: String] = [:]
        var fallback = 0
        for name in needing where result[name] == nil {
            if let free = automatic.first(where: { !taken.contains($0) }) {
                result[name] = free
                taken.insert(free)
            } else {
                result[name] = automatic[fallback % automatic.count]
                fallback += 1
            }
        }
        return result
    }

    /// Accepted in `color` for backwards compatibility.
    static let named: [String: UInt32] = [
        "yellow": 0xEAB308, "orange": 0xF97316, "red": 0xEF4444, "pink": 0xEC4899,
        "purple": 0xA855F7, "indigo": 0x6366F1, "blue": 0x3B82F6, "cyan": 0x06B6D4,
        "teal": 0x14B8A6, "mint": 0x10B981, "green": 0x22C55E, "brown": 0xA0703C,
        "gray": 0x6B7280, "grey": 0x6B7280,
    ]

    /// How far description text moves toward black (Light Mode) or white
    /// (Dark Mode). High enough to read easily on the tinted key, low enough
    /// to keep the section's hue.
    static let lightModeDarkening: CGFloat = 0.55
    static let darkModeLightening: CGFloat = 0.60

    static func style(for binding: KeyBinding) -> SectionStyle? {
        style(ruleName: binding.ruleName, color: binding.ruleColor)
    }

    static func style(ruleName: String, color: String?) -> SectionStyle? {
        guard let color, let base = parse(color) else { return nil }
        return SectionStyle(name: displayName(ruleName), base: Color(nsColor: base), text: readableText(on: base))
    }

    /// The sections these bindings come from, in order of first appearance,
    /// for the legend.
    static func present(in bindings: [KeyBinding]) -> [SectionStyle] {
        var seen = Set<String>()
        var result: [SectionStyle] = []
        for binding in bindings {
            guard let section = style(for: binding), seen.insert(section.name).inserted else { continue }
            result.append(section)
        }
        return result
    }

    /// Drops a leading "[tag]" and a trailing "(note)" from a rule name:
    /// "[Set] Text Editing (subset)" → "Text Editing"
    static func displayName(_ ruleName: String) -> String {
        var s = ruleName.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("["), let close = s.firstIndex(of: "]") {
            s = String(s[s.index(after: close)...]).trimmingCharacters(in: .whitespaces)
        }
        if s.hasSuffix(")"), let open = s.lastIndex(of: "(") {
            s = String(s[..<open]).trimmingCharacters(in: .whitespaces)
        }
        return s
    }

    // MARK: - Helpers

    private static func parse(_ value: String) -> NSColor? {
        guard let hex = canonicalHex(value), let rgb = UInt32(hex.dropFirst(), radix: 16) else { return nil }
        return nsColor(rgb)
    }

    private static func readableText(on base: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return base.blended(
                withFraction: isDark ? darkModeLightening : lightModeDarkening,
                of: isDark ? .white : .black
            ) ?? base
        })
    }

    private static func nsColor(_ hex: UInt32) -> NSColor {
        NSColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
