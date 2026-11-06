import AK820Kit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @State private var showLog = false
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true
    @State private var language = (UserDefaults.standard.array(forKey: "AppleLanguages") as? [String])
        .flatMap { $0.count == 1 ? $0.first : nil } ?? ""

    private var s: Binding<KeyboardSettings> { $store.config.settings }

    var body: some View {
        Page(hint: "Keyboard system settings. The keyboard can't report its current values, so this shows what was last written from this Mac.") {
            Form {
                Picker("Sleep after", selection: s.sleep) {
                    Text("Never").tag(0); Text("1 minute").tag(1); Text("5 minutes").tag(2); Text("30 minutes").tag(3)
                }
                Picker("Fn key", selection: s.fnToggle) {
                    Text("Active while held").tag(false)
                    Text("Toggles the layer (press to switch)").tag(true)
                }
                LevelSlider(title: "Debounce (response time)", value: s.responseLevel, range: 1...5)
                Section("Locks (for games)") {
                    Toggle("Disable the Win/⌘ key", isOn: s.lockWin)
                    Toggle("Disable Alt+F4", isOn: s.lockAltF4)
                    Toggle("Disable Alt+Tab", isOn: s.lockAltTab)
                }
            }
            .formStyle(.grouped)
            .frame(maxWidth: 560)

            WriteButton { store.applySettings() }

            Divider()
            HStack {
                Button("Sync clock") { store.syncClock() }.disabled(store.busy != nil || !store.connected)
                Button("Refresh battery level") { store.readBattery() }.disabled(!store.connected)
            }
            HStack {
                Picker("Language", selection: $language) {
                    Text("System").tag("")
                    ForEach(Bundle.main.localizations.filter { $0 != "Base" }.sorted(), id: \.self) { code in
                        Text(verbatim: Locale(identifier: code).localizedString(forIdentifier: code)?.capitalized ?? code).tag(code)
                    }
                }
                .frame(maxWidth: 300)
                .onChange(of: language) {
                    if language.isEmpty {
                        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
                    } else {
                        UserDefaults.standard.set([language], forKey: "AppleLanguages")
                    }
                    store.status = (String(localized: "Restart AK820 Studio to apply the language."), true)
                }
            }
            Toggle("AK820 icon in the menu bar (quick lighting controls)", isOn: $showMenuBarExtra)
            HStack {
                Button("Export all settings…") { store.exportConfig() }
                Button("Import…") { store.importConfig() }
            }

            DisclosureGroup("Keyboard communication log", isExpanded: $showLog) {
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
