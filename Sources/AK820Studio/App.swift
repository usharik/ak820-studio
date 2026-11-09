import AppKit
import SwiftUI

@main
struct AK820StudioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var store = Store()
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true

    var body: some Scene {
        Window("AK820 Studio", id: "main") {
            MainWindowContent(delegate: delegate)
                .environmentObject(store)
                .frame(minWidth: 980, minHeight: 640)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                QuickControlsCommand()
            }
            CommandGroup(replacing: .importExport) {
                Button("Export Settings…") { store.exportConfig() }
                Button("Import Settings…") { store.importConfig() }
            }
        }

        Window("Quick Controls", id: "quick-controls") {
            MenuBarView().environmentObject(store)
        }
        .windowResizability(.contentSize)

        MenuBarExtra(isInserted: $showMenuBarExtra) {
            MenuBarView().environmentObject(store)
        } label: {
            Image(systemName: store.connected ? "keyboard.fill" : "keyboard")
        }
        .menuBarExtraStyle(.window)
    }
}

private struct QuickControlsCommand: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Quick Controls…") { openWindow(id: "quick-controls") }
            .keyboardShortcut("l", modifiers: [.command, .shift])
    }
}

private struct MainWindowContent: View {
    let delegate: AppDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ContentView()
            .onAppear {
                delegate.openMainWindow = { openWindow(id: "main") }
            }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var openMainWindow: (() -> Void)?

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

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { openMainWindow?() }
        return true
    }
}

extension UserDefaults {
    func bool(forKey key: String, default value: Bool) -> Bool {
        object(forKey: key) == nil ? value : bool(forKey: key)
    }
}
