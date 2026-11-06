import AK820Kit
import ServiceManagement
import SwiftUI

/// Quick controls shown from the macOS menu bar.
struct MenuBarView: View {
    @EnvironmentObject var store: Store
    @Environment(\.openWindow) private var openWindow
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private let quickModes: [(LightingMode, String, LocalizedStringKey)] = [
        (.off, "lightbulb.slash", "Off"), (.statik, "circle.fill", "Static"), (.breath, "wind", "Breathing"),
        (.rolling, "water.waves", "Wave"), (.spectrum, "rainbow", "Spectrum"),
        (.ripples, "dot.radiowaves.left.and.right", "Rings"), (.singleOn, "hand.tap", "Press"),
        (.glittering, "sparkles", "Stars"),
    ]

    private let swatches: [RGB] = [
        RGB(r: 255, g: 255, b: 255), RGB(r: 255, g: 0, b: 0), RGB(r: 255, g: 96, b: 0), RGB(r: 255, g: 208, b: 0),
        RGB(r: 0, g: 255, b: 0), RGB(r: 0, g: 255, b: 200), RGB(r: 0, g: 64, b: 255), RGB(r: 160, g: 0, b: 255),
    ]

    private var light: LightingConfig { store.config.lighting }
    private var ready: Bool { store.connected && store.busy == nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()

            Text("Lighting").font(.caption).foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach(quickModes, id: \.0) { mode, icon, name in
                    Button { setMode(mode) } label: {
                        VStack(spacing: 3) {
                            Image(systemName: icon).font(.system(size: 15))
                            Text(name).font(.system(size: 10)).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .buttonStyle(.bordered)
                    .tint(light.mode == mode ? .accentColor : nil)
                    .help(mode.title)
                }
            }
            Button { applyCustomColors() } label: {
                Label("Custom key colors", systemImage: "paintpalette").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(light.mode == .custom ? .accentColor : nil)

            HStack(spacing: 6) {
                Button { setRainbow() } label: {
                    Circle().fill(AngularGradient(colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red], center: .center))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .help("Rainbow")
                ForEach(swatches, id: \.self) { c in
                    Button { setColor(c) } label: {
                        Circle().fill(c.color).frame(width: 18, height: 18)
                            .overlay(Circle().stroke(Color.primary.opacity(!light.rainbow && light.color == c ? 0.9 : 0.25),
                                                     lineWidth: !light.rainbow && light.color == c ? 2 : 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Image(systemName: "sun.min")
                Slider(value: Binding(get: { Double(light.brightness) },
                                      set: { store.config.lighting.brightness = Int($0.rounded()) }),
                       in: 0...5, step: 1) { editing in if !editing { apply() } }
                Image(systemName: "sun.max")
            }
            .disabled(light.mode == .off)

            Divider()
            VStack(spacing: 0) {
                MenuRow(title: "Sync clock", icon: "clock") { store.syncClock() }.disabled(!ready)
                MenuRow(title: "Open AK820 Studio…", icon: "macwindow") { openMain() }
            }
            Divider()
            Toggle("Launch at login", isOn: Binding(get: { launchAtLogin }, set: setLaunchAtLogin))
            Toggle("Show in menu bar", isOn: $showMenuBarExtra)
            Divider()
            MenuRow(title: "Quit", icon: "power") { NSApp.terminate(nil) }
        }
        .padding(14)
        .frame(width: 300)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "keyboard").font(.title2)
            VStack(alignment: .leading, spacing: 1) {
                Text("AK820 Pro").font(.headline)
                Group {
                    if let busy = store.busy {
                        Text(verbatim: "\(busy)…")
                    } else if !store.connected {
                        Text("Not connected by cable")
                    } else if let s = store.status, !s.ok {
                        Text(s.text).foregroundStyle(.orange)
                    } else {
                        if let b = store.battery { Text("Connected · battery \(b)%") } else { Text("Connected") }
                    }
                }
                .font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            Circle().fill(store.connected ? Color.green : Color.red).frame(width: 8, height: 8)
        }
    }

    private func setMode(_ m: LightingMode) {
        store.config.lighting.mode = m
        apply()
    }

    private func setColor(_ c: RGB) {
        store.config.lighting.color = c
        store.config.lighting.rainbow = false
        if [.off, .custom].contains(light.mode) { store.config.lighting.mode = .statik }
        apply()
    }

    private func setRainbow() {
        store.config.lighting.rainbow = true
        if [.off, .custom, .statik].contains(light.mode) { store.config.lighting.mode = .rolling }
        apply()
    }

    private func apply() {
        guard ready else { return }
        store.applyLighting()
    }

    private func applyCustomColors() {
        guard ready else { return }
        store.config.lighting.mode = .custom
        store.applyColors()
    }

    private func openMain() {
        NSApp.setActivationPolicy(.regular)
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            store.status = (String(localized: "Launch at login: \(error.localizedDescription)"), false)
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

/// A full-width menu-like row with hover highlight.
private struct MenuRow: View {
    let title: LocalizedStringKey
    let icon: String
    let action: () -> Void
    @State private var hover = false
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon).frame(width: 18)
                Text(title)
                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 5).fill(hover && enabled ? Color.accentColor.opacity(0.85) : .clear))
            .foregroundStyle(hover && enabled ? Color.white : Color.primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.4)
        .onHover { hover = $0 }
    }
}
