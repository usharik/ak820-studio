import Foundation

/// AK820 Pro over wired USB ("family B" firmware: control on 0xFF13, screen data on 0xFF68).
///
/// All calls are blocking and must come from one background thread at a time.
public final class Keyboard {
    public static let vendorID = 0x0C45
    public static let productIDs = [0x8009, 0x800A]
    static let controlPage = 0xFF13
    static let dataPage = 0xFF68

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

    /// The official driver waits 35 ms around every command; without it the keyboard drops data.
    static let pause: TimeInterval = 0.035

    public let control: HIDDevice
    public var productID: Int { control.productID }
    public var log: ((String) -> Void)?

    private init(control: HIDDevice) { self.control = control }

    public static func isPresent() -> Bool {
        HIDDevice.enumerate(vendorID: vendorID, productIDs: productIDs).contains { $0.usagePage == controlPage }
    }

    public static func open() throws -> Keyboard {
        guard let c = HIDDevice.enumerate(vendorID: vendorID, productIDs: productIDs)
            .first(where: { $0.usagePage == controlPage }) else { throw AK820Error.notFound }
        try c.open()
        return Keyboard(control: c)
    }

    public func close() { control.close() }

    // MARK: Transport

    @discardableResult
    func send(_ p: [UInt8]) throws -> [UInt8]? {
        Thread.sleep(forTimeInterval: Keyboard.pause)
        try control.setFeature(p)
        Thread.sleep(forTimeInterval: Keyboard.pause)
        let r = try? control.getFeature()
        log?("→ \(hexdump(p.prefix(12)))  ← \(r.map { hexdump($0.prefix(12)) } ?? "—")")
        return r
    }

    /// Bulk data packets go back-to-back without reading a reply (like the official driver).
    func stream(_ data: [UInt8]) throws {
        for i in stride(from: 0, to: data.count, by: Encode.packet) {
            try control.setFeature(Array(data[i..<min(i + Encode.packet, data.count)]))
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

    // MARK: Operations

    public func setLighting(_ c: LightingConfig) throws {
        try send(Encode.control(Cmd.start))
        try send(Encode.control(Cmd.lighting))
        try send(Encode.lighting(c))
        try send(Encode.control(Cmd.save))
    }

    public func syncClock(_ date: Date = Date()) throws {
        try send(Encode.control(Cmd.start))
        try send(Encode.control(Cmd.clock))
        try send(Encode.clock(date))
        try send(Encode.control(Cmd.commit, 0, 0))
    }

    public func setSettings(_ s: KeyboardSettings) throws {
        let data = Encode.settings(s)
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

    /// Writes macros (if any) and both layers. Macros are one block shared by both layers.
    public func setKeymap(base: [Int: KeyAction], fn: [Int: KeyAction], macros: [Macro]) throws {
        let baseTable = try Encode.keymap(base, macros: macros)
        let fnTable = try Encode.keymap(fn, macros: macros)
        if !macros.isEmpty {
            let block = try Encode.macroBlock(macros)
            try retrying(String(localized: "macros")) {
                try send(Encode.control(Cmd.macroOpen, 0, 0))
                try send(Encode.control(Cmd.macroData, 0, UInt8(block.count / Encode.packet)))
                Thread.sleep(forTimeInterval: 0.03)
                try stream(block)
                Thread.sleep(forTimeInterval: 0.03)
                return try commit(expecting: block)
            }
        }
        try uploadTable(Cmd.keymapBase, baseTable, what: String(localized: "base layer"))
        try uploadTable(Cmd.keymapFn, fnTable, what: String(localized: "Fn layer"))
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

    /// Shows a frame of per-key colors without storing it (until the next frame or effect).
    public func showLiveFrame(_ colors: [Int: RGB]) throws {
        try control.setFeature(Encode.control(Cmd.live, 0, 8))
        Thread.sleep(forTimeInterval: 0.005)
        let data = Encode.liveFrame(colors)
        for i in stride(from: 0, to: data.count, by: Encode.packet) {
            try control.setFeature(Array(data[i..<i + Encode.packet]))
            Thread.sleep(forTimeInterval: 0.002)
        }
        try control.setFeature(Encode.control(Cmd.commit, 0, 0))
        Thread.sleep(forTimeInterval: 0.005)
        _ = try? control.getFeature()
    }

    /// Battery percentage, or nil if unknown. 100 when charging over the cable may read as full.
    public func battery() throws -> Int? {
        var p = [UInt8](repeating: 0, count: Encode.packet)
        p[0] = 0x20; p[1] = 0x01
        Thread.sleep(forTimeInterval: Keyboard.pause)
        try control.setFeature(p)
        Thread.sleep(forTimeInterval: 0.05)
        let r = try control.getFeature()
        log?("battery ← \(hexdump(r.prefix(8)))")
        guard r.count >= 4, r[0] == 0x20, r[1] == 0x01 else { return nil }
        return r[3] == 0xFF ? 100 : (r[3] <= 100 ? Int(r[3]) : nil)
    }

    /// Uploads an encoded animation (see `ScreenImage`) to the 128×128 screen.
    public func uploadScreen(_ payload: [UInt8], slot: UInt8 = 1, progress: ((Double) -> Void)? = nil) throws {
        guard let data = HIDDevice.enumerate(vendorID: Keyboard.vendorID, productIDs: [productID])
            .first(where: { $0.usagePage == Keyboard.dataPage }) else {
            throw AK820Error.rejected(String(localized: "Screen interface (0xFF68) not found"))
        }
        try data.open()
        data.beginInput()
        defer { data.endInput(); data.close() }

        let blocks = payload.count / ScreenImage.blockSize
        try send(Encode.control(Cmd.start, 0, 0))
        try send(Encode.control(Cmd.screen, slot, UInt8(blocks & 0xFF), UInt8(blocks >> 8)))
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
