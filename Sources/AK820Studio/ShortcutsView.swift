import AK820Kit
import SwiftUI

/// Factory shortcuts of the AK820 Pro, from the official manual
/// (https://epomaker.com/cdn/shop/files/AK820_PRO_manual.pdf) and ak820-mac's hardware notes.
struct Shortcut: Identifiable {
    let id = UUID()
    /// Key chips, e.g. ["Fn", "\\"].
    let keys: [String]
    /// Layout indices to highlight on the keyboard drawing.
    let indices: [Int]
    let title: String
    var detail: String?
    /// Short label drawn on the key in the Fn-layer map.
    var caption: String?
    /// True if this is a Fn-layer shortcut a remap on the Keys page can replace.
    var fnLayer = true
}

struct ShortcutGroup: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let items: [Shortcut]
}

enum Shortcuts {
    static let groups: [ShortcutGroup] = [
        ShortcutGroup(title: String(localized: "Lighting"), icon: "sparkles", items: [
            Shortcut(keys: ["Fn", "\\"], indices: [67], title: String(localized: "Next lighting effect"),
                     detail: String(localized: "Cycles through the 20 built-in effects."), caption: String(localized: "Effect")),
            Shortcut(keys: ["Fn", "↑"], indices: [101], title: String(localized: "Brightness up"),
                     detail: String(localized: "Six levels; the keys flash three times at the maximum."), caption: "☀︎+"),
            Shortcut(keys: ["Fn", "↓"], indices: [100], title: String(localized: "Brightness down"),
                     detail: String(localized: "Six levels; at the lowest the backlight turns off."), caption: "☀︎−"),
            Shortcut(keys: ["Fn", "←"], indices: [99], title: String(localized: "Change effect direction"), caption: "⇄"),
            Shortcut(keys: ["Fn", "→"], indices: [102], title: String(localized: "Change lighting color"),
                     detail: String(localized: "RGB → red → orange → yellow → green → cyan → blue → purple → white."), caption: String(localized: "Color")),
            Shortcut(keys: ["Fn", "−"], indices: [30], title: String(localized: "Effect slower"), caption: String(localized: "Speed −")),
            Shortcut(keys: ["Fn", "="], indices: [31], title: String(localized: "Effect faster"), caption: String(localized: "Speed +")),
            Shortcut(keys: ["Fn", "X"], indices: [75], title: String(localized: "Lights on / off"),
                     detail: String(localized: "If the lights were switched off from the app, switch them on from the app."), caption: String(localized: "Light")),
        ]),
        ShortcutGroup(title: String(localized: "Game lighting"), icon: "gamecontroller", items: [
            Shortcut(keys: ["Fn", "1"], indices: [20], title: String(localized: "Game lighting 1 (FPS)"),
                     detail: String(localized: "Lights W A S D and the arrows."), caption: "FPS"),
            Shortcut(keys: ["Fn", "2"], indices: [21], title: String(localized: "Game lighting 2 (LOL)"),
                     detail: String(localized: "Lights Q W E R D F G, 1–6, Ctrl, Alt, Tab, Space and Esc."), caption: "LOL"),
            Shortcut(keys: ["Fn", "3"], indices: [22], title: String(localized: "Game lighting 3 (office)"),
                     detail: String(localized: "Lights the 37 letter and symbol keys and the arrows. On some keyboards it comes empty."), caption: String(localized: "Office")),
            Shortcut(keys: ["Fn", "`"], indices: [19], title: String(localized: "Record game lighting colors"),
                     detail: String(localized: "In a game lighting mode, each key press changes that key's color (8 colors). Press again to save."), caption: String(localized: "Record")),
        ]),
        ShortcutGroup(title: String(localized: "Connection"), icon: "antenna.radiowaves.left.and.right", items: [
            Shortcut(keys: ["Fn", "Q"], indices: [38], title: String(localized: "Bluetooth device 1"),
                     detail: String(localized: "Press to switch, hold 3 s to pair (the key flashes fast)."), caption: "BT 1"),
            Shortcut(keys: ["Fn", "W"], indices: [39], title: String(localized: "Bluetooth device 2"),
                     detail: String(localized: "Press to switch, hold 3 s to pair (the key flashes fast)."), caption: "BT 2"),
            Shortcut(keys: ["Fn", "E"], indices: [40], title: String(localized: "Bluetooth device 3"),
                     detail: String(localized: "Press to switch, hold 3 s to pair (the key flashes fast)."), caption: "BT 3"),
            Shortcut(keys: ["Fn", "R"], indices: [41], title: String(localized: "Pair the 2.4 GHz receiver"),
                     detail: String(localized: "Switch to 2.4G on the back, plug in the receiver, then hold 3 s."), caption: "2.4G"),
            Shortcut(keys: [String(localized: "Switch on the back")], indices: [], title: String(localized: "BT · USB · 2.4G"),
                     detail: String(localized: "Bluetooth, cable (also charges) or receiver. The app configures the keyboard over the cable or the receiver."), fnLayer: false),
            Shortcut(keys: [String(localized: "Switch on the back")], indices: [], title: String(localized: "Win · Mac"),
                     detail: String(localized: "In Mac mode Win works as ⌥ Option and Alt as ⌘ Command, and F1–F12 work like a Mac's top row."), fnLayer: false),
        ]),
        ShortcutGroup(title: String(localized: "Screen and knob"), icon: "dial.medium", items: [
            Shortcut(keys: ["Fn", "Del"], indices: [119], title: String(localized: "Screen: animation ↔ clock"), caption: String(localized: "Screen")),
            Shortcut(keys: ["Fn", "Home"], indices: [117], title: String(localized: "Screen off / on"), caption: "⏻"),
            Shortcut(keys: ["Fn", String(localized: "Knob press")], indices: [], title: String(localized: "Settings menu on the screen"),
                     detail: String(localized: "Effect, color, brightness, speed and screen language. Turn the knob to choose, press to confirm.")),
            Shortcut(keys: [String(localized: "Turn the knob")], indices: [], title: String(localized: "Volume up / down"), fnLayer: false),
            Shortcut(keys: [String(localized: "Knob press")], indices: [], title: String(localized: "Mute"), fnLayer: false),
        ]),
        ShortcutGroup(title: String(localized: "System functions"), icon: "gearshape", items: [
            Shortcut(keys: ["Fn", "Win"], indices: [92], title: String(localized: "Lock the Win key"),
                     detail: String(localized: "The W light turns on. Press again to unlock."), caption: String(localized: "Lock")),
            Shortcut(keys: ["Fn", "PgUp"], indices: [118], title: String(localized: "Print Screen"), caption: "PrtSc"),
            Shortcut(keys: ["Fn", "PgDn"], indices: [121], title: String(localized: "Pause"), caption: "Pause"),
            Shortcut(keys: ["Fn", String(localized: "Space")], indices: [94], title: String(localized: "Factory reset (hold 3–5 s)"),
                     detail: String(localized: "The backlight flashes three times; keys, macros, lighting and settings go back to factory values."),
                     caption: String(localized: "Reset (3 s)")),
        ]),
    ]

    /// F1–F12: [Mac mode without Fn, Windows mode with Fn]. In Mac mode Fn + F-key gives the plain F-key.
    static let functionRow: [(String, String)] = [
        (String(localized: "Display brightness −"), String(localized: "Media player")),
        (String(localized: "Display brightness +"), String(localized: "Volume −")),
        ("Mission Control", String(localized: "Volume +")),
        (String(localized: "Console"), String(localized: "Mute")),
        (String(localized: "Keyboard backlight −"), String(localized: "Play / stop")),
        (String(localized: "Keyboard backlight +"), String(localized: "Previous track")),
        (String(localized: "Previous track"), String(localized: "Play / pause")),
        (String(localized: "Play / pause"), String(localized: "Next track")),
        (String(localized: "Next track"), String(localized: "Mail")),
        (String(localized: "Mute"), String(localized: "Browser")),
        (String(localized: "Volume −"), String(localized: "My Computer")),
        (String(localized: "Volume +"), String(localized: "Calculator")),
    ]

    static let fRowCaptions = ["☀︎−", "☀︎+", "⧉", "⌘", "⌨︎−", "⌨︎+", "⏮", "⏯", "⏭", "🔇", "🔉", "🔊"]
}

struct ShortcutsView: View {
    @EnvironmentObject var store: Store
    @State private var hovered: Set<Int> = []
    @State private var focused: Int?
    @State private var query = ""

    private var captions: [Int: String] {
        var c: [Int: String] = [:]
        for g in Shortcuts.groups { for s in g.items { if let cap = s.caption { for i in s.indices { c[i] = cap } } } }
        return c
    }

    private func matches(_ s: Shortcut) -> Bool {
        if let f = focused { return s.indices.contains(f) }
        guard !query.isEmpty else { return true }
        let q = query.lowercased()
        return ([s.title, s.detail ?? ""] + s.keys).contains { $0.lowercased().contains(q) }
    }

    var body: some View {
        Page(hint: "Factory shortcuts of the keyboard itself, from the official manual. Hover a shortcut to see its keys; click a key to see what it does with Fn.") {
            HStack {
                TextField("Search shortcuts", text: $query).textFieldStyle(.roundedBorder).frame(maxWidth: 320)
                if focused != nil {
                    Button { focused = nil } label: { Label("Show all", systemImage: "xmark.circle") }
                }
                Spacer()
            }
            .frame(maxWidth: 980)

            let caps = captions
            KeyboardView(
                fill: { k in
                    if k.index == Layout.fnIndex { return Color.accentColor }
                    return caps[k.index] != nil || (2...13).contains(k.index) ? Color(white: 0.34) : .keyCap
                },
                caption: { k in
                    if store.config.fn[k.index] != nil { return String(localized: "remapped") }
                    if let c = caps[k.index] { return c }
                    return (2...13).contains(k.index) ? Shortcuts.fRowCaptions[k.index - 2] : nil
                },
                selected: hovered.union(focused.map { [$0, Layout.fnIndex] } ?? []),
                onTap: { k in focused = focused == k.index ? nil : k.index; query = "" })
                .frame(maxWidth: 980)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 420), spacing: 14, alignment: .top)], alignment: .leading, spacing: 14) {
                ForEach(Shortcuts.groups) { g in
                    let items = g.items.filter(matches)
                    if !items.isEmpty {
                        Card {
                            Label(g.title, systemImage: g.icon).font(.headline)
                            ForEach(items) { s in row(s) }
                        }
                    }
                }
                if focused == nil || (2...13).contains(focused ?? 0) {
                    fRow
                }
            }
            .frame(maxWidth: 980)

            Text("Shortcuts are part of the Fn layer: a remap on the Keys page replaces the factory shortcut of that key. Keys marked “remapped” have a custom Fn action.")
                .font(.caption).foregroundStyle(.secondary).frame(maxWidth: 980, alignment: .leading)
        }
    }

    private func row(_ s: Shortcut) -> some View {
        let remapped = s.fnLayer && s.indices.contains { store.config.fn[$0] != nil }
        return HStack(alignment: .firstTextBaseline, spacing: 12) {
            HStack(spacing: 3) {
                ForEach(Array(s.keys.enumerated()), id: \.offset) { i, k in
                    if i > 0 { Text(verbatim: "+").foregroundStyle(.secondary).font(.caption) }
                    KeyChip(text: k)
                }
            }
            .frame(minWidth: 96, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(verbatim: s.title)
                    if remapped {
                        Text("remapped").font(.caption2.bold()).padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Capsule().fill(Color.orange.opacity(0.2))).foregroundStyle(.orange)
                            .help("Replaced by your remap on the Keys page")
                    }
                }
                if let d = s.detail { Text(verbatim: d).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(!s.indices.isEmpty && hovered == Set(s.indices) ? Color.accentColor.opacity(0.1) : .clear))
        .contentShape(Rectangle())
        .onHover { inside in
            if inside { hovered = Set(s.indices) } else if hovered == Set(s.indices) { hovered = [] }
        }
    }

    private var fRow: some View {
        Card {
            Label("F1–F12", systemImage: "f.cursive").font(.headline)
            Text("Mac mode: without Fn the keys work like a Mac's top row, with Fn they are plain F1–F12. Windows mode: the other way round — Fn + F-key gives the media function.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 4) {
                GridRow {
                    Text(verbatim: "")
                    Text("Mac").font(.caption.bold()).foregroundStyle(.secondary)
                    Text("Windows (Fn +)").font(.caption.bold()).foregroundStyle(.secondary)
                }
                ForEach(Array(Shortcuts.functionRow.enumerated()), id: \.offset) { i, f in
                    let idx = i + 2
                    if focused == nil || focused == idx {
                        GridRow {
                            KeyChip(text: "F\(i + 1)")
                            Text(verbatim: f.0)
                            Text(verbatim: f.1).foregroundStyle(.secondary)
                        }
                        .onHover { inside in
                            if inside { hovered = [idx] } else if hovered == [idx] { hovered = [] }
                        }
                    }
                }
            }
        }
    }
}

/// A key cap drawn inline.
struct KeyChip: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color(nsColor: .controlColor)))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.primary.opacity(0.25)))
            .shadow(color: .black.opacity(0.12), radius: 0, y: 1)
            .fixedSize()
    }
}
