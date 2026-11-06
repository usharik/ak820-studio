import AK820Kit
import SwiftUI

struct MacrosView: View {
    @EnvironmentObject var store: Store
    @State private var selection: UUID?

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                List(selection: $selection) {
                    ForEach(store.config.macros) { m in Text(m.name).tag(m.id) }
                }
                HStack {
                    Button { add() } label: { Image(systemName: "plus") }
                    Button { remove() } label: { Image(systemName: "minus") }.disabled(selection == nil)
                    Spacer()
                }
                .buttonStyle(.borderless)
                .padding(8)
            }
            .frame(minWidth: 180, idealWidth: 220, maxWidth: 280)

            Group {
                if let i = store.config.macros.firstIndex(where: { $0.id == selection }) {
                    MacroEditor(macro: $store.config.macros[i])
                        .id(store.config.macros[i].id)   // a fresh editor (and recorder) per macro
                } else {
                    Page(hint: "Macros are played by the keyboard itself: text, key combinations, pauses and mouse clicks. Create a macro (+), then assign it to a key on the “Keys” tab.") {
                        Text("Total space: about 3.5 KB (≈ 100 characters of text per 1 KB).").foregroundStyle(.secondary)
                    }
                }
            }
            .frame(minWidth: 460, maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func add() {
        let m = Macro(name: String(localized: "Macro \(store.config.macros.count + 1)"), steps: [.text("Hello")])
        store.config.macros.append(m)
        selection = m.id
    }

    private func remove() {
        guard let id = selection else { return }
        store.config.macros.removeAll { $0.id == id }
        for (k, a) in store.config.base { if case let .macro(mid, _, _) = a, mid == id { store.config.base[k] = nil } }
        for (k, a) in store.config.fn { if case let .macro(mid, _, _) = a, mid == id { store.config.fn[k] = nil } }
        selection = nil
    }
}

struct MacroEditor: View {
    @EnvironmentObject var store: Store
    @Binding var macro: Macro
    @State private var recording = false
    @State private var monitor: Any?

    private func startRecording() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
            // Typing into a text field (e.g. the macro name) is left alone.
            if NSApp.keyWindow?.firstResponder is NSTextView { return e }
            guard let code = HIDUsage.fromMacKeyCode[e.keyCode] else { return nil }
            var mods: UInt8 = 0
            let f = e.modifierFlags
            if f.contains(.control) { mods |= 0x01 }
            if f.contains(.shift) { mods |= 0x02 }
            if f.contains(.option) { mods |= 0x04 }
            if f.contains(.command) { mods |= 0x08 }
            macro.steps.append(.combo(modifiers: mods, code: code))
            return nil
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
    }

    private var sizeInfo: (String, Bool) {
        do {
            let all = store.config.macros
            let block = try Encode.macroBlock(all).data
            return (String(localized: "Macro memory used: \(block.count) of 3584 bytes"), true)
        } catch { return (error.localizedDescription, false) }
    }

    var body: some View {
        Page(hint: "Text is typed using the US English layout: use Latin letters, digits and ASCII symbols. With another input source active in macOS, symbols may come out differently.") {
            TextField("Name", text: $macro.name).textFieldStyle(.roundedBorder).frame(maxWidth: 360)

            ForEach(macro.steps.indices, id: \.self) { i in
                HStack(alignment: .top) {
                    Text("\(i + 1).").monospacedDigit().foregroundStyle(.secondary).frame(width: 24)
                    StepEditor(step: $macro.steps[i])
                    Spacer()
                    Button { macro.steps.swapAt(i, i - 1) } label: { Image(systemName: "arrow.up") }.disabled(i == 0)
                    Button { macro.steps.swapAt(i, i + 1) } label: { Image(systemName: "arrow.down") }.disabled(i == macro.steps.count - 1)
                    Button { macro.steps.remove(at: i) } label: { Image(systemName: "trash") }
                }
                .buttonStyle(.borderless)
            }

            HStack {
                Text("Add:")
                Button("Text") { macro.steps.append(.text("")) }
                Button("Key combination") { macro.steps.append(.combo(modifiers: 0x08, code: 0x06)) }
                Button("Pause") { macro.steps.append(.delay(ms: 200)) }
                Button("Mouse click") { macro.steps.append(.click(.left)) }
                Divider().frame(height: 18)
                Button { recording ? stopRecording() : startRecording() } label: {
                    Label(recording ? "Stop recording" : "Record keys", systemImage: recording ? "stop.circle.fill" : "record.circle")
                }
                .tint(recording ? .red : nil)
                .buttonStyle(.bordered)
            }
            if recording {
                Text("Press keys and shortcuts on the Mac keyboard — each one is added as a step.")
                    .font(.caption).foregroundStyle(.red)
            }

            Stepper("Pause between key events: \(macro.gapMs) ms", value: $macro.gapMs, in: 10...500, step: 5).frame(maxWidth: 360)

            let info = sizeInfo
            Text(info.0).font(.caption).foregroundStyle(info.1 ? Color.secondary : Color.red)

            Text("Macros are written together with the keymap: press “Write to keyboard” (⌘S).")
                .font(.caption).foregroundStyle(.secondary)
        }
        .onDisappear(perform: stopRecording)
    }
}

private struct StepEditor: View {
    @Binding var step: MacroStep

    var body: some View {
        switch step {
        case let .text(s):
            HStack {
                Text("Text").frame(width: 90, alignment: .leading)
                TextField("text to type", text: Binding(get: { s }, set: { step = .text($0) }), axis: .vertical)
                    .textFieldStyle(.roundedBorder).frame(minWidth: 260)
            }
        case let .combo(mods, code):
            HStack(alignment: .top) {
                Text("Combination").frame(width: 90, alignment: .leading)
                ComboEditor(modifiers: Binding(get: { mods }, set: { step = .combo(modifiers: $0, code: code) }),
                            code: Binding(get: { code }, set: { step = .combo(modifiers: mods, code: $0) }))
            }
        case let .delay(ms):
            HStack {
                Text("Pause").frame(width: 90, alignment: .leading)
                TextField("", value: Binding(get: { ms }, set: { step = .delay(ms: max(10, $0)) }), format: .number)
                    .textFieldStyle(.roundedBorder).frame(width: 90)
                Text("ms")
            }
        case let .click(btn):
            HStack {
                Text("Click").frame(width: 90, alignment: .leading)
                Picker("", selection: Binding(get: { btn }, set: { step = .click($0) })) {
                    ForEach([MouseAction.left, .right, .middle], id: \.self) { Text($0.title).tag($0) }
                }
                .labelsHidden().frame(width: 180)
            }
        }
    }
}
