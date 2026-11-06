import AK820Kit
import SwiftUI

struct ColorsView: View {
    @EnvironmentObject var store: Store
    @State private var brush = RGB(r: 255, g: 96, b: 0)
    @State private var tool = Tool.brush

    enum Tool: String, CaseIterable, Identifiable {
        case brush, eraser, picker
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .brush: return "paintbrush.pointed"
            case .eraser: return "eraser"
            case .picker: return "eyedropper"
            }
        }
        var title: LocalizedStringKey {
            switch self {
            case .brush: return "Brush"
            case .eraser: return "Eraser"
            case .picker: return "Pick color"
            }
        }
    }

    var body: some View {
        Page(hint: "Your own color for every key. Pick a color, then click or drag across the keys.") {
            WiredOnlyNote()
            Card {
                HStack(spacing: 14) {
                    Picker("", selection: $tool) {
                        ForEach(Tool.allCases) { Label($0.title, systemImage: $0.icon).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().fixedSize()
                    ColorPicker("", selection: Binding(get: { brush.color }, set: { brush = RGB($0); tool = .brush }), supportsOpacity: false)
                        .labelsHidden()
                    SwatchRow(selected: brush) { brush = $0; tool = .brush }
                }
            }

            KeyboardView(
                fill: { k in mix(store.config.colors[k.index] ?? store.config.colorBackground) },
                glow: true,
                onPaint: paint)
                .frame(maxWidth: 980)

            Card {
                HStack(spacing: 12) {
                    ColorPicker("Background (other keys)", selection: Binding(
                        get: { store.config.colorBackground.color },
                        set: { store.config.colorBackground = RGB($0) }), supportsOpacity: false).fixedSize()
                    Spacer()
                    Menu("Presets") {
                        Button("Fill all with brush") { for k in Layout.keys { store.config.colors[k.index] = brush } }
                        Button("WASD + arrows") { highlight([39, 56, 57, 58, 99, 100, 101, 102]) }
                        Button("Rainbow rows") { gradient { _, y in RGB(hue: y * 0.8) } }
                        Button("Rainbow columns") { gradient { x, _ in RGB(hue: x * 0.85) } }
                        Button("Sunset") { gradient { x, _ in RGB(hue: 0.95 + x * 0.17) } }
                        Button("Ocean") { gradient { x, y in RGB(hue: 0.5 + x * 0.15, brightness: 1 - y * 0.5) } }
                    }
                    .fixedSize()
                    Button("Clear", role: .destructive) { store.config.colors = [:] }
                }
                LevelSlider(title: "Brightness", value: $store.config.colorBrightness, range: 1...5)
                    .frame(maxWidth: 420)
            }
        }
    }

    private func paint(_ k: KeySpec) {
        switch tool {
        case .brush: if store.config.colors[k.index] != brush { store.config.colors[k.index] = brush }
        case .eraser: if store.config.colors[k.index] != nil { store.config.colors[k.index] = nil }
        case .picker:
            brush = store.config.colors[k.index] ?? store.config.colorBackground
            tool = .brush
        }
    }

    private func mix(_ c: RGB) -> Color {
        let k = 0.4 + 0.6 * Double(store.config.colorBrightness) / 5
        return c == .black ? .keyCap : c.scaled(k).color
    }

    private func highlight(_ keys: [Int]) {
        store.config.colors = [:]
        for i in keys { store.config.colors[i] = brush }
    }

    private func gradient(_ f: (Double, Double) -> RGB) {
        for k in Layout.keys {
            store.config.colors[k.index] = f((k.x + k.w / 2) / Layout.width, (k.y + k.h / 2) / Layout.height)
        }
    }
}
