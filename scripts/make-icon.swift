// Draws the app icon and builds Resources/AppIcon.icns.
//   swift scripts/make-icon.swift
// A dark macOS squircle with the AK820 Pro: rainbow-wave backlit keys, the 0.85" screen and the knob.
import AppKit

let size: CGFloat = 1024

func rgb(_ h: CGFloat, _ s: CGFloat = 0.85, _ b: CGFloat = 1) -> NSColor {
    NSColor(hue: h.truncatingRemainder(dividingBy: 1), saturation: s, brightness: b, alpha: 1)
}

func roundedRect(_ r: CGRect, _ radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius)
}

func draw(in ctx: CGContext) {
    // Flip to top-left origin, like a design tool.
    ctx.translateBy(x: 0, y: size)
    ctx.scaleBy(x: 1, y: -1)

    // 1. Squircle background (macOS icon grid: 824 pt body, 100 pt margin).
    let plate = CGRect(x: 100, y: 100, width: 824, height: 824)
    let platePath = roundedRect(plate, 186)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: NSColor.black.withAlphaComponent(0.45).cgColor)
    NSColor.black.setFill()
    platePath.fill()
    ctx.restoreGState()
    ctx.saveGState()
    platePath.addClip()
    NSGradient(colors: [NSColor(calibratedRed: 0.17, green: 0.18, blue: 0.29, alpha: 1),
                        NSColor(calibratedRed: 0.05, green: 0.05, blue: 0.10, alpha: 1)])!
        .draw(in: plate, angle: -90)
    // Soft colored light behind the keyboard.
    for (i, h) in [0.0, 0.17, 0.33, 0.55, 0.75].enumerated() {
        let x = 220 + CGFloat(i) * 150
        NSGradient(colors: [rgb(h, 0.9, 1).withAlphaComponent(0.33), rgb(h).withAlphaComponent(0)])!
            .draw(fromCenter: CGPoint(x: x, y: 760), radius: 0, toCenter: CGPoint(x: x, y: 760), radius: 240, options: [])
    }
    ctx.restoreGState()
    NSColor.white.withAlphaComponent(0.12).setStroke()
    let rim = roundedRect(plate.insetBy(dx: 1.5, dy: 1.5), 185)
    rim.lineWidth = 3
    rim.stroke()

    // 2. Keyboard case, slightly tilted for depth.
    ctx.saveGState()
    ctx.translateBy(x: 512, y: 512)
    ctx.rotate(by: -0.07)
    ctx.scaleBy(x: 1.04, y: 1.04)
    ctx.translateBy(x: -512, y: -540)

    let body = CGRect(x: 168, y: 330, width: 688, height: 420)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -24), blur: 40, color: NSColor.black.withAlphaComponent(0.7).cgColor)
    NSColor(calibratedWhite: 0.16, alpha: 1).setFill()
    roundedRect(body, 54).fill()
    ctx.restoreGState()
    NSGradient(colors: [NSColor(calibratedWhite: 0.30, alpha: 1), NSColor(calibratedWhite: 0.13, alpha: 1)])!
        .draw(in: roundedRect(body, 54), angle: -90)
    NSColor.white.withAlphaComponent(0.18).setStroke()
    let edge = roundedRect(body.insetBy(dx: 2, dy: 2), 52)
    edge.lineWidth = 4
    edge.stroke()

    // 3. Screen and knob in the top-right corner (the AK820 Pro's signature).
    let screen = CGRect(x: 640, y: 362, width: 104, height: 92)
    NSColor.black.setFill()
    roundedRect(screen.insetBy(dx: -6, dy: -6), 18).fill()
    NSGradient(colors: [NSColor(calibratedRed: 0.10, green: 0.45, blue: 1, alpha: 1),
                        NSColor(calibratedRed: 0.55, green: 0.15, blue: 0.95, alpha: 1)])!
        .draw(in: roundedRect(screen, 12), angle: -60)
    let para = NSMutableParagraphStyle()
    para.alignment = .center
    let time = NSAttributedString(string: "12:34", attributes: [
        .font: NSFont.monospacedDigitSystemFont(ofSize: 30, weight: .bold),
        .foregroundColor: NSColor.white,
        .paragraphStyle: para,
    ])
    NSGraphicsContext.current?.saveGraphicsState()
    let tctx = NSGraphicsContext.current!.cgContext
    tctx.saveGState()
    // Text must be drawn unflipped.
    tctx.translateBy(x: 0, y: screen.midY * 2)
    tctx.scaleBy(x: 1, y: -1)
    time.draw(in: CGRect(x: screen.minX, y: screen.midY - 20, width: screen.width, height: 40))
    tctx.restoreGState()
    NSGraphicsContext.current?.restoreGraphicsState()

    let knob = CGRect(x: 764, y: 364, width: 76, height: 76)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 10, color: NSColor.black.withAlphaComponent(0.6).cgColor)
    NSColor(calibratedWhite: 0.5, alpha: 1).setFill()
    NSBezierPath(ovalIn: knob).fill()
    ctx.restoreGState()
    NSGradient(colors: [NSColor(calibratedWhite: 0.92, alpha: 1), NSColor(calibratedWhite: 0.45, alpha: 1)])!
        .draw(in: NSBezierPath(ovalIn: knob), angle: -70)
    NSGradient(colors: [NSColor(calibratedWhite: 0.55, alpha: 1), NSColor(calibratedWhite: 0.85, alpha: 1)])!
        .draw(in: NSBezierPath(ovalIn: knob.insetBy(dx: 12, dy: 12)), angle: -70)

    // 4. Backlit keys: four rows plus a space row, colored like the rainbow-wave effect.
    let left: CGFloat = 196, top: CGFloat = 478, pitch: CGFloat = 63, keySize: CGFloat = 52
    var rows: [[(x: CGFloat, w: CGFloat)]] = []
    rows.append((0..<6).map { (CGFloat($0) * pitch, keySize) })                     // F-row beside the screen
    for r in 0..<3 { rows.append((0..<10).map { (CGFloat($0) * pitch + CGFloat(r) * 6, keySize) }) }
    rows.append([(0, keySize), (pitch, keySize), (2 * pitch, 4 * pitch + keySize), (7 * pitch, keySize), (8 * pitch, keySize), (9 * pitch, keySize)])

    for (r, row) in rows.enumerated() {
        let y = r == 0 ? CGFloat(372) : top + CGFloat(r - 1) * pitch
        for k in row {
            let rect = CGRect(x: left + k.x, y: y, width: k.w, height: keySize)
            let hue = 0.95 + (k.x + k.w / 2) / 660 * 0.8 + CGFloat(r) * 0.03
            let c = rgb(hue)
            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: 26, color: c.withAlphaComponent(0.95).cgColor)
            c.setFill()
            roundedRect(rect, 12).fill()
            ctx.restoreGState()
            NSGradient(colors: [rgb(hue, 0.55, 1), rgb(hue, 0.95, 0.85)])!.draw(in: roundedRect(rect, 12), angle: -90)
            // Key top highlight.
            NSColor.white.withAlphaComponent(0.35).setFill()
            roundedRect(CGRect(x: rect.minX + 7, y: rect.minY + 5, width: rect.width - 14, height: 10), 5).fill()
        }
    }
    ctx.restoreGState()
}

func render(_ px: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let g = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = g
    g.cgContext.scaleBy(x: CGFloat(px) / size, y: CGFloat(px) / size)
    g.imageInterpolation = .high
    draw(in: g.cgContext)
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try render(base * scale).representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(name))
    }
}
let resources = root.appendingPathComponent("Resources")
try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
try render(1024).representation(using: .png, properties: [:])!.write(to: resources.appendingPathComponent("AppIcon.png"))
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", resources.appendingPathComponent("AppIcon.icns").path]
try p.run()
p.waitUntilExit()
print(p.terminationStatus == 0 ? "Resources/AppIcon.icns" : "iconutil failed")
