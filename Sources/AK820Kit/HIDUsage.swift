import Foundation

/// A key that can be sent by the keyboard (USB HID keyboard usage).
public struct HIDKey: Hashable, Identifiable {
    public let code: UInt8
    public let name: String
    public var id: UInt8 { code }
}

public enum HIDUsage {
    /// Assignable target keys, grouped in display order.
    public static let keys: [HIDKey] = {
        var k: [HIDKey] = []
        for (i, c) in "ABCDEFGHIJKLMNOPQRSTUVWXYZ".enumerated() { k.append(HIDKey(code: UInt8(0x04 + i), name: String(c))) }
        for n in 1...10 { k.append(HIDKey(code: UInt8(0x1D + n), name: String(n % 10))) }
        let named: [(UInt8, String)] = [
            (0x28, "Return"), (0x29, "Esc"), (0x2A, "Backspace"), (0x2B, "Tab"), (0x2C, "Space"),
            (0x2D, "-"), (0x2E, "="), (0x2F, "["), (0x30, "]"), (0x31, "\\"), (0x33, ";"), (0x34, "'"),
            (0x35, "`"), (0x36, ","), (0x37, "."), (0x38, "/"), (0x39, "Caps Lock"), (0x64, "§ (ISO)"),
        ]
        k += named.map { HIDKey(code: $0.0, name: $0.1) }
        for n in 1...12 { k.append(HIDKey(code: UInt8(0x39 + n), name: "F\(n)")) }
        for n in 13...24 { k.append(HIDKey(code: UInt8(0x5B + n), name: "F\(n)")) }
        let nav: [(UInt8, String)] = [
            (0x46, "Print Screen"), (0x47, "Scroll Lock"), (0x48, "Pause"), (0x49, "Insert"),
            (0x4A, "Home"), (0x4B, "Page Up"), (0x4C, "Delete"), (0x4D, "End"), (0x4E, "Page Down"),
            (0x4F, "→"), (0x50, "←"), (0x51, "↓"), (0x52, "↑"),
            (0x53, "Num Lock"), (0x54, "Num /"), (0x55, "Num *"), (0x56, "Num -"), (0x57, "Num +"),
            (0x58, "Num Enter"), (0x59, "Num 1"), (0x5A, "Num 2"), (0x5B, "Num 3"), (0x5C, "Num 4"),
            (0x5D, "Num 5"), (0x5E, "Num 6"), (0x5F, "Num 7"), (0x60, "Num 8"), (0x61, "Num 9"),
            (0x62, "Num 0"), (0x63, "Num ."), (0x65, "Menu"),
        ]
        k += nav.map { HIDKey(code: $0.0, name: $0.1) }
        return k
    }()

    public static func name(_ code: UInt8) -> String {
        keys.first { $0.code == code }?.name ?? String(format: "0x%02X", code)
    }

    /// Modifier bits used by the keyboard's "key combination" entries (standard USB order).
    public static let modifiers: [(bit: UInt8, name: String)] = [
        (0x01, "⌃ Control"), (0x02, "⇧ Shift"), (0x04, "⌥ Option"), (0x08, "⌘ Command"),
        (0x10, String(localized: "⌃ Control (right)")), (0x20, String(localized: "⇧ Shift (right)")),
        (0x40, String(localized: "⌥ Option (right)")), (0x80, String(localized: "⌘ Command (right)")),
    ]

    public static func modifierSymbols(_ mask: UInt8) -> String {
        var s = ""
        if mask & 0x11 != 0 { s += "⌃" }
        if mask & 0x44 != 0 { s += "⌥" }
        if mask & 0x22 != 0 { s += "⇧" }
        if mask & 0x88 != 0 { s += "⌘" }
        return s
    }

    /// USB HID usage of a modifier bit (0x01 → 0xE0 … 0x80 → 0xE7), used in macros.
    public static func modifierUsage(bit: UInt8) -> UInt8 {
        UInt8(0xE0 + bit.trailingZeroBitCount)
    }

    /// Consumer-page (multimedia) codes.
    public static let media: [(code: UInt16, name: String)] = [
        (0xCD, String(localized: "Play / Pause")), (0xB5, String(localized: "Next track")), (0xB6, String(localized: "Previous track")), (0xB7, String(localized: "Stop")),
        (0xE2, String(localized: "Mute")), (0xE9, String(localized: "Volume +")), (0xEA, String(localized: "Volume −")),
        (0x6F, String(localized: "Display brightness +")), (0x70, String(localized: "Display brightness −")),
    ]

    public static func mediaName(_ code: UInt16) -> String {
        media.first { $0.code == code }?.name ?? String(format: "Media 0x%02X", code)
    }

    /// macOS virtual key code (kVK_*) → USB HID usage, for "press a key to pick it".
    public static let fromMacKeyCode: [UInt16: UInt8] = [
        0x00: 0x04, 0x0B: 0x05, 0x08: 0x06, 0x02: 0x07, 0x0E: 0x08, 0x03: 0x09, 0x05: 0x0A, 0x04: 0x0B,
        0x22: 0x0C, 0x26: 0x0D, 0x28: 0x0E, 0x25: 0x0F, 0x2E: 0x10, 0x2D: 0x11, 0x1F: 0x12, 0x23: 0x13,
        0x0C: 0x14, 0x0F: 0x15, 0x01: 0x16, 0x11: 0x17, 0x20: 0x18, 0x09: 0x19, 0x0D: 0x1A, 0x07: 0x1B,
        0x10: 0x1C, 0x06: 0x1D,
        0x12: 0x1E, 0x13: 0x1F, 0x14: 0x20, 0x15: 0x21, 0x17: 0x22, 0x16: 0x23, 0x1A: 0x24, 0x1C: 0x25,
        0x19: 0x26, 0x1D: 0x27,
        0x24: 0x28, 0x35: 0x29, 0x33: 0x2A, 0x30: 0x2B, 0x31: 0x2C, 0x1B: 0x2D, 0x18: 0x2E, 0x21: 0x2F,
        0x1E: 0x30, 0x2A: 0x31, 0x29: 0x33, 0x27: 0x34, 0x32: 0x35, 0x2B: 0x36, 0x2F: 0x37, 0x2C: 0x38,
        0x39: 0x39, 0x0A: 0x64,
        0x7A: 0x3A, 0x78: 0x3B, 0x63: 0x3C, 0x76: 0x3D, 0x60: 0x3E, 0x61: 0x3F, 0x62: 0x40, 0x64: 0x41,
        0x65: 0x42, 0x6D: 0x43, 0x67: 0x44, 0x6F: 0x45, 0x69: 0x68, 0x6B: 0x69, 0x71: 0x6A,
        0x72: 0x49, 0x73: 0x4A, 0x74: 0x4B, 0x75: 0x4C, 0x77: 0x4D, 0x79: 0x4E,
        0x7C: 0x4F, 0x7B: 0x50, 0x7D: 0x51, 0x7E: 0x52,
        0x47: 0x53, 0x4B: 0x54, 0x43: 0x55, 0x4E: 0x56, 0x45: 0x57, 0x4C: 0x58, 0x53: 0x59, 0x54: 0x5A,
        0x55: 0x5B, 0x56: 0x5C, 0x57: 0x5D, 0x58: 0x5E, 0x59: 0x5F, 0x5B: 0x60, 0x5C: 0x61, 0x52: 0x62,
        0x41: 0x63,
    ]

    /// Characters a text macro can type (US layout) → (usage, needs Shift).
    public static func usage(for ch: Character) -> (UInt8, Bool)? {
        let shifted: [Character: Character] = [
            "!": "1", "@": "2", "#": "3", "$": "4", "%": "5", "^": "6", "&": "7", "*": "8", "(": "9", ")": "0",
            "_": "-", "+": "=", "{": "[", "}": "]", "|": "\\", ":": ";", "\"": "'", "~": "`", "<": ",", ">": ".", "?": "/",
        ]
        if ch == " " { return (0x2C, false) }
        if ch == "\n" { return (0x28, false) }
        if ch == "\t" { return (0x2B, false) }
        if let base = shifted[ch], let (u, _) = usage(for: base) { return (u, true) }
        if ch.isASCII, ch.isLetter {
            let up = ch.uppercased()
            guard let k = keys.first(where: { $0.name == up }) else { return nil }
            return (k.code, ch.isUppercase)
        }
        let plain: [Character: UInt8] = [
            "1": 0x1E, "2": 0x1F, "3": 0x20, "4": 0x21, "5": 0x22, "6": 0x23, "7": 0x24, "8": 0x25, "9": 0x26, "0": 0x27,
            "-": 0x2D, "=": 0x2E, "[": 0x2F, "]": 0x30, "\\": 0x31, ";": 0x33, "'": 0x34, "`": 0x35, ",": 0x36, ".": 0x37, "/": 0x38,
        ]
        if let u = plain[ch] { return (u, false) }
        return nil
    }
}
