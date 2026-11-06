import AppKit
import SwiftUI

@main
struct AK820StudioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup("AK820 Studio") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 980, minHeight: 640)
        }
        .commands {
            CommandGroup(replacing: .importExport) {
                Button("Экспорт настроек…") { store.exportConfig() }
                Button("Импорт настроек…") { store.importConfig() }
            }
        }
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

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
