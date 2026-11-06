import Foundation

public enum Connection: String {
    case wired, dongle

    public var title: String {
        switch self {
        case .wired: return String(localized: "USB cable")
        case .dongle: return String(localized: "2.4 GHz receiver")
        }
    }

    public var shortTitle: String {
        switch self {
        case .wired: return "USB"
        case .dongle: return String(localized: "2.4 GHz")
        }
    }
}

/// What can be seen without opening the device.
public struct DeviceInfo: Equatable {
    public let connection: Connection
    public let productID: Int
    /// Firmware (bcdDevice) of the keyboard over the cable, or of the receiver over 2.4 GHz.
    public let firmware: String
}

/// AK820 Pro with the "family B" firmware.
///
/// Over the cable: control on 0xFF13 (64-byte feature reports), screen data on 0xFF68.
/// Over the 2.4 GHz receiver (0C45:FDFD): 32-byte output reports on 0xFF60, echoed back.
/// All calls are blocking and must come from one background thread at a time.
public final class Keyboard {
    public static let vendorID = 0x0C45
    public static let productIDs = [0x8009, 0x800A]
    public static let dongleID = 0xFDFD
    static let controlPage = 0xFF13
    static let dataPage = 0xFF68
    static let donglePage = 0xFF60

    enum Cmd {
        static let commit: UInt8 = 0x02
        static let keymapBase: UInt8 = 0x11
        static let lighting: UInt8 = 0x13
        static let macroData: UInt8 = 0x15
        static let settings: UInt8 = 0x17
        static let start: UInt8 = 0x18
        static let macroOpen: UInt8 = 0x19
        static let live: UInt8 = 0x20
        static let colors: UInt8 = 0x23
        static let keymapFn: UInt8 = 0x27
        static let clock: UInt8 = 0x28
        static let screen: UInt8 = 0x72
        static let save: UInt8 = 0xF0
    }

    /// Receiver order codes (from the official driver).
    enum Order {
        static let lighting: UInt8 = 0x05
        static let settings: UInt8 = 0x07
        static let macros: UInt8 = 0x09
        static let music: UInt8 = 0x0B
        static let clock: UInt8 = 0x0C
        static let keymapBase: UInt8 = 0x10
        static let keymapFn: UInt8 = 0x12
        static let battery: UInt8 = 0x20
    }

    /// The official driver waits 35 ms around every command; without it the keyboard drops data.
    static let pause: TimeInterval = 0.035

    public let device: HIDDevice
    public let connection: Connection
    public var info: DeviceInfo { DeviceInfo(connection: connection, productID: device.productID, firmware: device.versionString) }
    public var log: ((String) -> Void)?

    private init(device: HIDDevice, connection: Connection) {
        self.device = device
        self.connection = connection
    }

    private static func candidates() -> (wired: HIDDevice?, dongle: HIDDevice?) {
        let all = HIDDevice.enumerate(vendorID: vendorID, productIDs: productIDs + [dongleID])
        return (all.first { $0.productID != dongleID && $0.usagePage == controlPage },
                all.first { $0.productID == dongleID && $0.usagePage == donglePage })
    }

    /// The cable wins over the receiver when both are present.
    public static func detect() -> DeviceInfo? {
        let c = candidates()
        if let w = c.wired { return DeviceInfo(connection: .wired, productID: w.productID, firmware: w.versionString) }
        if let d = c.dongle { return DeviceInfo(connection: .dongle, productID: d.productID, firmware: d.versionString) }
        return nil
    }

    public static func open() throws -> Keyboard {
        let c = candidates()
        if let w = c.wired {
            try w.open()
            return Keyboard(device: w, connection: .wired)
        }
        if let d = c.dongle {
            try d.open()
            d.beginInput()
            return Keyboard(device: d, connection: .dongle)
        }
        throw AK820Error.notFound
    }

    public func close() {
        if connection == .dongle { device.endInput() }
        device.close()
    }

    private func requireWired(_ what: String) throws {
        guard connection == .wired else {
            throw AK820Error.unsupported(String(localized: "\(what): available over the USB cable only."))
        }
    }

    // MARK: Wired transport

    @discardableResult
    func send(_ p: [UInt8]) throws -> [UInt8]? {
        Thread.sleep(forTimeInterval: Keyboard.pause)
        try device.setFeature(p)
        Thread.sleep(forTimeInterval: Keyboard.pause)
        let r = try? device.getFeature()
        log?("→ \(hexdump(p.prefix(12)))  ← \(r.map { hexdump($0.prefix(12)) } ?? "—")")
        return r
    }

    /// Bulk data packets go back-to-back without reading a reply (like the official driver).
    func stream(_ data: [UInt8]) throws {
        for i in stride(from: 0, to: data.count, by: Encode.packet) {
            try device.setFeature(Array(data[i..<min(i + Encode.packet, data.count)]))
            Thread.sleep(forTimeInterval: Keyboard.pause)
        }
    }

    /// COMMIT; the reply carries the byte sum of the received data in bytes 4–5.
    func commit(expecting data: [UInt8]?) throws -> Bool {
        let r = try send(Encode.control(Cmd.commit, 0, 0))
        guard let data, let r, r.count >= 6 else { return true }
        let got = UInt16(r[4]) | UInt16(r[5]) << 8
        let want = Encode.checksum(data)
        if got != want { log?("checksum mismatch: got \(got), want \(want)") }
        return got == want
    }

    private func retrying(_ what: String, _ body: () throws -> Bool) throws {
        for attempt in 1...3 {
            if try body() { return }
            log?("\(what): attempt \(attempt) failed, retrying…")
            Thread.sleep(forTimeInterval: 0.2)
        }
        throw AK820Error.rejected(String(localized: "The keyboard did not confirm: \(what). Please try again."))
    }

    func uploadTable(_ cmd: UInt8, _ table: [UInt8], what: String) throws {
        try retrying(what) {
            try send(Encode.control(Cmd.start, 0, 0))
            try send(Encode.control(cmd, 0, UInt8(table.count / Encode.packet)))
            try stream(table)
            guard try commit(expecting: table) else { return false }
            try send(Encode.control(Cmd.save, 0, 0))
            return true
        }
    }

    // MARK: Receiver transport

    /// Sends frames; each one must be echoed (first three bytes) by the receiver.
    func sendDongle(_ frames: [[UInt8]], what: String) throws {
        for f in frames {
            var echoed = false
            for _ in 0..<3 where !echoed {
                try device.setOutput(f)
                echoed = device.waitInput(timeout: 0.2) { Array($0.prefix(3)) == Array(f.prefix(3)) } != nil
            }
            log?("⇢ \(hexdump(f.prefix(8))) \(echoed ? "✓" : "✗")")
            guard echoed else {
                throw AK820Error.rejected(String(localized: "The receiver did not confirm: \(what). Is the keyboard switched on and in 2.4 GHz mode? If it has been idle, press a key to wake it up."))
            }
            Thread.sleep(forTimeInterval: 0.002)
        }
    }

    // MARK: Operations

    public func setLighting(_ c: LightingConfig) throws {
        if connection == .dongle {
            return try sendDongle(Encode.dongleFrames(Order.lighting, Encode.short(Encode.lighting(c))), what: String(localized: "lighting"))
        }
        try send(Encode.control(Cmd.start))
        try send(Encode.control(Cmd.lighting))
        try send(Encode.lighting(c))
        try send(Encode.control(Cmd.save))
    }

    public func syncClock(_ date: Date = Date()) throws {
        if connection == .dongle {
            var d = Encode.short(Encode.clock(date))
            d[10] = UInt8(Calendar(identifier: .gregorian).component(.weekday, from: date) - 1)   // Sunday = 0
            return try sendDongle(Encode.dongleFrames(Order.clock, d), what: String(localized: "clock"))
        }
        try send(Encode.control(Cmd.start))
        try send(Encode.control(Cmd.clock))
        try send(Encode.clock(date))
        try send(Encode.control(Cmd.commit, 0, 0))
    }

    public func setSettings(_ s: KeyboardSettings) throws {
        let data = Encode.settings(s)
        if connection == .dongle {
            return try sendDongle(Encode.dongleFrames(Order.settings, Encode.short(data)), what: String(localized: "settings"))
        }
        try retrying(String(localized: "settings")) {
            try send(Encode.control(Cmd.start, 0, 0))
            try send(Encode.control(Cmd.settings, 1, 1))
            Thread.sleep(forTimeInterval: Keyboard.pause)
            try stream(data)
            return try commit(expecting: data)
        }
    }

    /// Switches to the custom effect and stores the per-key colors.
    public func setCustomColors(_ colors: [Int: RGB], background: RGB, brightness: Int) throws {
        try requireWired(String(localized: "Per-key colors"))
        var light = LightingConfig()
        light.mode = .custom
        light.rainbow = false
        light.brightness = brightness
        light.speed = 0
        light.color = .black
        try send(Encode.control(Cmd.start, 0, 0))
        try send(Encode.control(Cmd.lighting))
        try send(Encode.lighting(light))
        try send(Encode.control(Cmd.commit, 0, 0))
        try send(Encode.control(Cmd.save, 0, 0))
        try uploadTable(Cmd.colors, Encode.colors(colors, background: background), what: String(localized: "key colors"))
    }

    /// Writes all macros and both layers. Macros are one block shared by both layers, so it is
    /// always sent (an empty block clears old macros).
    public func setKeymap(base: [Int: KeyAction], fn: [Int: KeyAction], macros: [Macro]) throws {
        let baseTable = try Encode.keymap(base, macros: macros)
        let fnTable = try Encode.keymap(fn, macros: macros)
        if connection == .dongle {
            let block = try Encode.macroBlock(macros, packet: 28)
            try sendDongle(Encode.dongleFrames(Order.macros, block.data, lastLength: block.used % 28), what: String(localized: "macros"))
            try sendDongle(Encode.dongleFrames(Order.keymapBase, baseTable), what: String(localized: "base layer"))
            try sendDongle(Encode.dongleFrames(Order.keymapFn, fnTable), what: String(localized: "Fn layer"))
            return
        }
        let block = try Encode.macroBlock(macros).data
        try retrying(String(localized: "macros")) {
            try send(Encode.control(Cmd.macroOpen, 0, 0))
            try send(Encode.control(Cmd.macroData, 0, UInt8(block.count / Encode.packet)))
            Thread.sleep(forTimeInterval: 0.03)
            try stream(block)
            Thread.sleep(forTimeInterval: 0.03)
            return try commit(expecting: block)
        }
        try uploadTable(Cmd.keymapBase, baseTable, what: String(localized: "base layer"))
        try uploadTable(Cmd.keymapFn, fnTable, what: String(localized: "Fn layer"))
    }

    /// Shows a frame of per-key colors without storing it. When frames stop, the stored effect returns.
    public func showLiveFrame(_ colors: [Int: RGB]) throws {
        try requireWired(String(localized: "Live per-key lighting"))
        try device.setFeature(Encode.control(Cmd.live, 0, 8))
        Thread.sleep(forTimeInterval: 0.005)
        let data = Encode.liveFrame(colors)
        for i in stride(from: 0, to: data.count, by: Encode.packet) {
            try device.setFeature(Array(data[i..<i + Encode.packet]))
            Thread.sleep(forTimeInterval: 0.002)
        }
        try device.setFeature(Encode.control(Cmd.commit, 0, 0))
        Thread.sleep(forTimeInterval: 0.005)
        _ = try? device.getFeature()
    }

    /// Receiver only: the keyboard draws a 21-band spectrum itself. `heights` are rows lit (0…6).
    public func showSpectrum(style: UInt8, heights: [UInt8]) throws -> Bool {
        let f = Encode.dongleFrames(Order.music, [style, 0, 0] + heights.prefix(21))[0]
        try device.setOutput(f)
        return device.waitInput(timeout: 0.05) { Array($0.prefix(3)) == Array(f.prefix(3)) } != nil
    }

    /// Battery percentage, or nil if unknown. Over the cable a full battery reads 100.
    public func battery() throws -> Int? {
        if connection == .dongle {
            let f = Encode.dongleFrames(Order.battery, [0])[0]
            for _ in 0..<2 {
                try device.setOutput(f)
                if let r = device.waitInput(timeout: 0.2, match: { Array($0.prefix(3)) == Array(f.prefix(3)) }), r.count > 3 {
                    return (1...100).contains(r[3]) ? Int(r[3]) : nil
                }
            }
            return nil
        }
        var p = [UInt8](repeating: 0, count: Encode.packet)
        p[0] = 0x20; p[1] = 0x01
        Thread.sleep(forTimeInterval: Keyboard.pause)
        try device.setFeature(p)
        Thread.sleep(forTimeInterval: 0.05)
        let r = try device.getFeature()
        log?("battery ← \(hexdump(r.prefix(8)))")
        guard r.count >= 4, r[0] == 0x20, r[1] == 0x01 else { return nil }
        return r[3] == 0xFF ? 100 : (r[3] <= 100 ? Int(r[3]) : nil)
    }

    /// Uploads an encoded animation (see `ScreenImage`) to one of the three screen slots.
    public func uploadScreen(_ payload: [UInt8], slot: Int = 1, progress: ((Double) -> Void)? = nil) throws {
        try requireWired(String(localized: "The screen"))
        guard let data = HIDDevice.enumerate(vendorID: Keyboard.vendorID, productIDs: [device.productID])
            .first(where: { $0.usagePage == Keyboard.dataPage }) else {
            throw AK820Error.rejected(String(localized: "Screen interface (0xFF68) not found"))
        }
        try data.open()
        data.beginInput()
        defer { data.endInput(); data.close() }

        let blocks = payload.count / ScreenImage.blockSize
        try send(Encode.control(Cmd.start, 0, 0))
        try send(Encode.control(Cmd.screen, UInt8(min(max(slot, 1), 3)), UInt8(blocks & 0xFF), UInt8(blocks >> 8)))
        for b in 0..<blocks {
            try data.setOutput(Array(payload[b * ScreenImage.blockSize..<(b + 1) * ScreenImage.blockSize]))
            guard data.waitInput(timeout: 3) != nil else {
                try? send(Encode.control(Cmd.save, 0, 0))
                throw AK820Error.rejected(String(localized: "The screen did not confirm block \(b + 1) of \(blocks)"))
            }
            progress?(Double(b + 1) / Double(blocks))
        }
        // No SAVE (F0) here: it corrupts the image.
        try send(Encode.control(Cmd.commit, 0, 0))
    }
}

func hexdump<S: Sequence>(_ bytes: S) -> String where S.Element == UInt8 {
    bytes.map { String(format: "%02x", $0) }.joined(separator: " ")
}
