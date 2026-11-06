import AppKit
import SwiftUI

@main
struct AK820StudioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var store = Store()
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true

    var body: some Scene {
        Window("AK820 Studio", id: "main") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 980, minHeight: 640)
                // With the menu bar widget on, closing the window hides the Dock icon instead of quitting.
                .onAppear { NSApp.setActivationPolicy(.regular) }
                .onDisappear { if showMenuBarExtra { NSApp.setActivationPolicy(.accessory) } }
        }
        .commands {
            CommandGroup(replacing: .importExport) {
                Button("Export Settings…") { store.exportConfig() }
                Button("Import Settings…") { store.importConfig() }
            }
        }

        MenuBarExtra(isInserted: $showMenuBarExtra) {
            MenuBarView().environmentObject(store)
        } label: {
            Image(systemName: store.connected ? "keyboard.fill" : "keyboard")
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let dir = ProcessInfo.processInfo.environment["AK820_SNAPSHOT"] {
            Snapshot.renderAll(to: URL(fileURLWithPath: dir))
            exit(0)
        }
        // Lets `swift run` show a regular window too, not only the bundled .app.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !UserDefaults.standard.bool(forKey: "showMenuBarExtra", default: true)
    }
}

extension UserDefaults {
    func bool(forKey key: String, default value: Bool) -> Bool {
        object(forKey: key) == nil ? value : bool(forKey: key)
    }
}
