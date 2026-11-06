import AK820Kit
import AppKit
import SwiftUI

/// Parts of the configuration written to the keyboard separately.
enum Part: String, Codable, CaseIterable {
    case lighting, colors, keymap, settings
}

/// Everything the keyboard can't report back, remembered on this Mac.
struct Config: Codable {
    var lighting = LightingConfig()
    var settings = KeyboardSettings()
    var colors: [Int: RGB] = [:]
    var colorBackground = RGB(r: 0, g: 0, b: 0)
    var colorBrightness = 5
    var base: [Int: KeyAction] = [:]
    var fn: [Int: KeyAction] = [:]
    var macros: [Macro] = []
    var applyLightingInstantly = true
    var screenSlot = 1
    var live = LiveSettings()
    /// Wire bytes of each part as last written, to show unsaved changes.
    var written: [Part: Data] = [:]

    init() {}

    // Every field is optional so that configs from older versions keep loading.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Config()
        lighting = (try? c.decodeIfPresent(LightingConfig.self, forKey: .lighting)) ?? d.lighting
        settings = (try? c.decodeIfPresent(KeyboardSettings.self, forKey: .settings)) ?? d.settings
        colors = (try? c.decodeIfPresent([Int: RGB].self, forKey: .colors)) ?? d.colors
        colorBackground = (try? c.decodeIfPresent(RGB.self, forKey: .colorBackground)) ?? d.colorBackground
        colorBrightness = (try? c.decodeIfPresent(Int.self, forKey: .colorBrightness)) ?? d.colorBrightness
        base = (try? c.decodeIfPresent([Int: KeyAction].self, forKey: .base)) ?? d.base
        fn = (try? c.decodeIfPresent([Int: KeyAction].self, forKey: .fn)) ?? d.fn
        macros = (try? c.decodeIfPresent([Macro].self, forKey: .macros)) ?? d.macros
        applyLightingInstantly = (try? c.decodeIfPresent(Bool.self, forKey: .applyLightingInstantly)) ?? d.applyLightingInstantly
        screenSlot = (try? c.decodeIfPresent(Int.self, forKey: .screenSlot)) ?? d.screenSlot
        live = (try? c.decodeIfPresent(LiveSettings.self, forKey: .live)) ?? d.live
        // Configs from before change tracking: assume what is saved was written.
        written = (try? c.decodeIfPresent([Part: Data].self, forKey: .written))
            ?? Dictionary(uniqueKeysWithValues: Part.allCases.map { ($0, fingerprint($0)) })
    }

    /// Deterministic wire bytes of a part (dictionaries can't be compared by their JSON).
    func fingerprint(_ part: Part) -> Data {
        switch part {
        case .lighting: return Data(Encode.lighting(lighting))
        case .colors: return Data(Encode.colors(colors, background: colorBackground) + [UInt8(clamping: colorBrightness)])
        case .settings: return Data(Encode.settings(settings))
        case .keymap:
            let tables = ((try? Encode.keymap(base, macros: macros)) ?? []) + ((try? Encode.keymap(fn, macros: macros)) ?? [])
            return Data(tables + ((try? Encode.macroBlock(macros).data) ?? []))
        }
    }

    static let factory: Config = {
        var c = Config()
        c.lighting = LightingConfig()   // rainbow wave, brightness 5, speed 3 — the factory effect
        return c
    }()
}

struct Toast: Equatable {
    let text: String
    let ok: Bool
    let id = UUID()
}

@MainActor
final class Store: ObservableObject {
    @Published var config: Config { didSet { save(); dirty = Set(Part.allCases.filter { config.written[$0] != config.fingerprint($0) }) } }
    /// Parts changed since they were last written (cached: fingerprints encode whole tables).
    @Published private(set) var dirty: Set<Part> = []
    @Published private(set) var device: DeviceInfo?
    @Published var battery: Int?
    @Published var busy: String?
    @Published var progress: Double?
    @Published var toast: Toast?
    @Published var log: [String] = []
    @Published private(set) var liveMode: LiveMode?
    @Published var liveFrame: [Int: RGB] = [:]

    var connected: Bool { device != nil }
    var wired: Bool { device?.connection == .wired }

    private let queue = DispatchQueue(label: "ak820.hid", qos: .userInitiated)
    /// Lighting changed while another operation was running; applied when it finishes.
    private var lightingPending = false
    private var timer: Timer?
    private var liveToken: CancelToken?
    private var spectrum: AudioSpectrum?

    static let supportDir: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AK820Studio", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
    static let configURL = supportDir.appendingPathComponent("config.json")
    static let backupURL = supportDir.appendingPathComponent("config-before-reset.json")

    init() {
        config = Store.loadConfig()
        dirty = Set(Part.allCases.filter { config.written[$0] != config.fingerprint($0) })
        refreshConnection()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshConnection() }
        }
    }

    /// An unreadable config is moved aside instead of being overwritten by defaults.
    private static func loadConfig() -> Config {
        guard let data = try? Data(contentsOf: configURL) else { return Config() }
        if let c = try? JSONDecoder().decode(Config.self, from: data) { return c }
        let aside = supportDir.appendingPathComponent("config-unreadable-\(Int(Date().timeIntervalSince1970)).json")
        try? FileManager.default.moveItem(at: configURL, to: aside)
        return Config()
    }

    private func save() {
        try? Store.encoder.encode(config).write(to: Store.configURL, options: .atomic)
    }

    static let encoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return enc
    }()

    func isDirty(_ part: Part) -> Bool { dirty.contains(part) }

    private func markWritten(_ parts: [Part], from c: Config) {
        for p in parts { config.written[p] = c.fingerprint(p) }
    }

    func refreshConnection() {
        guard busy == nil, liveMode == nil else { return }
        let now = Keyboard.detect()
        if now != device {
            let wasConnected = device != nil
            device = now
            battery = nil
            if now != nil {
                readBattery()
            } else if wasConnected {
                showToast(String(localized: "Keyboard disconnected"), ok: false)
            }
        }
    }

    func readBattery() {
        guard liveMode == nil else { return }
        run(nil) { kb in try kb.battery() } done: { [weak self] pct in self?.battery = pct }
    }

    func showToast(_ text: String, ok: Bool) {
        let t = Toast(text: text, ok: ok)
        toast = t
        guard ok else { return }   // errors stay until dismissed
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            if self?.toast == t { self?.toast = nil }
        }
    }

    /// Runs a keyboard operation on the HID queue; `title` shows progress and a result toast.
    func run<T>(_ title: String?, _ op: @escaping (Keyboard) throws -> T, done: ((T) -> Void)? = nil,
                failed: (() -> Void)? = nil) {
        if title != nil {
            guard busy == nil else { return }
            busy = title
            progress = nil
            stopLive()
        }
        let logLine: (String) -> Void = { [weak self] line in
            DispatchQueue.main.async { self?.appendLog(line) }
        }
        queue.async {
            let result: Result<T, Error>
            do {
                let kb = try Keyboard.open()
                defer { kb.close() }
                kb.log = logLine
                result = .success(try op(kb))
            } catch {
                result = .failure(error)
            }
            DispatchQueue.main.async {
                if title != nil { self.busy = nil; self.progress = nil }
                switch result {
                case let .success(v):
                    if let title { self.showToast(String(localized: "\(title): done"), ok: true) }
                    done?(v)
                case let .failure(e):
                    if title != nil { self.showToast(e.localizedDescription, ok: false) }
                    self.appendLog("error: \(e.localizedDescription)")
                    failed?()
                }
                if self.lightingPending, self.busy == nil {
                    self.lightingPending = false
                    self.applyLighting()
                }
            }
        }
    }

    private func appendLog(_ s: String) {
        log.append(s)
        if log.count > 400 { log.removeFirst(log.count - 400) }
    }

    // MARK: Operations

    func applyLighting() {
        guard busy == nil else { lightingPending = true; return }
        let c = config
        run(String(localized: "Lighting")) { try $0.setLighting(c.lighting) } done: { [weak self] in
            self?.markWritten([.lighting], from: c)
        }
    }

    func applyColors() {
        let c = config
        run(String(localized: "Key colors")) {
            try $0.setCustomColors(c.colors, background: c.colorBackground, brightness: c.colorBrightness)
        } done: { [weak self] in
            self?.config.lighting.mode = .custom
            self?.config.lighting.brightness = c.colorBrightness
            self?.markWritten([.colors], from: c)
            if let me = self { me.markWritten([.lighting], from: me.config) }
        }
    }

    func applyKeymap() {
        let c = config
        run(String(localized: "Keymap and macros")) {
            try $0.setKeymap(base: c.base, fn: c.fn, macros: c.macros)
        } done: { [weak self] in self?.markWritten([.keymap], from: c) }
    }

    func applySettings() {
        let c = config
        run(String(localized: "Settings")) { try $0.setSettings(c.settings) } done: { [weak self] in
            self?.markWritten([.settings], from: c)
        }
    }

    func syncClock() {
        run(String(localized: "Clock")) { try $0.syncClock() }
    }

    func uploadScreen(_ image: ScreenImage) {
        let payload = image.payload()
        let slot = config.screenSlot
        run(String(localized: "Screen")) { kb in
            try kb.uploadScreen(payload, slot: slot) { p in DispatchQueue.main.async { self.progress = p } }
        }
    }

    /// Sends everything remembered on this Mac (e.g. after a reset on the keyboard itself).
    func writeAll(onSuccess: (() -> Void)? = nil) {
        let c = config
        run(String(localized: "Everything")) { kb -> Connection in
            try kb.setKeymap(base: c.base, fn: c.fn, macros: c.macros)
            try kb.setSettings(c.settings)
            if c.lighting.mode == .custom, kb.connection == .wired {
                try kb.setCustomColors(c.colors, background: c.colorBackground, brightness: c.colorBrightness)
            } else {
                try kb.setLighting(c.lighting)
            }
            try kb.syncClock()
            return kb.connection
        } done: { [weak self] connection in
            // Per-key colors are only sent over the cable, and only when they are the active effect.
            self?.markWritten(Part.allCases.filter { $0 != .colors || (connection == .wired && c.lighting.mode == .custom) }, from: c)
            onSuccess?()
        } failed: { [weak self] in
            self?.config.written = [:]   // unknown what reached the keyboard
        }
    }

    /// Like the official "Factory reset": there is no reset command, the factory configuration is
    /// written instead. The macro library on this Mac is kept; a backup allows undoing.
    func factoryReset() {
        try? Store.encoder.encode(config).write(to: Store.backupURL, options: .atomic)
        var f = Config.factory
        f.macros = config.macros
        f.applyLightingInstantly = config.applyLightingInstantly
        f.live = config.live
        f.screenSlot = config.screenSlot
        let target = f
        run(String(localized: "Factory reset")) { kb -> Connection in
            try kb.setKeymap(base: [:], fn: [:], macros: [])
            if kb.connection == .wired {
                try kb.setCustomColors([:], background: .black, brightness: 5)
            }
            try kb.setLighting(target.lighting)
            try kb.setSettings(target.settings)
            try kb.syncClock()
            return kb.connection
        } done: { [weak self] connection in
            var c = target
            c.written = [:]
            for p in Part.allCases where p != .colors || connection == .wired { c.written[p] = target.fingerprint(p) }
            self?.config = c
        } failed: { [weak self] in
            self?.config.written = [:]   // the keyboard may be half reset
        }
    }

    var hasBackup: Bool { FileManager.default.fileExists(atPath: Store.backupURL.path) }

    /// Restores the configuration from before the reset; the backup is removed only once written.
    func undoFactoryReset() {
        guard var c = try? JSONDecoder().decode(Config.self, from: Data(contentsOf: Store.backupURL)) else { return }
        c.written = [:]
        config = c
        writeAll { try? FileManager.default.removeItem(at: Store.backupURL) }
    }

    // MARK: Live lighting

    func startLive(_ mode: LiveMode) {
        stopLive()
        guard busy == nil else { return }
        let settings = config.live
        if mode == .music {
            guard #available(macOS 14.2, *) else {
                showToast(String(localized: "Music mode needs macOS 14.2 or later."), ok: false)
                return
            }
            do {
                spectrum = try AudioSpectrum()
            } catch {
                showToast(error.localizedDescription, ok: false)
                return
            }
        }
        let token = CancelToken()
        liveToken = token
        liveMode = mode
        let spectrum = spectrum
        let monitor = SystemMonitor()
        let publish: ([Int: RGB]) -> Void = { [weak self] frame in
            DispatchQueue.main.async { if self?.liveToken === token { self?.liveFrame = frame } }
        }
        // Live frames are sent while the app is usually in the background: no App Nap.
        let activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .latencyCritical],
                                                             reason: "Live keyboard lighting")
        queue.async {
            var failure: Error?
            defer { ProcessInfo.processInfo.endActivity(activity) }
            do { try PreciseTiming.run {
                let kb = try Keyboard.open()
                defer { kb.close() }
                if mode == .system, kb.connection != .wired {
                    throw AK820Error.unsupported(String(localized: "System monitor lighting: available over the USB cable only."))
                }
                let start = Date()
                var lastPreview = Date.distantPast
                var missed = 0
                while !token.cancelled {
                    let frameStart = Date()
                    let t = frameStart.timeIntervalSince(start)
                    let colors: [Int: RGB]
                    switch mode {
                    case .music:
                        let bands = spectrum?.bands() ?? []
                        if kb.connection == .dongle {
                            missed = try kb.showSpectrum(style: settings.style.dongleCode, heights: LiveRender.heights(bands)) ? 0 : missed + 1
                            if missed > 50 { throw AK820Error.rejected(String(localized: "The receiver stopped answering. Press a key to wake the keyboard up.")) }
                        }
                        colors = LiveRender.music(bands: bands, settings: settings, time: t)
                    case .system:
                        colors = LiveRender.system(monitor.sample(), settings: settings)
                    }
                    if kb.connection == .wired { try kb.showLiveFrame(colors) }
                    if frameStart.timeIntervalSince(lastPreview) > 0.08 {
                        publish(colors)
                        lastPreview = frameStart
                    }
                    let budget = mode == .music ? 0.035 : 0.25
                    let left = budget - Date().timeIntervalSince(frameStart)
                    if left > 0 { Thread.sleep(forTimeInterval: left) }
                }
            } } catch {
                failure = error
            }
            DispatchQueue.main.async {
                guard self.liveToken === token else { return }
                self.liveToken = nil
                self.liveMode = nil
                self.liveFrame = [:]
                self.spectrum?.stop()
                self.spectrum = nil
                if let failure { self.showToast(failure.localizedDescription, ok: false) }
            }
        }
    }

    /// The keyboard goes back to its stored effect as soon as live frames stop.
    func stopLive() {
        liveToken?.cancel()
        liveToken = nil
        liveMode = nil
        liveFrame = [:]
        spectrum?.stop()
        spectrum = nil
    }

    // MARK: Import / export

    func exportConfig() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "ak820-config.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try Store.encoder.encode(config).write(to: url)
            showToast(String(localized: "Settings saved to \(url.lastPathComponent)"), ok: true)
        } catch { showToast(error.localizedDescription, ok: false) }
    }

    func importConfig() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            var c = try JSONDecoder().decode(Config.self, from: Data(contentsOf: url))
            c.written = config.written
            config = c
            showToast(String(localized: "Loaded. Sections with changes are marked with a dot — write them to the keyboard."), ok: true)
        } catch { showToast(String(localized: "Couldn't read the file: \(error.localizedDescription)"), ok: false) }
    }
}

final class CancelToken {
    private let lock = NSLock()
    private var flag = false
    var cancelled: Bool { lock.lock(); defer { lock.unlock() }; return flag }
    func cancel() { lock.lock(); flag = true; lock.unlock() }
}

extension RGB {
    var color: Color { Color(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255) }

    init(_ color: Color) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .white
        self.init(r: UInt8(clamping: Int((ns.redComponent * 255).rounded())),
                  g: UInt8(clamping: Int((ns.greenComponent * 255).rounded())),
                  b: UInt8(clamping: Int((ns.blueComponent * 255).rounded())))
    }

    init(hue: Double, saturation: Double = 1, brightness: Double = 1) {
        let c = NSColor(hue: hue.truncatingRemainder(dividingBy: 1), saturation: saturation, brightness: brightness, alpha: 1)
        self.init(r: UInt8(clamping: Int(c.redComponent * 255)), g: UInt8(clamping: Int(c.greenComponent * 255)),
                  b: UInt8(clamping: Int(c.blueComponent * 255)))
    }

    func scaled(_ k: Double) -> RGB {
        RGB(r: UInt8(clamping: Int(Double(r) * k)), g: UInt8(clamping: Int(Double(g) * k)), b: UInt8(clamping: Int(Double(b) * k)))
    }
}
