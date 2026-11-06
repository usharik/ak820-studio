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
                } else {
                    Page(hint: "Макросы выполняет сама клавиатура: текст, сочетания клавиш, паузы и клики мыши. Создайте макрос (+), затем назначьте его клавише на вкладке «Клавиши».") {
                        Text("Всего места: около 3,5 КБ (≈ 100 символов текста на 1 КБ).").foregroundStyle(.secondary)
                    }
                }
            }
            .frame(minWidth: 460, maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func add() {
        let m = Macro(name: "Макрос \(store.config.macros.count + 1)", steps: [.text("Hello")])
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

    private var sizeInfo: (String, Bool) {
        do {
            let all = store.config.macros
            let block = try Encode.macroBlock(all)
            return ("Занято памяти макросов: \(block.count) из 3584 байт", true)
        } catch { return (error.localizedDescription, false) }
    }

    var body: some View {
        Page(hint: "Текст набирается в английской (US) раскладке: используйте латиницу, цифры и ASCII-символы. Если в macOS включена другая раскладка, символы могут отличаться.") {
            TextField("Название", text: $macro.name).textFieldStyle(.roundedBorder).frame(maxWidth: 360)

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
                Text("Добавить:")
                Button("Текст") { macro.steps.append(.text("")) }
                Button("Сочетание клавиш") { macro.steps.append(.combo(modifiers: 0x08, code: 0x06)) }
                Button("Пауза") { macro.steps.append(.delay(ms: 200)) }
                Button("Клик мыши") { macro.steps.append(.click(.left)) }
            }

            Stepper("Пауза между нажатиями: \(macro.gapMs) мс", value: $macro.gapMs, in: 10...500, step: 5).frame(maxWidth: 360)

            let info = sizeInfo
            Text(info.0).font(.caption).foregroundStyle(info.1 ? Color.secondary : Color.red)

            HStack {
                WriteButton(title: "Записать макросы и раскладку") { store.applyKeymap() }
                Text("Макросы отправляются вместе с раскладкой клавиш.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct StepEditor: View {
    @Binding var step: MacroStep

    var body: some View {
        switch step {
        case let .text(s):
            HStack {
                Text("Текст").frame(width: 90, alignment: .leading)
                TextField("что набрать", text: Binding(get: { s }, set: { step = .text($0) }), axis: .vertical)
                    .textFieldStyle(.roundedBorder).frame(minWidth: 260)
            }
        case let .combo(mods, code):
            HStack(alignment: .top) {
                Text("Сочетание").frame(width: 90, alignment: .leading)
                ComboEditor(modifiers: Binding(get: { mods }, set: { step = .combo(modifiers: $0, code: code) }),
                            code: Binding(get: { code }, set: { step = .combo(modifiers: mods, code: $0) }))
            }
        case let .delay(ms):
            HStack {
                Text("Пауза").frame(width: 90, alignment: .leading)
                TextField("", value: Binding(get: { ms }, set: { step = .delay(ms: max(10, $0)) }), format: .number)
                    .textFieldStyle(.roundedBorder).frame(width: 90)
                Text("мс")
            }
        case let .click(btn):
            HStack {
                Text("Клик").frame(width: 90, alignment: .leading)
                Picker("", selection: Binding(get: { btn }, set: { step = .click($0) })) {
                    ForEach([MouseAction.left, .right, .middle], id: \.self) { Text($0.title).tag($0) }
                }
                .labelsHidden().frame(width: 180)
            }
        }
    }
}
