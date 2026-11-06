import AK820Kit
import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case lighting = "Подсветка"
    case colors = "Цвета клавиш"
    case keymap = "Клавиши"
    case macros = "Макросы"
    case screen = "Экран"
    case settings = "Настройки"

    var id: String { rawValue }

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
                Label(s.rawValue, systemImage: s.icon).tag(s)
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
            .navigationTitle(section?.rawValue ?? "")
        }
    }
}

struct ConnectionBadge: View {
    @EnvironmentObject var store: Store

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(store.connected ? Color.green : Color.red).frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 1) {
                Text(store.connected ? "AK820 Pro (USB)" : "Не подключена").font(.callout)
                if let b = store.battery { Text("Батарея: \(b) %").font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
        }
        .help(store.connected ? "Клавиатура подключена кабелем" : "Подключите клавиатуру кабелем USB-C")
    }
}

struct StatusBar: View {
    @EnvironmentObject var store: Store

    var body: some View {
        HStack(spacing: 10) {
            if let busy = store.busy {
                ProgressView().controlSize(.small)
                Text("\(busy)…")
                if let p = store.progress { ProgressView(value: p).frame(width: 160) }
            } else if let s = store.status {
                Image(systemName: s.ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(s.ok ? .green : .orange)
                Text(s.text).lineLimit(2).textSelection(.enabled)
            } else {
                Text(store.connected ? "Готово к работе" : "Подключите клавиатуру кабелем USB-C — по Bluetooth и 2.4G настройка недоступна")
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
    var title = "Записать в клавиатуру"
    let action: () -> Void

    var body: some View {
        Button(action: action) { Label(title, systemImage: "square.and.arrow.down") }
            .buttonStyle(.borderedProminent)
            .disabled(store.busy != nil || !store.connected)
    }
}

/// Page scaffold with a header hint.
struct Page<Content: View>: View {
    let hint: String
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
