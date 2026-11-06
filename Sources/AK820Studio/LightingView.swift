import AK820Kit
import SwiftUI

struct LightingView: View {
    @EnvironmentObject var store: Store
    @State private var pending: DispatchWorkItem?

    private var light: Binding<LightingConfig> { $store.config.lighting }
    private var mode: LightingMode { store.config.lighting.mode }
    private var animated: Bool { ![.off, .statik].contains(mode) }

    var body: some View {
        Page(hint: "Built-in lighting effects. They are stored in the keyboard and work on any computer.") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 8)], spacing: 8) {
                ForEach(LightingMode.effects) { m in
                    Button { light.wrappedValue.mode = m; changed() } label: {
                        Text(m.title).frame(maxWidth: .infinity, minHeight: 28)
                    }
                    .buttonStyle(.bordered)
                    .tint(m == mode ? .accentColor : nil)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(m == mode ? Color.accentColor : .clear, lineWidth: 2))
                }
            }

            Form {
                if mode != .off {
                    if mode != .statik {
                        Toggle("Rainbow (instead of a single color)", isOn: light.rainbow).onChange(of: store.config.lighting.rainbow) { changed() }
                    }
                    ColorPicker("Color", selection: Binding(
                        get: { store.config.lighting.color.color },
                        set: { light.wrappedValue.color = RGB($0); changed() }), supportsOpacity: false)
                        .disabled(store.config.lighting.rainbow && mode != .statik)
                    LevelSlider(title: "Brightness", value: light.brightness, onChange: changed)
                    if animated {
                        LevelSlider(title: "Speed", value: light.speed, onChange: changed)
                        Picker("Direction", selection: light.direction) {
                            Text("← Left").tag(0); Text("↓ Down").tag(1); Text("↑ Up").tag(2); Text("→ Right").tag(3)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: store.config.lighting.direction) { changed() }
                    }
                }
                Toggle("Apply changes immediately", isOn: $store.config.applyLightingInstantly)
            }
            .formStyle(.grouped)
            .frame(maxWidth: 560)

            HStack {
                WriteButton(title: "Apply") { store.applyLighting() }
                Text("Tip: Fn + keys on the keyboard itself switch effects too.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    /// Debounced auto-apply.
    private func changed() {
        guard store.config.applyLightingInstantly, store.connected else { return }
        pending?.cancel()
        let item = DispatchWorkItem { [store] in store.applyLighting() }
        pending = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: item)
    }
}

struct LevelSlider: View {
    let title: LocalizedStringKey
    @Binding var value: Int
    var range: ClosedRange<Int> = 0...5
    var onChange: () -> Void = {}

    var body: some View {
        HStack {
            Text(title)
            Slider(value: Binding(get: { Double(value) }, set: { value = Int($0.rounded()) }),
                   in: Double(range.lowerBound)...Double(range.upperBound), step: 1) { editing in
                if !editing { onChange() }
            }
            Text("\(value)").monospacedDigit().frame(width: 20)
        }
    }
}
