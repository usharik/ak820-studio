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
        case .off: return "Выключено"
        case .statik: return "Статичный цвет"
        case .singleOn: return "Нажатая клавиша"
        case .singleOff: return "Гаснет нажатая"
        case .glittering: return "Мерцание (звёзды)"
        case .falling: return "Дождь"
        case .colourful: return "Разноцветный"
        case .breath: return "Дыхание"
        case .spectrum: return "Спектр"
        case .outward: return "Фонтан"
        case .scrolling: return "Прокрутка"
        case .rolling: return "Радужная волна"
        case .rotating: return "Вращение"
        case .explode: return "Взрыв"
        case .launch: return "Запуск"
        case .ripples: return "Круги на воде"
        case .flowing: return "Течение"
        case .pulsating: return "Пульсация"
        case .tilt: return "Наклон"
        case .shuttle: return "Челнок"
        case .custom: return "Свои цвета клавиш"
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
        case .left: return "Левый клик"
        case .right: return "Правый клик"
        case .middle: return "Средний клик"
        case .wheelUp: return "Колесо вверх"
        case .wheelDown: return "Колесо вниз"
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
        case .once: return "Один раз"
        case .times: return "N раз"
        case .toggle: return "До повторного нажатия"
        case .whileHeld: return "Пока клавиша зажата"
        case .step: return "По шагу на нажатие"
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
            guard let i = macroIndex(id) else { throw AK820Error.invalid("Назначен удалённый макрос") }
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
        case let .macro(id, _, _): return "Макрос «\(macros.first { $0.id == id }?.name ?? "?")»"
        case .disabled: return "Отключена"
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

    public static func clock(_ date: Date, calendar: Calendar = .current) -> [UInt8] {
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
                        throw AK820Error.invalid("Макрос «\(m.name)»: символ «\(ch)» нельзя набрать (только латиница, цифры и ASCII-символы)")
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

    /// The whole macro area (all 100 slots), padded to 64 and ended by `AA 55`.
    public static func macroBlock(_ macros: [Macro]) throws -> [UInt8] {
        guard macros.count <= 100 else { throw AK820Error.invalid("Не больше 100 макросов") }
        var block = [UInt8](repeating: 0, count: macroBlockMax)
        var pos = macroBodyStart
        for (i, m) in macros.enumerated() {
            let ev = try events(m)
            let body = ev.flatMap { $0 }
            guard pos + 8 + body.count + 2 <= macroBlockMax else {
                throw AK820Error.invalid("Макросы не помещаются в память клавиатуры (3,5 КБ). Сократите их.")
            }
            block[i * 4] = UInt8(pos & 0xFF); block[i * 4 + 1] = UInt8(pos >> 8)
            block[pos] = UInt8(ev.count & 0xFF); block[pos + 1] = UInt8(ev.count >> 8)
            block.replaceSubrange(pos + 8..<pos + 8 + body.count, with: body)
            pos += 8 + body.count
        }
        let packets = pos / packet + (pos % packet == 0 ? 1 : 2)
        let size = min(packets * packet, macroBlockMax)
        block[size - 2] = 0xAA; block[size - 1] = 0x55
        return Array(block[0..<size])
    }

    /// Byte sum the keyboard echoes back on COMMIT (little-endian u16).
    public static func checksum(_ data: [UInt8]) -> UInt16 {
        UInt16(truncatingIfNeeded: data.reduce(0) { $0 + Int($1) })
    }
}
