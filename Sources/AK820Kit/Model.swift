import Foundation

// MARK: - Lighting

public enum LightingMode: UInt8, CaseIterable, Codable, Identifiable {
    case off = 0x00, statik = 0x01, singleOn = 0x02, singleOff = 0x03, glittering = 0x04, falling = 0x05
    case colourful = 0x06, breath = 0x07, spectrum = 0x08, outward = 0x09, scrolling = 0x0A, rolling = 0x0B
    case rotating = 0x0C, explode = 0x0D, launch = 0x0E, ripples = 0x0F, flowing = 0x10, pulsating = 0x11
    case tilt = 0x12, shuttle = 0x13
    case custom = 0x80

    public var id: UInt8 { rawValue }

    public var title: String {
        switch self {
        case .off: return String(localized: "Lights off")
        case .statik: return String(localized: "Static color")
        case .singleOn: return String(localized: "Pressed key lights up")
        case .singleOff: return String(localized: "Pressed key goes dark")
        case .glittering: return String(localized: "Glittering (stars)")
        case .falling: return String(localized: "Rain")
        case .colourful: return String(localized: "Colorful")
        case .breath: return String(localized: "Breathing")
        case .spectrum: return String(localized: "Spectrum")
        case .outward: return String(localized: "Fountain")
        case .scrolling: return String(localized: "Scrolling")
        case .rolling: return String(localized: "Rainbow wave")
        case .rotating: return String(localized: "Rotating")
        case .explode: return String(localized: "Explode")
        case .launch: return String(localized: "Launch")
        case .ripples: return String(localized: "Ripples")
        case .flowing: return String(localized: "Flowing")
        case .pulsating: return String(localized: "Pulsating")
        case .tilt: return String(localized: "Tilt")
        case .shuttle: return String(localized: "Shuttle")
        case .custom: return String(localized: "Custom key colors")
        }
    }

    /// Modes shown in the effect picker (custom is configured on its own page).
    public static var effects: [LightingMode] { allCases.filter { $0 != .custom } }
}

public struct LightingConfig: Codable, Equatable {
    public var mode: LightingMode = .rolling
    public var color: RGB = RGB(r: 255, g: 255, b: 255)
    public var rainbow = true
    public var brightness = 5   // 0…5
    public var speed = 3        // 0…5
    public var direction = 0    // 0 ←, 1 ↓, 2 ↑, 3 →
    public init() {}
}

public struct RGB: Codable, Hashable {
    public var r: UInt8, g: UInt8, b: UInt8
    public init(r: UInt8, g: UInt8, b: UInt8) { self.r = r; self.g = g; self.b = b }
    public static let black = RGB(r: 0, g: 0, b: 0)
}

// MARK: - Settings

public struct KeyboardSettings: Codable, Equatable {
    public var sleep = 2            // 0 never, 1 = 1 min, 2 = 5 min, 3 = 30 min
    public var fnToggle = false     // false: Fn layer while held, true: Fn toggles
    public var responseLevel = 2    // debounce level 1…5
    public var lockWin = false
    public var lockAltF4 = false
    public var lockAltTab = false
    public init() {}
}

// MARK: - Key actions

public enum MouseAction: String, Codable, CaseIterable {
    case left, right, middle, wheelUp, wheelDown

    public var title: String {
        switch self {
        case .left: return String(localized: "Left click")
        case .right: return String(localized: "Right click")
        case .middle: return String(localized: "Middle click")
        case .wheelUp: return String(localized: "Wheel up")
        case .wheelDown: return String(localized: "Wheel down")
        }
    }

    var bytes: (UInt8, UInt8) {
        switch self {
        case .left: return (0x01, 0x01)
        case .right: return (0x01, 0x02)
        case .middle: return (0x01, 0x04)
        case .wheelUp: return (0x03, 0x01)
        case .wheelDown: return (0x03, 0xFF)
        }
    }
}

public enum MacroPlayMode: Int, Codable, CaseIterable {
    case once = 0, times = 1, toggle = 2, whileHeld = 3, step = 4

    public var title: String {
        switch self {
        case .once: return String(localized: "Once")
        case .times: return String(localized: "N times")
        case .toggle: return String(localized: "Until pressed again")
        case .whileHeld: return String(localized: "While held")
        case .step: return String(localized: "One step per press")
        }
    }
}

public enum KeyAction: Codable, Hashable {
    case key(modifiers: UInt8, code: UInt8)      // code 0 = modifiers only
    case media(UInt16)
    case mouse(MouseAction)
    case macro(id: UUID, mode: MacroPlayMode, times: Int)
    case disabled

    /// 4-byte entry of the keymap table. `macroIndex` resolves macro ids.
    func entry(macroIndex: (UUID) -> Int?) throws -> [UInt8] {
        switch self {
        case let .key(mods, code):
            return [0x02, mods, code, 0x00]
        case let .media(code):
            return [0x03, UInt8(code & 0xFF), UInt8(code >> 8), 0x00]
        case let .mouse(m):
            return [0x01, m.bytes.0, m.bytes.1, 0x00]
        case let .macro(id, mode, times):
            guard let i = macroIndex(id) else { throw AK820Error.invalid(String(localized: "A deleted macro is assigned to a key")) }
            return [0x06, UInt8(i), UInt8(mode.rawValue), UInt8(clamping: max(1, times))]
        case .disabled:
            return [0x05, 0x03, 0x00, 0x00]
        }
    }

    public func describe(macros: [Macro]) -> String {
        switch self {
        case let .key(mods, code):
            let m = HIDUsage.modifierSymbols(mods)
            return code == 0 ? (m.isEmpty ? "—" : m) : m + HIDUsage.name(code)
        case let .media(code): return HIDUsage.mediaName(code)
        case let .mouse(m): return m.title
        case let .macro(id, _, _): let name = macros.first { $0.id == id }?.name ?? "?"
            return String(localized: "Macro “\(name)”")
        case .disabled: return String(localized: "Disabled")
        }
    }
}

// MARK: - Macros

public enum MacroStep: Codable, Hashable {
    case text(String)
    case combo(modifiers: UInt8, code: UInt8)
    case delay(ms: Int)
    case click(MouseAction)
}

public struct Macro: Codable, Hashable, Identifiable {
    public var id = UUID()
    public var name: String
    public var steps: [MacroStep]
    /// Pause after each key event, ms.
    public var gapMs = 15
    public init(name: String, steps: [MacroStep] = []) { self.name = name; self.steps = steps }
}

// MARK: - Encoders (byte layouts from the reverse-engineered official driver)

public enum Encode {
    public static let packet = 64
    static let tableSize = 576
    static let macroBlockMax = 0xE00
    static let macroBodyStart = 400

    public static func control(_ cmd: UInt8, _ b2: UInt8 = 0, _ b8: UInt8 = 1, _ b9: UInt8 = 0) -> [UInt8] {
        var p = [UInt8](repeating: 0, count: packet)
        p[0] = 0x04; p[1] = cmd; p[2] = b2; p[8] = b8; p[9] = b9
        return p
    }

    public static func lighting(_ c: LightingConfig) -> [UInt8] {
        var c = c
        if c.mode == .custom {   // like the official driver: per-key colors carry no color/rainbow/speed
            c.color = .black; c.rainbow = false; c.speed = 0
        }
        // Effect 01 is untested on this firmware; the hardware-verified "static" is breath at speed 0.
        let isStatic = c.mode == .statik
        var p = [UInt8](repeating: 0, count: packet)
        p[0] = isStatic ? LightingMode.breath.rawValue : c.mode.rawValue
        p[1] = c.color.r; p[2] = c.color.g; p[3] = c.color.b
        p[8] = c.rainbow && !isStatic ? 1 : 0
        p[9] = UInt8(clamping: min(max(c.brightness, 0), 5))
        p[10] = isStatic ? 0 : UInt8(clamping: min(max(c.speed, 0), 5))
        p[11] = UInt8(clamping: c.direction)
        p[14] = 0xAA; p[15] = 0x55
        return p
    }

    public static func clock(_ date: Date, calendar: Calendar = Calendar(identifier: .gregorian)) -> [UInt8] {
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        var p = [UInt8](repeating: 0, count: packet)
        p[1] = 0x01; p[2] = 0x5A
        p[3] = UInt8(c.year! % 100); p[4] = UInt8(c.month!); p[5] = UInt8(c.day!)
        p[6] = UInt8(c.hour!); p[7] = UInt8(c.minute!); p[8] = UInt8(c.second!)
        p[10] = 0x04
        p[62] = 0xAA; p[63] = 0x55
        return p
    }

    public static func settings(_ s: KeyboardSettings) -> [UInt8] {
        var p = [UInt8](repeating: 0, count: packet)
        p[1] = 0x01
        p[2] = s.lockWin ? 1 : 0
        p[3] = s.lockAltF4 ? 1 : 0
        p[4] = s.lockAltTab ? 1 : 0
        p[5] = s.fnToggle ? 1 : 0
        p[6] = UInt8(clamping: s.sleep)
        p[8] = UInt8(clamping: min(max(s.responseLevel, 1), 5))
        p[62] = 0xAA; p[63] = 0x55
        return p
    }

    /// 144 slots × 4 bytes, `AA 55` trailer.
    public static func table(_ entries: [Int: [UInt8]]) -> [UInt8] {
        var t = [UInt8](repeating: 0, count: tableSize)
        for (i, e) in entries where i >= 0 && i < 143 {
            t.replaceSubrange(i * 4..<i * 4 + 4, with: e)
        }
        t[tableSize - 2] = 0xAA; t[tableSize - 1] = 0x55
        return t
    }

    public static func keymap(_ map: [Int: KeyAction], macros: [Macro]) throws -> [UInt8] {
        var entries: [Int: [UInt8]] = [:]
        for (i, a) in map {
            entries[i] = try a.entry { id in macros.firstIndex { $0.id == id } }
        }
        return table(entries)
    }

    /// Per-key colors: `[index, r, g, b]` in each key's slot.
    public static func colors(_ colors: [Int: RGB], background: RGB) -> [UInt8] {
        var entries: [Int: [UInt8]] = [:]
        for k in Layout.keys {
            let c = colors[k.index] ?? background
            entries[k.index] = [UInt8(k.index), c.r, c.g, c.b]
        }
        return table(entries)
    }

    /// Live frame (not stored): 128 slots × `[index, r, g, b]`.
    public static func liveFrame(_ colors: [Int: RGB]) -> [UInt8] {
        var d = [UInt8](repeating: 0, count: 512)
        for (i, c) in colors where i < 128 {
            d.replaceSubrange(i * 4..<i * 4 + 4, with: [UInt8(i), c.r, c.g, c.b])
        }
        return d
    }

    // MARK: Macros

    static func wait(_ ms: Int) -> [UInt8] {
        let v = UInt16(clamping: max(10, ms))
        return [UInt8(v & 0xFF), UInt8(v >> 8), 0x00, 0x50]
    }

    public static func events(_ m: Macro) throws -> [[UInt8]] {
        var ev: [[UInt8]] = []
        let gap = wait(m.gapMs)
        func tap(_ codes: [UInt8]) {
            for c in codes { ev += [[0, 0, c, 0xB0], gap] }
            for c in codes.reversed() { ev += [[0, 0, c, 0x30], gap] }
        }
        func modCodes(_ mask: UInt8) -> [UInt8] {
            (0..<8).compactMap { mask & (1 << $0) != 0 ? UInt8(0xE0 + $0) : nil }
        }
        for step in m.steps {
            switch step {
            case let .text(s):
                for ch in s {
                    guard let (u, shift) = HIDUsage.usage(for: ch) else {
                        throw AK820Error.invalid(String(localized: "Macro “\(m.name)”: the character “\(String(ch))” can't be typed (only Latin letters, digits and ASCII symbols)"))
                    }
                    tap(shift ? [0xE1, u] : [u])
                }
            case let .combo(mods, code):
                tap(modCodes(mods) + (code == 0 ? [] : [code]))
            case let .delay(ms):
                var left = ms
                while left > 0 { ev.append(wait(min(left, 0xFFFF))); left -= 0xFFFF }
            case let .click(btn):
                let b = btn.bytes
                if b.0 == 0x01 { ev += [[0, 0, b.1, 0x90], gap, [0, 0, b.1, 0x10], gap] }
            }
        }
        return ev
    }

    /// The whole macro area (all 100 slots), padded to `packet` bytes and ended by `AA 55`.
    /// `used` is the number of meaningful bytes (index + bodies).
    public static func macroBlock(_ macros: [Macro], packet: Int = Encode.packet) throws -> (data: [UInt8], used: Int) {
        guard macros.count <= 100 else { throw AK820Error.invalid(String(localized: "No more than 100 macros")) }
        var block = [UInt8](repeating: 0, count: macroBlockMax)
        var pos = macroBodyStart
        let tooBig = AK820Error.invalid(String(localized: "The macros don't fit into the keyboard memory (3.5 KB). Make them shorter."))
        for (i, m) in macros.enumerated() {
            let ev = try events(m)
            let body = ev.flatMap { $0 }
            guard pos + 8 + body.count <= macroBlockMax else { throw tooBig }
            block[i * 4] = UInt8(pos & 0xFF); block[i * 4 + 1] = UInt8(pos >> 8)
            block[pos] = UInt8(ev.count & 0xFF); block[pos + 1] = UInt8(ev.count >> 8)
            block.replaceSubrange(pos + 8..<pos + 8 + body.count, with: body)
            pos += 8 + body.count
        }
        // Like the official driver: always at least one spare byte before the AA 55 trailer.
        let packets = pos / packet + (pos % packet == 0 ? 1 : 2)
        let size = packets * packet
        guard size <= macroBlockMax else { throw tooBig }
        block[size - 2] = 0xAA; block[size - 1] = 0x55
        return (Array(block[0..<size]), pos)
    }

    // MARK: 2.4 GHz receiver

    /// Receiver payload for lighting / settings / clock: the first 14 bytes of the wired packet + `AA 55`.
    public static func short(_ packet: [UInt8]) -> [UInt8] {
        Array(packet.prefix(14)) + [0xAA, 0x55]
    }

    /// 32-byte receiver frames: `[order, length, index, ≤28 data bytes, sum]`.
    public static func dongleFrames(_ order: UInt8, _ data: [UInt8], lastLength: Int? = nil) -> [[UInt8]] {
        let chunks = stride(from: 0, to: max(data.count, 1), by: 28).map { Array(data[$0..<min($0 + 28, data.count)]) }
        return chunks.enumerated().map { i, chunk in
            var f = [UInt8](repeating: 0, count: 32)
            f[0] = order
            f[1] = UInt8(i == chunks.count - 1 ? (lastLength ?? chunk.count) : chunk.count)
            f[2] = UInt8(i)
            f.replaceSubrange(3..<3 + chunk.count, with: chunk)
            f[31] = UInt8(truncatingIfNeeded: f[0..<31].reduce(0) { $0 + Int($1) })
            return f
        }
    }

    /// Byte sum the keyboard echoes back on COMMIT (little-endian u16).
    public static func checksum(_ data: [UInt8]) -> UInt16 {
        UInt16(truncatingIfNeeded: data.reduce(0) { $0 + Int($1) })
    }
}
