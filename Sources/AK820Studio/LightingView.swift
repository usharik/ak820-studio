import AK820Kit
import SwiftUI

extension LightingMode {
    var icon: String {
        switch self {
        case .off: return "lightbulb.slash"
        case .statik: return "circle.fill"
        case .singleOn: return "hand.tap"
        case .singleOff: return "hand.tap.fill"
        case .glittering: return "sparkles"
        case .falling: return "cloud.rain"
        case .colourful: return "paintpalette"
        case .breath: return "wind"
        case .spectrum: return "rainbow"
        case .outward: return "drop"
        case .scrolling: return "arrow.left.and.right"
        case .rolling: return "water.waves"
        case .rotating: return "arrow.triangle.2.circlepath"
        case .explode: return "burst"
        case .launch: return "paperplane"
        case .ripples: return "dot.radiowaves.left.and.right"
        case .flowing: return "wave.3.right"
        case .pulsating: return "waveform.path.ecg"
        case .tilt: return "arrow.up.right"
        case .shuttle: return "arrow.left.arrow.right"
        case .custom: return "square.grid.3x3.fill"
        }
    }

    var hasSpeed: Bool { ![.off, .statik, .custom].contains(self) }
    var hasDirection: Bool { [.scrolling, .rolling, .flowing, .tilt, .shuttle, .falling].contains(self) }
}

struct LightingView: View {
    @EnvironmentObject var store: Store
    @State private var pending: DispatchWorkItem?

    private var light: Binding<LightingConfig> { $store.config.lighting }
    private var mode: LightingMode { store.config.lighting.mode }

    var body: some View {
        Page(hint: "Built-in lighting effects. They are stored in the keyboard and work on any computer.") {
            LightingPreview(config: store.config.lighting, colors: store.config.colors, background: store.config.colorBackground)
                .frame(maxWidth: 820)

            Card(title: "Effect") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 8)], spacing: 8) {
                    ForEach(LightingMode.effects) { m in
                        EffectTile(mode: m, selected: m == mode) { light.wrappedValue.mode = m; changed() }
                    }
                    if store.config.lighting.mode == .custom {
                        EffectTile(mode: .custom, selected: true) {}
                    }
                }
            }

            if mode != .off {
                Card(title: "Parameters") {
                    if mode != .statik && mode != .custom {
                        Toggle("Rainbow (instead of a single color)", isOn: Binding(
                            get: { store.config.lighting.rainbow }, set: { light.wrappedValue.rainbow = $0; changed() }))
                    }
                    if mode != .custom {
                        HStack {
                            ColorPicker("Color", selection: Binding(
                                get: { store.config.lighting.color.color },
                                set: { light.wrappedValue.color = RGB($0); changed() }), supportsOpacity: false)
                                .fixedSize()
                            SwatchRow { c in light.wrappedValue.color = c; light.wrappedValue.rainbow = false; changed() }
                        }
                        .disabled(store.config.lighting.rainbow && mode != .statik)
                    }
                    LevelSlider(title: "Brightness", value: light.brightness, onChange: changed)
                    if mode.hasSpeed {
                        LevelSlider(title: "Speed", value: light.speed, onChange: changed)
                    }
                    if mode.hasDirection {
                        Picker("Direction", selection: Binding(
                            get: { store.config.lighting.direction }, set: { light.wrappedValue.direction = $0; changed() })) {
                            Text("← Left").tag(0); Text("↓ Down").tag(1); Text("↑ Up").tag(2); Text("→ Right").tag(3)
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .frame(maxWidth: 820)
            }

            Toggle("Apply changes immediately", isOn: $store.config.applyLightingInstantly)
            Text("Tip: Fn + keys on the keyboard itself switch effects too.").font(.caption).foregroundStyle(.secondary)
        }
    }

    /// Debounced auto-apply.
    private func changed() {
        guard store.config.applyLightingInstantly, store.connected else { return }
        pending?.cancel()
        let item = DispatchWorkItem { [store] in store.applyLighting() }
        pending = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: item)
    }
}

private struct EffectTile: View {
    let mode: LightingMode
    let selected: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: mode.icon).font(.system(size: 18)).frame(height: 22)
                Text(verbatim: mode.title).font(.caption).lineLimit(2).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .padding(.horizontal, 4)
            .background(RoundedRectangle(cornerRadius: 10).fill(selected ? Color.accentColor.opacity(0.18) : hover ? Color.primary.opacity(0.06) : Color.primary.opacity(0.03)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Color.accentColor : .clear, lineWidth: 2))
            .foregroundStyle(selected ? Color.accentColor : Color.primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

/// Quick colors.
struct SwatchRow: View {
    static let colors: [RGB] = [
        RGB(r: 255, g: 255, b: 255), RGB(r: 255, g: 0, b: 0), RGB(r: 255, g: 96, b: 0), RGB(r: 255, g: 208, b: 0),
        RGB(r: 0, g: 255, b: 0), RGB(r: 0, g: 255, b: 200), RGB(r: 0, g: 64, b: 255), RGB(r: 160, g: 0, b: 255),
        RGB(r: 255, g: 0, b: 160),
    ]
    var selected: RGB?
    let pick: (RGB) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Self.colors, id: \.self) { c in
                Button { pick(c) } label: {
                    Circle().fill(c.color).frame(width: 20, height: 20)
                        .overlay(Circle().stroke(Color.primary.opacity(selected == c ? 0.9 : 0.2), lineWidth: selected == c ? 2 : 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// An approximate animated preview of the effect on the keyboard drawing.
struct LightingPreview: View {
    let config: LightingConfig
    var colors: [Int: RGB] = [:]
    var background: RGB = .black

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            TimelineView(.animation(minimumInterval: 1 / 20, paused: !animated)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                KeyboardView(fill: { color(for: $0, time: t) }, glow: config.mode != .off)
            }
            Text("Approximate preview").font(.caption2).foregroundStyle(.tertiary)
        }
    }

    private var animated: Bool { config.mode.hasSpeed && config.speed > 0 }

    private func color(for k: KeySpec, time t: Double) -> Color {
        let level = Double(config.brightness) / 5
        guard config.mode != .off, level > 0 else { return .keyCap }
        if config.mode == .custom { return mix((colors[k.index] ?? background), level) }
        let speed = 0.08 + Double(config.speed) * 0.08
        let x = (k.x + k.w / 2) / Layout.width, y = (k.y + k.h / 2) / Layout.height
        let along: Double
        switch config.direction {
        case 1: along = -y
        case 2: along = y
        case 3: along = -x
        default: along = x
        }
        var base = config.color
        if config.rainbow && config.mode != .statik {
            base = RGB(hue: (along * 0.8 + (animated ? t * speed : 0)).truncatingRemainder(dividingBy: 1) + 1)
        }
        var k2 = level
        if config.mode == .breath || config.mode == .pulsating {
            k2 *= animated ? 0.35 + 0.65 * (0.5 + 0.5 * sin(t * speed * 12)) : 1
        }
        return mix(base, k2)
    }

    private func mix(_ c: RGB, _ k: Double) -> Color {
        let kc = RGB(white: 0.27)
        func ch(_ a: UInt8, _ b: UInt8) -> Double { (Double(a) * k + Double(b) * (1 - k) * 0.6) / 255 }
        return Color(.sRGB, red: ch(c.r, kc.r), green: ch(c.g, kc.g), blue: ch(c.b, kc.b))
    }
}

extension RGB {
    init(white: Double) {
        let v = UInt8(clamping: Int(white * 255))
        self.init(r: v, g: v, b: v)
    }
}
