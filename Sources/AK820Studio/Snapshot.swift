import AppKit
import SwiftUI

/// Debug aid: `AK820_SNAPSHOT=/tmp/dir AK820Studio` renders every page to PNG offscreen.
@MainActor
enum Snapshot {
    static func renderAll(to dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = Store()
        for (i, s) in AppSection.allCases.enumerated() {
            let view = ContentView(section: s).environmentObject(store).frame(width: 1180, height: 820)
            let host = NSHostingView(rootView: view)
            host.frame = NSRect(x: 0, y: 0, width: 1180, height: 820)
            let window = NSWindow(contentRect: host.frame, styleMask: [.titled], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: .aqua)
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.6))
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { continue }
            host.cacheDisplay(in: host.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent("\(i)-\(s).png"))
        }
    }
}
