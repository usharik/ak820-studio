import AK820Kit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @Environment(\.openWindow) private var openWindow
    @State private var showLog = false
    @State private var confirmReset = false
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var language = (UserDefaults.standard.array(forKey: "AppleLanguages") as? [String])
        .flatMap { $0.count == 1 ? $0.first : nil } ?? ""

    private var s: Binding<KeyboardSettings> { $store.config.settings }

    var body: some View {
        Form {
            Section("Device") {
                if let d = store.device {
                    LabeledContent("Connection", value: d.connection.title)
                    LabeledContent(d.connection == .wired ? "Firmware" : "Receiver firmware", value: d.firmware)
                    LabeledContent("USB ID", value: String(format: "0C45:%04X", d.productID))
                    LabeledContent("Battery", value: store.battery.map { "\($0)%" } ?? "—")
                } else {
                    Text("Connect the keyboard with a USB-C cable or plug in its 2.4 GHz receiver. Bluetooth can't be used for configuration.")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Picker("Sleep after", selection: s.sleep) {
                    Text("Never").tag(0); Text("1 minute").tag(1); Text("5 minutes").tag(2); Text("30 minutes").tag(3)
                }
                Picker("Fn key", selection: s.fnToggle) {
                    Text("Active while held").tag(false)
                    Text("Toggles the layer (press to switch)").tag(true)
                }
                LevelSlider(title: "Debounce (response time)", value: s.responseLevel, range: 1...5)
                Toggle("Disable the Win/⌘ key", isOn: s.lockWin)
                Toggle("Disable Alt+F4", isOn: s.lockAltF4)
                Toggle("Disable Alt+Tab", isOn: s.lockAltTab)
            } header: {
                Text("Keyboard")
            } footer: {
                Text("The keyboard can't report its current values, so this shows what was last written from this Mac. Write with ⌘S.")
            }

            Section("Maintenance") {
                HStack {
                    Button { store.syncClock() } label: { Label("Sync clock", systemImage: "clock") }
                    Button { store.readBattery() } label: { Label("Refresh battery level", systemImage: "battery.75percent") }
                    Button { store.writeAll() } label: { Label("Write everything again", systemImage: "arrow.clockwise") }
                        .help("Sends keys, macros, lighting and settings remembered on this Mac — e.g. after resetting the keyboard itself.")
                }
                .disabled(store.busy != nil || !store.connected)
                HStack {
                    Button(role: .destructive) { confirmReset = true } label: { Label("Reset keyboard to factory defaults…", systemImage: "exclamationmark.arrow.triangle.2.circlepath") }
                        .disabled(store.busy != nil || !store.connected)
                    if store.hasBackup {
                        Button { store.undoFactoryReset() } label: { Label("Undo reset", systemImage: "arrow.uturn.backward") }
                            .disabled(store.busy != nil || !store.connected)
                    }
                }
                Text("Hardware reset on the keyboard itself: hold Fn + Space for 3–5 seconds.").font(.caption).foregroundStyle(.secondary)
            }

            Section("App") {
                Picker("Language", selection: $language) {
                    Text("System").tag("")
                    ForEach(Bundle.main.localizations.filter { $0 != "Base" }.sorted(), id: \.self) { code in
                        Text(verbatim: Locale(identifier: code).localizedString(forIdentifier: code)?.capitalized ?? code).tag(code)
                    }
                }
                .onChange(of: language) {
                    if language.isEmpty {
                        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
                    } else {
                        UserDefaults.standard.set([language], forKey: "AppleLanguages")
                    }
                    store.showToast(String(localized: "Restart AK820 Studio to apply the language."), ok: true)
                }
                Toggle("AK820 icon in the menu bar (quick lighting controls)", isOn: $showMenuBarExtra)
                Button("Quick Controls…") { openWindow(id: "quick-controls") }
                Text("If macOS hides the icon in a crowded menu bar, use Quick Controls from the app menu (⇧⌘L) or this button.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Launch at login", isOn: Binding(get: { launchAtLogin }, set: setLaunchAtLogin))
                HStack {
                    Button("Export all settings…") { store.exportConfig() }
                    Button("Import…") { store.importConfig() }
                }
            }

            Section {
                DisclosureGroup("Keyboard communication log", isExpanded: $showLog) {
                    ScrollView {
                        Text(verbatim: store.log.suffix(200).joined(separator: "\n"))
                            .font(.system(size: 11, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 220)
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
        .confirmationDialog("Reset the keyboard to factory defaults?", isPresented: $confirmReset) {
            Button("Reset", role: .destructive) { store.factoryReset() }
        } message: {
            Text("Keys on both layers, macros, lighting, key colors and settings go back to factory values. A copy of your configuration is kept on this Mac, so you can undo it.")
        }
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            store.showToast(String(localized: "Launch at login: \(error.localizedDescription)"), ok: false)
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
