// Generated from the official driver's rgb-keyboard.xml (AK820 Pro, 81 keys).
// index = key_index = light_index: slot of the key in the 144-entry keymap / RGB tables.

public struct KeySpec: Identifiable, Hashable {
    public let index: Int
    public let label: String
    /// HID usage the key sends by default.
    public let defaultCode: UInt8
    /// Position in layout units (1 unit = a regular key pitch).
    public let x: Double, y: Double, w: Double, h: Double
    /// The official driver does not allow remapping this key on the Fn layer.
    public let fnLocked: Bool
    public var id: Int { index }
}

public enum Layout {
    public static let width = 16.41
    public static let height = 6.51
    public static let fnIndex = 96

    public static let keys: [KeySpec] = [
        KeySpec(index: 1, label: "Esc", defaultCode: 0x29, x: 0.000, y: 0.000, w: 1.005, h: 1.005, fnLocked: true),
        KeySpec(index: 2, label: "F1", defaultCode: 0x3a, x: 1.217, y: 0.000, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 3, label: "F2", defaultCode: 0x3b, x: 2.222, y: 0.000, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 4, label: "F3", defaultCode: 0x3c, x: 3.228, y: 0.000, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 5, label: "F4", defaultCode: 0x3d, x: 4.233, y: 0.000, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 6, label: "F5", defaultCode: 0x3e, x: 5.476, y: 0.000, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 7, label: "F6", defaultCode: 0x3f, x: 6.455, y: 0.000, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 8, label: "F7", defaultCode: 0x40, x: 7.460, y: 0.000, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 9, label: "F8", defaultCode: 0x41, x: 8.466, y: 0.000, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 10, label: "F9", defaultCode: 0x42, x: 9.709, y: 0.000, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 11, label: "F10", defaultCode: 0x43, x: 10.714, y: 0.000, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 12, label: "F11", defaultCode: 0x44, x: 11.720, y: 0.000, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 13, label: "F12", defaultCode: 0x45, x: 12.725, y: 0.000, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 119, label: "Del", defaultCode: 0x4c, x: 13.968, y: 0.000, w: 1.005, h: 1.005, fnLocked: true),
        KeySpec(index: 19, label: "`", defaultCode: 0x35, x: 0.000, y: 1.243, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 20, label: "1", defaultCode: 0x1e, x: 0.979, y: 1.243, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 21, label: "2", defaultCode: 0x1f, x: 1.984, y: 1.243, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 22, label: "3", defaultCode: 0x20, x: 2.989, y: 1.243, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 23, label: "4", defaultCode: 0x21, x: 3.995, y: 1.243, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 24, label: "5", defaultCode: 0x22, x: 4.974, y: 1.243, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 25, label: "6", defaultCode: 0x23, x: 5.979, y: 1.243, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 26, label: "7", defaultCode: 0x24, x: 6.984, y: 1.243, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 27, label: "8", defaultCode: 0x25, x: 7.989, y: 1.243, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 28, label: "9", defaultCode: 0x26, x: 8.968, y: 1.243, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 29, label: "0", defaultCode: 0x27, x: 9.974, y: 1.243, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 30, label: "-", defaultCode: 0x2d, x: 10.979, y: 1.243, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 31, label: "=", defaultCode: 0x2e, x: 11.958, y: 1.243, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 103, label: "⌫", defaultCode: 0x2a, x: 12.963, y: 1.243, w: 2.011, h: 1.005, fnLocked: true),
        KeySpec(index: 117, label: "Home", defaultCode: 0x4a, x: 15.397, y: 1.243, w: 1.005, h: 1.005, fnLocked: true),
        KeySpec(index: 37, label: "Tab", defaultCode: 0x2b, x: 0.000, y: 2.275, w: 1.481, h: 1.005, fnLocked: false),
        KeySpec(index: 38, label: "Q", defaultCode: 0x14, x: 1.481, y: 2.275, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 39, label: "W", defaultCode: 0x1a, x: 2.487, y: 2.275, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 40, label: "E", defaultCode: 0x8, x: 3.492, y: 2.275, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 41, label: "R", defaultCode: 0x15, x: 4.497, y: 2.275, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 42, label: "T", defaultCode: 0x17, x: 5.476, y: 2.275, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 43, label: "Y", defaultCode: 0x1c, x: 6.481, y: 2.275, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 44, label: "U", defaultCode: 0x18, x: 7.487, y: 2.275, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 45, label: "I", defaultCode: 0xc, x: 8.492, y: 2.275, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 46, label: "O", defaultCode: 0x12, x: 9.471, y: 2.275, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 47, label: "P", defaultCode: 0x13, x: 10.476, y: 2.275, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 48, label: "[", defaultCode: 0x2f, x: 11.481, y: 2.275, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 49, label: "]", defaultCode: 0x30, x: 12.460, y: 2.275, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 67, label: "\\", defaultCode: 0x31, x: 13.466, y: 2.275, w: 1.508, h: 1.005, fnLocked: true),
        KeySpec(index: 118, label: "PgUp", defaultCode: 0x4b, x: 15.397, y: 2.275, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 55, label: "Caps", defaultCode: 0x39, x: 0.000, y: 3.254, w: 1.720, h: 1.005, fnLocked: false),
        KeySpec(index: 56, label: "A", defaultCode: 0x4, x: 1.720, y: 3.254, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 57, label: "S", defaultCode: 0x16, x: 2.725, y: 3.254, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 58, label: "D", defaultCode: 0x7, x: 3.730, y: 3.254, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 59, label: "F", defaultCode: 0x9, x: 4.735, y: 3.254, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 60, label: "G", defaultCode: 0xa, x: 5.741, y: 3.254, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 61, label: "H", defaultCode: 0xb, x: 6.746, y: 3.254, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 62, label: "J", defaultCode: 0xd, x: 7.725, y: 3.254, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 63, label: "K", defaultCode: 0xe, x: 8.730, y: 3.254, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 64, label: "L", defaultCode: 0xf, x: 9.709, y: 3.254, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 65, label: ";", defaultCode: 0x33, x: 10.714, y: 3.254, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 66, label: "'", defaultCode: 0x34, x: 11.720, y: 3.254, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 85, label: "Enter", defaultCode: 0x28, x: 12.725, y: 3.254, w: 2.249, h: 1.005, fnLocked: false),
        KeySpec(index: 121, label: "PgDn", defaultCode: 0x4e, x: 15.397, y: 3.254, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 73, label: "Shift", defaultCode: 0xe1, x: 0.000, y: 4.259, w: 2.249, h: 1.005, fnLocked: false),
        KeySpec(index: 74, label: "Z", defaultCode: 0x1d, x: 2.222, y: 4.259, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 75, label: "X", defaultCode: 0x1b, x: 3.228, y: 4.259, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 76, label: "C", defaultCode: 0x6, x: 4.233, y: 4.259, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 77, label: "V", defaultCode: 0x19, x: 5.212, y: 4.259, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 78, label: "B", defaultCode: 0x5, x: 6.217, y: 4.259, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 79, label: "N", defaultCode: 0x11, x: 7.222, y: 4.259, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 80, label: "M", defaultCode: 0x10, x: 8.228, y: 4.259, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 81, label: ",", defaultCode: 0x36, x: 9.206, y: 4.259, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 82, label: ".", defaultCode: 0x37, x: 10.212, y: 4.259, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 83, label: "/", defaultCode: 0x38, x: 11.217, y: 4.259, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 84, label: "Shift", defaultCode: 0xe5, x: 12.222, y: 4.259, w: 1.720, h: 1.005, fnLocked: false),
        KeySpec(index: 101, label: "↑", defaultCode: 0x52, x: 14.180, y: 4.497, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 91, label: "Ctrl", defaultCode: 0xe0, x: 0.000, y: 5.265, w: 1.243, h: 1.005, fnLocked: false),
        KeySpec(index: 92, label: "Win", defaultCode: 0xe3, x: 1.243, y: 5.265, w: 1.243, h: 1.005, fnLocked: true),
        KeySpec(index: 93, label: "Alt", defaultCode: 0xe2, x: 2.487, y: 5.265, w: 1.243, h: 1.005, fnLocked: false),
        KeySpec(index: 94, label: "Space", defaultCode: 0x2c, x: 3.730, y: 5.265, w: 6.217, h: 1.005, fnLocked: false),
        KeySpec(index: 95, label: "Alt", defaultCode: 0xe6, x: 9.974, y: 5.265, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 96, label: "Fn", defaultCode: 0xaf, x: 10.979, y: 5.265, w: 1.005, h: 1.005, fnLocked: true),
        KeySpec(index: 98, label: "Ctrl", defaultCode: 0xe4, x: 11.984, y: 5.265, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 99, label: "←", defaultCode: 0x50, x: 13.201, y: 5.503, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 100, label: "↓", defaultCode: 0x51, x: 14.180, y: 5.503, w: 1.005, h: 1.005, fnLocked: false),
        KeySpec(index: 102, label: "→", defaultCode: 0x4f, x: 15.185, y: 5.503, w: 1.005, h: 1.005, fnLocked: false),
    ]

    public static func key(_ index: Int) -> KeySpec? { keys.first { $0.index == index } }
}
