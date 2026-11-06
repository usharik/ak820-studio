import AK820Kit
import Foundation

let usage = """
ak820ctl — AJAZZ AK820 Pro (USB) from the terminal

  ak820ctl info                         list keyboard interfaces (writes nothing)
  ak820ctl battery                      battery level
  ak820ctl clock                        sync the clock on the screen
  ak820ctl lights <mode> [RRGGBB] [brightness 0-5] [speed 0-5]
  ak820ctl live [seconds]               rainbow sweep via live frames (nothing stored)
  ak820ctl image <file.png|gif>         image/GIF to the screen
  -v                                    show packet exchange
modes: \(LightingMode.effects.map { "\($0.rawValue)" }.joined(separator: ","))  (1 = static, 0 = off)
"""

var args = Array(CommandLine.arguments.dropFirst())
let verbose = args.contains("-v")
args.removeAll { $0 == "-v" }

func withKeyboard(_ body: (Keyboard) throws -> Void) throws {
    let kb = try Keyboard.open()
    defer { kb.close() }
    if verbose { kb.log = { print("  \($0)") } }
    try body(kb)
}

do {
    switch args.first {
    case "info":
        let devs = HIDDevice.enumerate(vendorID: Keyboard.vendorID, productIDs: Keyboard.productIDs + [Keyboard.dongleID])
        if devs.isEmpty { throw AK820Error.notFound }
        for d in devs.sorted(by: { $0.usagePage < $1.usagePage }) {
            print(String(format: "%@  PID 0x%04X  usage page 0x%04X  version %@", d.product, d.productID, d.usagePage, d.versionString))
        }
    case "battery":
        try withKeyboard { kb in
            print(try kb.battery().map { "Battery: \($0)%" } ?? "Battery level unknown")
        }
    case "clock":
        try withKeyboard { try $0.syncClock() }
        print("Clock synced")
    case "lights":
        guard args.count >= 2, let m = UInt8(args[1]), let mode = LightingMode(rawValue: m) else {
            print(usage); exit(2)
        }
        var c = LightingConfig()
        c.mode = mode
        if args.count >= 3, let v = UInt32(args[2], radix: 16) {
            c.color = RGB(r: UInt8(v >> 16 & 0xFF), g: UInt8(v >> 8 & 0xFF), b: UInt8(v & 0xFF))
            c.rainbow = false
        }
        if args.count >= 4, let b = Int(args[3]) { c.brightness = b }
        if args.count >= 5, let s = Int(args[4]) { c.speed = s }
        try withKeyboard { try $0.setLighting(c) }
        print("Lighting: \(mode.title)")
    case "live":
        let seconds = args.count >= 2 ? Double(args[1]) ?? 3 : 3
        try withKeyboard { kb in try PreciseTiming.run {
            let start = Date()
            var frames = 0
            while Date().timeIntervalSince(start) < seconds {
                let t = Date().timeIntervalSince(start)
                var colors: [Int: RGB] = [:]
                for k in Layout.keys {
                    let h = ((k.x / Layout.width) + t * 0.5).truncatingRemainder(dividingBy: 1)
                    let (r, g, b) = hsv(h)
                    colors[k.index] = RGB(r: r, g: g, b: b)
                }
                try kb.showLiveFrame(colors)
                frames += 1
            }
            print(String(format: "%d frames, %.1f fps", frames, Double(frames) / seconds))
        } }
    case "image":
        guard args.count >= 2 else { print(usage); exit(2) }
        let img = try ScreenImage(url: URL(fileURLWithPath: args[1]))
        let payload = img.payload()
        print("Frames: \(img.frames.count), blocks: \(payload.count / ScreenImage.blockSize)")
        try withKeyboard { kb in
            try kb.uploadScreen(payload) { p in print(String(format: "\r  %3.0f %%", p * 100), terminator: "") ; fflush(stdout) }
        }
        print("\nDone")
    default:
        print(usage)
    }
} catch {
    FileHandle.standardError.write("Error: \(error.localizedDescription)\n".data(using: .utf8)!)
    exit(1)
}

func hsv(_ h: Double) -> (UInt8, UInt8, UInt8) {
    let i = Int(h * 6) % 6, f = h * 6 - Double(Int(h * 6))
    let q = UInt8((1 - f) * 255), t = UInt8(f * 255)
    switch i {
    case 0: return (255, t, 0)
    case 1: return (q, 255, 0)
    case 2: return (0, 255, t)
    case 3: return (0, q, 255)
    case 4: return (t, 0, 255)
    default: return (255, 0, q)
    }
}
