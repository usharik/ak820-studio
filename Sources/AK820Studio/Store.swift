import AK820Kit
import AppKit
import SwiftUI

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
}

@MainActor
final class Store: ObservableObject {
    @Published var config: Config { didSet { save() } }
    @Published var connected = false
    @Published var battery: Int?
    @Published var busy: String?
    @Published var progress: Double?
    @Published var status: (text: String, ok: Bool)?
    @Published var log: [String] = []

    private let queue = DispatchQueue(label: "ak820.hid", qos: .userInitiated)
    /// Lighting changed while another operation was running; applied when it finishes.
    private var lightingPending = false
    private var timer: Timer?

    static let configURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AK820Studio", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("config.json")
    }()

    init() {
        config = (try? JSONDecoder().decode(Config.self, from: Data(contentsOf: Store.configURL))) ?? Config()
        refreshConnection()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshConnection() }
        }
    }

    private func save() {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? enc.encode(config).write(to: Store.configURL, options: .atomic)
    }

    func refreshConnection() {
        guard busy == nil else { return }
        let now = Keyboard.isPresent()
        if now != connected {
            connected = now
            battery = nil
            if now { readBattery() }
        }
    }

    func readBattery() {
        run(nil) { kb in try kb.battery() } done: { [weak self] pct in self?.battery = pct }
    }

    /// Runs a keyboard operation on the HID queue; `title` shows a spinner and a result message.
    func run<T>(_ title: String?, _ op: @escaping (Keyboard) throws -> T, done: ((T) -> Void)? = nil) {
        if title != nil {
            guard busy == nil else { return }
            busy = title
            status = nil
            progress = nil
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
                defer {
                    if self.lightingPending, self.busy == nil {
                        self.lightingPending = false
                        self.applyLighting()
                    }
                }
                switch result {
                case let .success(v):
                    self.connected = true
                    if let title { self.status = (String(localized: "\(title): done"), true) }
                    done?(v)
                case let .failure(e):
                    if title != nil { self.status = (e.localizedDescription, false) }
                    self.appendLog("error: \(e.localizedDescription)")
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
        let c = config.lighting
        run(String(localized: "Lighting")) { try $0.setLighting(c) }
    }

    func applyColors() {
        let c = config
        run(String(localized: "Key colors")) { try $0.setCustomColors(c.colors, background: c.colorBackground, brightness: c.colorBrightness) }
    }

    func applyKeymap() {
        let c = config
        run(String(localized: "Keymap and macros")) { try $0.setKeymap(base: c.base, fn: c.fn, macros: c.macros) }
    }

    func applySettings() {
        let s = config.settings
        run(String(localized: "Settings")) { try $0.setSettings(s) }
    }

    func syncClock() {
        run(String(localized: "Clock")) { try $0.syncClock() }
    }

    func uploadScreen(_ image: ScreenImage) {
        let payload = image.payload()
        run(String(localized: "Screen")) { kb in
            try kb.uploadScreen(payload) { p in DispatchQueue.main.async { self.progress = p } }
        }
    }

    // MARK: Import / export

    func exportConfig() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "ak820-config.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            try enc.encode(config).write(to: url)
            status = (String(localized: "Settings saved to \(url.lastPathComponent)"), true)
        } catch { status = (error.localizedDescription, false) }
    }

    func importConfig() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            config = try JSONDecoder().decode(Config.self, from: Data(contentsOf: url))
            status = (String(localized: "Loaded. Press “Write to keyboard” on the relevant tabs to send it to the keyboard."), true)
        } catch { status = (String(localized: "Couldn't read the file: \(error.localizedDescription)"), false) }
    }
}

extension RGB {
    var color: Color { Color(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255) }

    init(_ color: Color) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .white
        self.init(r: UInt8(clamping: Int((ns.redComponent * 255).rounded())),
                  g: UInt8(clamping: Int((ns.greenComponent * 255).rounded())),
                  b: UInt8(clamping: Int((ns.blueComponent * 255).rounded())))
    }

    var hex: String { String(format: "%02X%02X%02X", r, g, b) }
}
