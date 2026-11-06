import AK820Kit
import SwiftUI

struct KeymapView: View {
    @EnvironmentObject var store: Store
    @State private var fnLayer = false
    @State private var selected: Int?

    private var layer: Binding<[Int: KeyAction]> { fnLayer ? $store.config.fn : $store.config.base }

    var body: some View {
        Page(hint: "Remapping is stored in the keyboard itself: it works on any computer, over cable, 2.4 GHz and Bluetooth. Click a key, choose an action, then press “Write to keyboard”.") {
            HStack {
                Picker("", selection: $fnLayer) {
                    Text("Base layer").tag(false)
                    Text("Fn layer (Fn + key)").tag(true)
                }
                .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 380)
                Spacer()
                Menu {
                    Button("Reset this layer", role: .destructive) { layer.wrappedValue = [:]; selected = nil }
                    Button("Reset all", role: .destructive) { store.config.base = [:]; store.config.fn = [:]; selected = nil }
                } label: { Label("Reset", systemImage: "arrow.counterclockwise") }
                .fixedSize()
            }
            .frame(maxWidth: 980)
            .onChange(of: fnLayer) { selected = nil }

            KeyboardView(
                fill: { k in layer.wrappedValue[k.index] != nil ? Color.accentColor.opacity(0.55) : .keyCap },
                caption: { k in layer.wrappedValue[k.index]?.describe(macros: store.config.macros) },
                selected: selected.map { [$0] } ?? [],
                disabled: { k in k.index == Layout.fnIndex || (fnLayer && k.fnLocked) },
                onTap: { selected = $0.index })
                .frame(maxWidth: 980)

            HStack(alignment: .top, spacing: 14) {
                Card {
                    if let i = selected, let key = Layout.key(i) {
                        Text(verbatim: "\(fnLayer ? "Fn + " : "")\(key.label)").font(.title3.bold())
                        ActionEditor(action: Binding(get: { layer.wrappedValue[i] },
                                                     set: { layer.wrappedValue[i] = $0 }),
                                     macros: store.config.macros)
                            .id("\(fnLayer)-\(i)")   // "Press to pick" must not outlive the selected key
                    } else {
                        Label("Select a key on the layout.", systemImage: "cursorarrow.click").foregroundStyle(.secondary)
                    }
                }
                Card(title: "Changed keys") {
                    let changed = layer.wrappedValue.sorted { $0.key < $1.key }
                    if changed.isEmpty {
                        Text("All keys work as from the factory.").foregroundStyle(.secondary)
                    }
                    ForEach(changed, id: \.key) { idx, action in
                        HStack {
                            Text(verbatim: Layout.key(idx)?.label ?? "#\(idx)").bold().frame(width: 70, alignment: .leading)
                            Image(systemName: "arrow.right").foregroundStyle(.secondary)
                            Text(verbatim: action.describe(macros: store.config.macros)).lineLimit(1)
                            Spacer()
                            Button { layer.wrappedValue[idx] = nil } label: { Image(systemName: "xmark.circle.fill") }
                                .buttonStyle(.borderless).foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selected = idx }
                    }
                }
                .frame(maxWidth: 360)
            }
            .frame(maxWidth: 980)

            Text("In Mac mode the keyboard swaps Win and Alt by itself. A remapped key sends exactly what you set (⌘, ⌥ …). “Reset” + “Write to keyboard” restores the factory keymap. Fn can't be remapped.")
                .font(.caption).foregroundStyle(.secondary).frame(maxWidth: 980, alignment: .leading)
        }
    }
}

private enum ActionKind: String, CaseIterable, Identifiable {
    case none = "Default", key = "Key / combination", media = "Media", mouse = "Mouse", macro = "Macro", disabled = "Disable"
    var id: String { rawValue }
    var title: LocalizedStringKey { LocalizedStringKey(rawValue) }

    init(_ a: KeyAction?) {
        switch a {
        case nil: self = .none
        case .key: self = .key
        case .media: self = .media
        case .mouse: self = .mouse
        case .macro: self = .macro
        case .disabled: self = .disabled
        }
    }
}

struct ActionEditor: View {
    @Binding var action: KeyAction?
    let macros: [Macro]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Action", selection: Binding(get: { ActionKind(action) }, set: setKind)) {
                ForEach(ActionKind.allCases) { Text($0.title).tag($0) }
            }

            switch action {
            case let .key(mods, code):
                ComboEditor(modifiers: Binding(get: { mods }, set: { action = .key(modifiers: $0, code: code) }),
                            code: Binding(get: { code }, set: { action = .key(modifiers: mods, code: $0) }))
            case let .media(code):
                Picker("Function", selection: Binding(get: { code }, set: { action = .media($0) })) {
                    ForEach(HIDUsage.media, id: \.code) { Text($0.name).tag($0.code) }
                }
            case let .mouse(m):
                Picker("Button", selection: Binding(get: { m }, set: { action = .mouse($0) })) {
                    ForEach(MouseAction.allCases, id: \.self) { Text($0.title).tag($0) }
                }
            case let .macro(id, mode, times):
                if macros.isEmpty {
                    Text("Create a macro on the “Macros” tab first.").foregroundStyle(.secondary)
                } else {
                    Picker("Macro", selection: Binding(get: { id }, set: { action = .macro(id: $0, mode: mode, times: times) })) {
                        ForEach(macros) { Text($0.name).tag($0.id) }
                    }
                    Picker("Playback", selection: Binding(get: { mode }, set: { action = .macro(id: id, mode: $0, times: times) })) {
                        ForEach(MacroPlayMode.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    if mode == .times {
                        Stepper("Repeats: \(times)", value: Binding(get: { times }, set: { action = .macro(id: id, mode: mode, times: $0) }), in: 1...255)
                    }
                }
            case .disabled:
                Text("The key will do nothing (experimental).").foregroundStyle(.secondary)
            case nil:
                Text("The key works as from the factory.").foregroundStyle(.secondary)
            }
        }
    }

    private func setKind(_ k: ActionKind) {
        switch k {
        case .none: action = nil
        case .key: action = .key(modifiers: 0, code: 0x04)
        case .media: action = .media(0xCD)
        case .mouse: action = .mouse(.left)
        case .macro: action = macros.first.map { .macro(id: $0.id, mode: .once, times: 1) } ?? .macro(id: UUID(), mode: .once, times: 1)
        case .disabled: action = .disabled
        }
    }
}

/// Modifier toggles + key picker + "press a key" capture.
struct ComboEditor: View {
    @Binding var modifiers: UInt8
    @Binding var code: UInt8
    @State private var capturing = false
    @State private var monitor: Any?

    private let mods: [(UInt8, String)] = [(0x08, "⌘"), (0x04, "⌥"), (0x01, "⌃"), (0x02, "⇧")]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Modifiers")
                ForEach(mods, id: \.0) { bit, sym in
                    Toggle(sym, isOn: Binding(get: { modifiers & bit != 0 },
                                              set: { modifiers = $0 ? modifiers | bit : modifiers & ~bit }))
                        .toggleStyle(.button)
                }
                Menu("Right-hand…") {
                    ForEach(HIDUsage.modifiers.filter { $0.bit >= 0x10 }, id: \.bit) { m in
                        Toggle(m.name, isOn: Binding(get: { modifiers & m.bit != 0 },
                                                     set: { modifiers = $0 ? modifiers | m.bit : modifiers & ~m.bit }))
                    }
                }
                .fixedSize()
            }
            HStack {
                Picker("Key", selection: $code) {
                    Text("— (modifiers only)").tag(UInt8(0))
                    ForEach(HIDUsage.keys) { Text($0.name).tag($0.code) }
                }
                .frame(maxWidth: 300)
                Button(capturing ? "Press a key… (Esc to cancel)" : "Press to pick") { capturing ? stop() : start() }
            }
        }
        .onDisappear(perform: stop)
    }

    private func start() {
        capturing = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
            if e.keyCode == 0x35, e.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty { stop(); return nil }
            if let u = HIDUsage.fromMacKeyCode[e.keyCode] {
                var m: UInt8 = 0
                let f = e.modifierFlags
                if f.contains(.control) { m |= 0x01 }
                if f.contains(.shift) { m |= 0x02 }
                if f.contains(.option) { m |= 0x04 }
                if f.contains(.command) { m |= 0x08 }
                code = u
                modifiers = m
            }
            stop()
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        capturing = false
    }
}
