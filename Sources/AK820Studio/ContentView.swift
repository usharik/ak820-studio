import AK820Kit
import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case lighting = "Lighting"
    case colors = "Key Colors"
    case keymap = "Keys"
    case macros = "Macros"
    case screen = "Screen"
    case settings = "Settings"

    var id: String { rawValue }
    var title: LocalizedStringKey { LocalizedStringKey(rawValue) }

    var icon: String {
        switch self {
        case .lighting: return "sparkles"
        case .colors: return "paintpalette"
        case .keymap: return "keyboard"
        case .macros: return "text.badge.plus"
        case .screen: return "photo"
        case .settings: return "gearshape"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var store: Store
    @State private var section: AppSection?

    init(section: AppSection = .lighting) { _section = State(initialValue: section) }

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $section) { s in
                Label(s.title, systemImage: s.icon).tag(s)
            }
            .navigationSplitViewColumnWidth(190)
            .safeAreaInset(edge: .bottom) { ConnectionBadge().padding(10) }
        } detail: {
            VStack(spacing: 0) {
                Group {
                    switch section ?? .lighting {
                    case .lighting: LightingView()
                    case .colors: ColorsView()
                    case .keymap: KeymapView()
                    case .macros: MacrosView()
                    case .screen: ScreenView()
                    case .settings: SettingsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                Divider()
                StatusBar()
            }
            .navigationTitle(section?.title ?? "")
        }
    }
}

struct ConnectionBadge: View {
    @EnvironmentObject var store: Store

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(store.connected ? Color.green : Color.red).frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 1) {
                Text(store.connected ? "AK820 Pro (USB)" : "Not connected").font(.callout)
                if let b = store.battery { Text("Battery: \(b)%").font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
        }
        .help(store.connected ? "The keyboard is connected by cable" : "Connect the keyboard with a USB-C cable")
    }
}

struct StatusBar: View {
    @EnvironmentObject var store: Store

    var body: some View {
        HStack(spacing: 10) {
            if let busy = store.busy {
                ProgressView().controlSize(.small)
                Text(verbatim: "\(busy)…")
                if let p = store.progress { ProgressView(value: p).frame(width: 160) }
            } else if let s = store.status {
                Image(systemName: s.ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(s.ok ? .green : .orange)
                Text(s.text).lineLimit(2).textSelection(.enabled)
            } else {
                Text(store.connected ? "Ready" : "Connect the keyboard with a USB-C cable — configuration isn't available over Bluetooth or 2.4 GHz")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .font(.callout)
        .padding(.horizontal, 14)
        .frame(height: 34)
    }
}

/// Primary "write to keyboard" button used on every page.
struct WriteButton: View {
    @EnvironmentObject var store: Store
    var title: LocalizedStringKey = "Write to keyboard"
    let action: () -> Void

    var body: some View {
        Button(action: action) { Label(title, systemImage: "square.and.arrow.down") }
            .buttonStyle(.borderedProminent)
            .disabled(store.busy != nil || !store.connected)
    }
}

/// Page scaffold with a header hint.
struct Page<Content: View>: View {
    let hint: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(hint).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                content
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
