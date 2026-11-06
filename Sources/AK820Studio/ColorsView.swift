import AK820Kit
import SwiftUI

struct ColorsView: View {
    @EnvironmentObject var store: Store
    @State private var brush = Color(.sRGB, red: 1, green: 0.4, blue: 0)
    @State private var eraser = false

    private let swatches: [RGB] = [
        RGB(r: 255, g: 0, b: 0), RGB(r: 255, g: 96, b: 0), RGB(r: 255, g: 208, b: 0), RGB(r: 0, g: 255, b: 0),
        RGB(r: 0, g: 255, b: 200), RGB(r: 0, g: 64, b: 255), RGB(r: 160, g: 0, b: 255), RGB(r: 255, g: 0, b: 160),
        RGB(r: 255, g: 255, b: 255),
    ]

    var body: some View {
        Page(hint: "Your own color for every key (the “Custom key colors” effect). Pick a color and click keys, then press “Write to keyboard”.") {
            HStack(spacing: 14) {
                ColorPicker("Brush", selection: $brush, supportsOpacity: false).fixedSize()
                ForEach(swatches, id: \.self) { s in
                    Circle().fill(s.color).frame(width: 22, height: 22)
                        .overlay(Circle().stroke(Color.primary.opacity(0.3)))
                        .onTapGesture { brush = s.color; eraser = false }
                }
                Toggle("Eraser", isOn: $eraser).toggleStyle(.button)
            }

            KeyboardView(
                fill: { k in (store.config.colors[k.index] ?? store.config.colorBackground).color },
                onTap: { k in
                    if eraser { store.config.colors[k.index] = nil } else { store.config.colors[k.index] = RGB(brush) }
                })
                .frame(maxWidth: 900)

            HStack(spacing: 14) {
                ColorPicker("Background (other keys)", selection: Binding(
                    get: { store.config.colorBackground.color },
                    set: { store.config.colorBackground = RGB($0) }), supportsOpacity: false).fixedSize()
                Button("Fill all with brush") {
                    for k in Layout.keys { store.config.colors[k.index] = RGB(brush) }
                }
                Button("Clear") { store.config.colors = [:] }
                Menu("Presets") {
                    Button("WASD + arrows") { preset(wasd: true) }
                    Button("Rainbow rows") { rainbowRows() }
                }
                .fixedSize()
            }
            LevelSlider(title: "Brightness", value: $store.config.colorBrightness, range: 1...5).frame(maxWidth: 360)
            WriteButton { store.applyColors() }
        }
    }

    private func preset(wasd: Bool) {
        store.config.colors = [:]
        for i in [39, 56, 57, 58, 99, 100, 101, 102] { store.config.colors[i] = RGB(brush) }
    }

    private func rainbowRows() {
        let rows: [RGB] = [RGB(r: 255, g: 0, b: 0), RGB(r: 255, g: 128, b: 0), RGB(r: 255, g: 230, b: 0),
                           RGB(r: 0, g: 220, b: 0), RGB(r: 0, g: 120, b: 255), RGB(r: 150, g: 0, b: 255)]
        for k in Layout.keys {
            let row = min(max(Int((k.y / 1.03).rounded(.down)), 0), rows.count - 1)
            store.config.colors[k.index] = rows[row]
        }
    }
}
