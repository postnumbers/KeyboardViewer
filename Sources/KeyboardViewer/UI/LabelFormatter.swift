import Foundation

/// Breaks long compound terms onto two lines so they fit on a key:
///
///     "shift_down"    → "shift" / "down"
///     "OmniOutliner"  → "Omni" / "Outliner"
///     "FontCreator"   → "Font" / "Creator"
///
/// Underscores always split (and are dropped). Joined-up capitalised words
/// split before each capital that follows a lowercase letter, but only when
/// the word is long enough not to fit on one line, and never after a single
/// letter, so short or prefixed names like "NotePlan" and "iTerm2" stay whole.
enum LabelFormatter {
    static let camelCaseMinimumLength = 9

    static func format(_ title: String) -> String {
        title
            .split(separator: " ", omittingEmptySubsequences: false)
            .map { split(String($0)) }
            .joined(separator: " ")
    }

    static func split(_ word: String) -> String {
        if word.contains("_") {
            let parts = word.split(separator: "_").map(String.init)
            if parts.count > 1 { return parts.joined(separator: "\n") }
        }
        guard word.count >= camelCaseMinimumLength else { return word }

        var lines: [String] = []
        var current = ""
        var previous: Character?
        for ch in word {
            if let p = previous, p.isLowercase, ch.isUppercase, current.count >= 2 {
                lines.append(current)
                current = ""
            }
            current.append(ch)
            previous = ch
        }
        lines.append(current)
        return lines.joined(separator: "\n")
    }
}
