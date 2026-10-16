import Foundation

// Codable model for the parts of karabiner.json the overlay cares about.
// Unknown keys are ignored by JSONDecoder, so only what we read is modelled.
// Several fields are "one or many" in practice (Karabiner accepts both), e.g.
// `"to": { ... }` vs `"to": [ ... ]` and `"mandatory": "shift"` vs `["shift"]`.

struct KarabinerConfig: Decodable {
    let profiles: [Profile]

    var activeProfile: Profile? {
        profiles.first(where: { $0.selected == true }) ?? profiles.first
    }

    static func load(from url: URL) throws -> KarabinerConfig {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(KarabinerConfig.self, from: data)
    }
}

struct Profile: Decodable {
    let name: String?
    let selected: Bool?
    let complexModifications: ComplexModifications?
    /// What the F1–F12 keys do when pressed without fn (Karabiner's
    /// "Function keys" tab). Keys not listed keep Karabiner's defaults.
    let fnFunctionKeys: [SimpleModification]?

    enum CodingKeys: String, CodingKey {
        case name, selected
        case complexModifications = "complex_modifications"
        case fnFunctionKeys = "fn_function_keys"
    }
}

struct SimpleModification: Decodable {
    let from: FromEvent?
    let to: OneOrMany<ToEvent>?
}

struct ComplexModifications: Decodable {
    let rules: [Rule]?
}

struct Rule: Decodable {
    let description: String?
    let enabled: Bool?
    /// Not Karabiner fields (Karabiner ignores unknown keys on rules):
    /// `color` is the hex colour the overlay uses for this rule's keys,
    /// e.g. "#EAB308"; `color name` is a human-readable note, e.g. "yellow".
    let color: String?
    let colorName: String?
    let manipulators: [Manipulator]?

    enum CodingKeys: String, CodingKey {
        case description, enabled, color, manipulators
        case colorName = "color name"
    }

    /// Rules without an `enabled` key are enabled.
    var isEnabled: Bool { enabled ?? true }
}

struct Manipulator: Decodable {
    let type: String?
    let description: String?
    let from: FromEvent?
    let to: OneOrMany<ToEvent>?
    let conditions: [Condition]?
}

struct FromEvent: Decodable {
    let keyCode: String?
    let modifiers: FromModifiers?

    enum CodingKeys: String, CodingKey {
        case keyCode = "key_code"
        case modifiers
    }
}

struct FromModifiers: Decodable {
    let mandatory: StringList?
    let optional: StringList?
}

struct ToEvent: Decodable {
    let keyCode: String?
    let modifiers: StringList?
    let shellCommand: String?
    let pointingButton: String?
    let mouseKey: [String: Double]?
    let setVariable: SetVariable?
    let softwareFunction: Present?
    let sendUserCommand: Present?
    let consumerKeyCode: String?
    let appleVendorKeyboardKeyCode: String?
    let appleVendorTopCaseKeyCode: String?

    enum CodingKeys: String, CodingKey {
        case keyCode = "key_code"
        case modifiers
        case shellCommand = "shell_command"
        case pointingButton = "pointing_button"
        case mouseKey = "mouse_key"
        case setVariable = "set_variable"
        case softwareFunction = "software_function"
        case sendUserCommand = "send_user_command"
        case consumerKeyCode = "consumer_key_code"
        case appleVendorKeyboardKeyCode = "apple_vendor_keyboard_key_code"
        case appleVendorTopCaseKeyCode = "apple_vendor_top_case_key_code"
    }
}

struct SetVariable: Decodable {
    let name: String?
    let value: ConditionValue?
}

struct Condition: Decodable {
    let type: String
    let name: String?
    let value: ConditionValue?
}

enum ConditionValue: Decodable, Equatable {
    case int(Int)
    case bool(Bool)
    case string(String)

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let i = try? c.decode(Int.self) {
            self = .int(i)
        } else if let b = try? c.decode(Bool.self) {
            self = .bool(b)
        } else {
            self = .string(try c.decode(String.self))
        }
    }
}

// MARK: - Helpers

/// Decodes either a single value or an array of values.
struct OneOrMany<T: Decodable>: Decodable {
    let items: [T]

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let many = try? c.decode([T].self) {
            items = many
        } else {
            items = [try c.decode(T.self)]
        }
    }
}

typealias StringList = OneOrMany<String>

/// Records that a key was present without decoding its contents.
struct Present: Decodable {
    init(from decoder: Decoder) throws {}
}
