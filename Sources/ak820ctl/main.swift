import AK820Kit
import Foundation

let usage = """
ak820ctl — AJAZZ AK820 Pro (USB) из терминала

  ak820ctl info                         интерфейсы клавиатуры (ничего не записывает)
  ak820ctl battery                      заряд батареи
  ak820ctl clock                        синхронизировать часы на экране
  ak820ctl lights <режим> [RRGGBB] [яркость 0-5] [скорость 0-5]
  ak820ctl image <файл.png|gif>         картинка/GIF на экран
  -v                                    показывать обмен пакетами
режимы: \(LightingMode.effects.map { "\($0.rawValue)" }.joined(separator: ","))  (1 = статичный, 0 = выкл)
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
        let devs = HIDDevice.enumerate(vendorID: Keyboard.vendorID, productIDs: Keyboard.productIDs)
        if devs.isEmpty { throw AK820Error.notFound }
        for d in devs.sorted(by: { $0.usagePage < $1.usagePage }) {
            print(String(format: "%@  PID 0x%04X  usage page 0x%04X", d.product, d.productID, d.usagePage))
        }
    case "battery":
        try withKeyboard { kb in
            print(try kb.battery().map { "Заряд: \($0) %" } ?? "Заряд неизвестен")
        }
    case "clock":
        try withKeyboard { try $0.syncClock() }
        print("Часы синхронизированы")
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
        print("Подсветка: \(mode.title)")
    case "image":
        guard args.count >= 2 else { print(usage); exit(2) }
        let img = try ScreenImage(url: URL(fileURLWithPath: args[1]))
        let payload = img.payload()
        print("Кадров: \(img.frames.count), блоков: \(payload.count / ScreenImage.blockSize)")
        try withKeyboard { kb in
            try kb.uploadScreen(payload) { p in print(String(format: "\r  %3.0f %%", p * 100), terminator: "") ; fflush(stdout) }
        }
        print("\nГотово")
    default:
        print(usage)
    }
} catch {
    FileHandle.standardError.write("Ошибка: \(error.localizedDescription)\n".data(using: .utf8)!)
    exit(1)
}
