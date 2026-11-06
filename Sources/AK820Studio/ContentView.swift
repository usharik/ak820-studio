import AK820Kit
import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case lighting = "Effects"
    case colors = "Key Colors"
    case live = "Live Lighting"
    case keymap = "Keys"
    case macros = "Macros"
    case screen = "Screen"
    case settings = "Settings"
    case shortcuts = "Keyboard Shortcuts"

    var id: String { rawValue }
    var title: LocalizedStringKey { LocalizedStringKey(rawValue) }

    var icon: String {
        switch self {
        case .lighting: return "sparkles"
        case .colors: return "paintpalette"
        case .live: return "waveform"
        case .keymap: return "keyboard"
        case .macros: return "text.badge.plus"
        case .screen: return "photo.on.rectangle"
        case .settings: return "gearshape"
        case .shortcuts: return "command"
        }
    }

    /// The keyboard part this page writes, if any.
    var part: Part? {
        switch self {
        case .lighting: return .lighting
        case .colors: return .colors
        case .keymap, .macros: return .keymap
        case .settings: return .settings
        case .live, .screen, .shortcuts: return nil
        }
    }

    static let groups: [(LocalizedStringKey, [AppSection])] = [
        ("Lighting", [.lighting, .colors, .live]),
        ("Keyboard", [.keymap, .macros]),
        ("Display", [.screen]),
        ("Device", [.settings, .shortcuts]),
    ]
}

struct ContentView: View {
    @EnvironmentObject var store: Store
    @State private var section: AppSection?

    init(section: AppSection = .lighting) { _section = State(initialValue: section) }

    var body: some View {
        NavigationSplitView {
            List(selection: $section) {
                DeviceCard().listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 10, trailing: 0))
                    .selectionDisabled()
                ForEach(AppSection.groups, id: \.1) { title, items in
                    Section(title) {
                        ForEach(items) { s in
                            HStack {
                                Label(s.title, systemImage: s.icon)
                                Spacer()
                                if let p = s.part, store.isDirty(p) {
                                    Circle().fill(Color.orange).frame(width: 7, height: 7)
                                        .help("Changes not written to the keyboard yet")
                                }
                                if s == .live, store.liveMode != nil {
                                    Image(systemName: "dot.radiowaves.left.and.right").foregroundStyle(.green).font(.caption)
                                }
                            }
                            .tag(s)
                        }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 210, ideal: 230)
        } detail: {
            let s = section ?? .lighting
            Group {
                switch s {
                case .lighting: LightingView()
                case .colors: ColorsView()
                case .live: LiveView()
                case .keymap: KeymapView()
                case .macros: MacrosView()
                case .screen: ScreenView()
                case .settings: SettingsView()
                case .shortcuts: ShortcutsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .navigationTitle(s.title)
            .toolbar { PageToolbar(section: s) }
            .overlay(alignment: .bottom) { ToastView().padding(16) }
        }
    }
}

/// Write button for the current page, highlighted when there are unsaved changes.
struct PageToolbar: ToolbarContent {
    @EnvironmentObject var store: Store
    let section: AppSection

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if let busy = store.busy {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text(verbatim: busy).foregroundStyle(.secondary)
                    if let p = store.progress { ProgressView(value: p).frame(width: 90) }
                }
            }
            if let part = section.part {
                let dirty = store.isDirty(part)
                Button { write(part) } label: {
                    Label(dirty ? "Write to keyboard" : "Written", systemImage: dirty ? "square.and.arrow.down" : "checkmark")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
                .tint(dirty ? .accentColor : .gray.opacity(0.6))
                .disabled(store.busy != nil || !store.connected)
                .keyboardShortcut("s", modifiers: .command)
                .help("Write this page to the keyboard (⌘S)")
            }
        }
    }

    private func write(_ part: Part) {
        switch part {
        case .lighting: store.applyLighting()
        case .colors: store.applyColors()
        case .keymap: store.applyKeymap()
        case .settings: store.applySettings()
        }
    }
}

struct DeviceCard: View {
    @EnvironmentObject var store: Store

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9).fill(store.connected ? Color.accentColor.gradient : Color.gray.gradient)
                Image(systemName: "keyboard.fill").foregroundStyle(.white).font(.system(size: 16, weight: .semibold))
            }
            .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "AK820 Pro").font(.headline)
                if let d = store.device {
                    HStack(spacing: 5) {
                        Image(systemName: d.connection == .wired ? "cable.connector" : "antenna.radiowaves.left.and.right")
                        Text(verbatim: d.connection.shortTitle)
                        if let b = store.battery {
                            Text(verbatim: "·")
                            Image(systemName: b > 80 ? "battery.100" : b > 50 ? "battery.75" : b > 20 ? "battery.50" : "battery.25")
                            Text(verbatim: "\(b)%")
                        }
                    }
                    .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Not connected").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary.opacity(0.6)))
        .help(store.device.map { String(localized: "Firmware \($0.firmware), USB ID 0C45:\(String(format: "%04X", $0.productID))") }
              ?? String(localized: "Connect the keyboard with a USB-C cable or plug in its 2.4 GHz receiver"))
    }
}

struct ToastView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        Group {
            if let t = store.toast {
                HStack(spacing: 8) {
                    Image(systemName: t.ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(t.ok ? .green : .orange)
                    Text(verbatim: t.text).lineLimit(3).textSelection(.enabled)
                    if !t.ok {
                        Button { store.toast = nil } label: { Image(systemName: "xmark") }.buttonStyle(.borderless)
                    }
                }
                .font(.callout)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.15), radius: 10, y: 3)
                .frame(maxWidth: 560)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: store.toast)
    }
}

/// Page scaffold: a short description and content.
struct Page<Content: View>: View {
    let hint: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(hint).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                content
            }
            .padding(24)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// A rounded content block.
struct Card<Content: View>: View {
    var title: LocalizedStringKey?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title { Text(title).font(.headline) }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.07)))
    }
}

/// Shown instead of controls that need the cable when connected through the receiver.
struct WiredOnlyNote: View {
    @EnvironmentObject var store: Store

    var body: some View {
        if store.device?.connection == .dongle {
            Label("This works over the USB cable only — connect the cable to write it.", systemImage: "cable.connector")
                .font(.callout).foregroundStyle(.orange)
        }
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
            Text(verbatim: "\(value)").monospacedDigit().foregroundStyle(.secondary).frame(width: 18)
        }
    }
}
