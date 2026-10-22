import Foundation

/// macOS virtual key codes (kVK_*) for the keys the overlay draws, keyed by the
/// Karabiner key_code names the layout uses. Virtual key codes identify a
/// physical key position, independent of the input language.
enum KeyCodes {
    static let byName: [String: UInt16] = [
        "non_us_backslash": 0x0A,   // ISO: § left of 1 (kVK_ISO_Section)
        "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03, "h": 0x04, "g": 0x05,
        "z": 0x06, "x": 0x07, "c": 0x08, "v": 0x09, "b": 0x0B, "q": 0x0C,
        "w": 0x0D, "e": 0x0E, "r": 0x0F, "y": 0x10, "t": 0x11,
        "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "6": 0x16, "5": 0x17,
        "equal_sign": 0x18, "9": 0x19, "7": 0x1A, "hyphen": 0x1B, "8": 0x1C, "0": 0x1D,
        "close_bracket": 0x1E, "o": 0x1F, "u": 0x20, "open_bracket": 0x21,
        "i": 0x22, "p": 0x23, "return_or_enter": 0x24, "l": 0x25, "j": 0x26,
        "quote": 0x27, "k": 0x28, "semicolon": 0x29, "backslash": 0x2A,
        "comma": 0x2B, "slash": 0x2C, "n": 0x2D, "m": 0x2E, "period": 0x2F,
        "tab": 0x30, "spacebar": 0x31, "grave_accent_and_tilde": 0x32,
        "delete_or_backspace": 0x33, "escape": 0x35,
        "f5": 0x60, "f6": 0x61, "f7": 0x62, "f3": 0x63, "f8": 0x64, "f9": 0x65,
        "f11": 0x67, "f10": 0x6D, "f12": 0x6F,
        "home": 0x73, "page_up": 0x74, "delete_forward": 0x75, "f4": 0x76,
        "end": 0x77, "f2": 0x78, "page_down": 0x79, "f1": 0x7A,
        "left_arrow": 0x7B, "right_arrow": 0x7C, "down_arrow": 0x7D, "up_arrow": 0x7E,
    ]

    static let byCode: [UInt16: String] = Dictionary(uniqueKeysWithValues: byName.map { ($1, $0) })

    /// Keys that type a character, in keyboard order.
    static let characterKeys: [String] =
        ["non_us_backslash", "grave_accent_and_tilde"] + "1234567890".map(String.init) + ["hyphen", "equal_sign"]
        + "qwertyuiop".map(String.init) + ["open_bracket", "close_bracket", "backslash"]
        + "asdfghjkl".map(String.init) + ["semicolon", "quote"]
        + "zxcvbnm".map(String.init) + ["comma", "period", "slash"]

    /// AppKit function-key characters (NSUpArrowFunctionKey etc.) and control
    /// characters that menus use as key equivalents for non-printing keys.
    static let specialCharacters: [UInt32: String] = {
        var map: [UInt32: String] = [
            0xF700: "up_arrow", 0xF701: "down_arrow", 0xF702: "left_arrow", 0xF703: "right_arrow",
            0xF728: "delete_forward", 0xF729: "home", 0xF72B: "end",
            0xF72C: "page_up", 0xF72D: "page_down",
            0x08: "delete_or_backspace", 0x7F: "delete_or_backspace",
            0x0D: "return_or_enter", 0x03: "return_or_enter",
            0x1B: "escape", 0x09: "tab", 0x20: "spacebar",
        ]
        for n in 1...12 { map[0xF703 + UInt32(n)] = "f\(n)" }   // NSF1FunctionKey = 0xF704
        return map
    }()

    /// Menu glyph codes (kMenu…Glyph) that menus report for keys with no
    /// character. Only the common ones; unknown glyphs are ignored.
    static let menuGlyphs: [Int: String] = {
        var map: [Int: String] = [
            0x02: "tab", 0x09: "spacebar", 0x0A: "delete_forward", 0x0B: "return_or_enter",
            0x17: "delete_or_backspace", 0x1B: "escape",
            0x64: "left_arrow", 0x65: "right_arrow", 0x68: "up_arrow", 0x6A: "down_arrow",
        ]
        for n in 1...12 { map[0x6E + n] = "f\(n)" }   // kMenuF1Glyph = 0x6F
        return map
    }()
}
