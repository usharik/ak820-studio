import AK820Kit
import SwiftUI

extension LiveMode {
    var title: LocalizedStringKey {
        switch self {
        case .music: return "Music"
        case .system: return "System monitor"
        }
    }

    /// For narrow places such as the menu bar.
    var shortTitle: LocalizedStringKey {
        switch self {
        case .music: return "Music"
        case .system: return "CPU & memory"
        }
    }

    var subtitle: LocalizedStringKey {
        switch self {
        case .music: return "The keys become an equalizer for whatever your Mac plays."
        case .system: return "F1–F12 show CPU load, the number row shows memory use."
        }
    }

    var icon: String {
        switch self {
        case .music: return "music.note"
        case .system: return "cpu"
        }
    }
}

extension MusicStyle {
    var title: LocalizedStringKey {
        switch self {
        case .meter: return "Green–yellow–red"
        case .rainbow: return "Rainbow"
        case .gradient: return "Gradient"
        case .cycle: return "Color cycle"
        case .single: return "One color"
        }
    }
}

struct LiveView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        Page(hint: "Real-time lighting driven by this Mac. Nothing is stored: when it stops, the keyboard returns to its own effect.") {
            HStack(spacing: 12) {
                ForEach(LiveMode.allCases) { m in ModeCard(mode: m) }
            }
            .frame(maxWidth: 820)

            KeyboardView(fill: { k in store.liveFrame[k.index].map { $0 == .black ? Color.keyCap : $0.color } ?? .keyCap },
                         glow: store.liveMode != nil)
                .frame(maxWidth: 820)
                .opacity(store.liveMode == nil ? 0.6 : 1)

            Card(title: "Music colors") {
                Picker("Style", selection: $store.config.live.style) {
                    ForEach(MusicStyle.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                if store.config.live.style == .single {
                    ColorPicker("Color", selection: Binding(get: { store.config.live.color.color },
                                                            set: { store.config.live.color = RGB($0) }), supportsOpacity: false)
                        .fixedSize()
                }
                Text("Style changes apply the next time live lighting starts.").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: 820)

            VStack(alignment: .leading, spacing: 4) {
                Text("Music mode asks for permission to record system audio (only audio, not the screen). If the keys stay dark while music plays, allow AK820 Studio in System Settings → Privacy & Security → Screen & System Audio Recording.")
                Text("Over the 2.4 GHz receiver the keyboard draws the music spectrum itself; the system monitor needs the cable.")
            }
            .font(.caption).foregroundStyle(.secondary).frame(maxWidth: 820, alignment: .leading)
        }
    }
}

private struct ModeCard: View {
    @EnvironmentObject var store: Store
    let mode: LiveMode

    private var running: Bool { store.liveMode == mode }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: mode.icon)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(Circle().fill(running ? Color.green.opacity(0.2) : Color.accentColor.opacity(0.12)))
                .foregroundStyle(running ? .green : .accentColor)
            VStack(alignment: .leading, spacing: 6) {
                Text(mode.title).font(.headline)
                Text(mode.subtitle).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Button {
                    running ? store.stopLive() : store.startLive(mode)
                } label: {
                    Label(running ? "Stop" : "Start", systemImage: running ? "stop.fill" : "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(running ? .red : .accentColor)
                .disabled(!store.connected || store.busy != nil)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(running ? Color.green : Color.primary.opacity(0.07), lineWidth: running ? 2 : 1))
    }
}
