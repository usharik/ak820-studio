import AK820Kit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @State private var showLog = false

    private var s: Binding<KeyboardSettings> { $store.config.settings }

    var body: some View {
        Page(hint: "Системные настройки клавиатуры. Клавиатура не умеет сообщать текущие значения, поэтому здесь показано то, что последний раз было записано с этого Mac.") {
            Form {
                Picker("Засыпать через", selection: s.sleep) {
                    Text("Никогда").tag(0); Text("1 минуту").tag(1); Text("5 минут").tag(2); Text("30 минут").tag(3)
                }
                Picker("Клавиша Fn", selection: s.fnToggle) {
                    Text("Работает, пока зажата").tag(false)
                    Text("Переключает слой (нажал — включил)").tag(true)
                }
                LevelSlider(title: "Защита от дребезга (время отклика)", value: s.responseLevel, range: 1...5)
                Section("Блокировки (для игр)") {
                    Toggle("Отключить клавишу Win/⌘", isOn: s.lockWin)
                    Toggle("Отключить Alt+F4", isOn: s.lockAltF4)
                    Toggle("Отключить Alt+Tab", isOn: s.lockAltTab)
                }
            }
            .formStyle(.grouped)
            .frame(maxWidth: 560)

            WriteButton { store.applySettings() }

            Divider()
            HStack {
                Button("Синхронизировать часы") { store.syncClock() }.disabled(store.busy != nil || !store.connected)
                Button("Обновить заряд батареи") { store.readBattery() }.disabled(!store.connected)
            }
            HStack {
                Button("Экспорт всех настроек…") { store.exportConfig() }
                Button("Импорт…") { store.importConfig() }
            }

            DisclosureGroup("Журнал обмена с клавиатурой", isExpanded: $showLog) {
                ScrollView {
                    Text(store.log.suffix(200).joined(separator: "\n"))
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 220)
            }
        }
    }
}
