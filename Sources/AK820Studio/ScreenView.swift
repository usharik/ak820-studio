import AK820Kit
import SwiftUI
import UniformTypeIdentifiers

struct ScreenView: View {
    @EnvironmentObject var store: Store
    @State private var image: ScreenImage?
    @State private var fileName = ""
    @State private var importing = false
    @State private var error: String?

    @State private var payloadKB = 0
    @State private var dropTargeted = false

    var body: some View {
        Page(hint: "An image or GIF for the 128×128 screen. The image is center-cropped to a square. GIFs: up to 140 frames.") {
            WiredOnlyNote()
            HStack(alignment: .top, spacing: 24) {
                Preview(image: image)
                    .frame(width: 256, height: 256)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18)
                        .stroke(dropTargeted ? Color.accentColor : Color.primary.opacity(0.2), lineWidth: dropTargeted ? 3 : 1))
                    .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
                    .onTapGesture { importing = true }
                    .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
                        _ = providers.first?.loadObject(ofClass: URL.self) { url, _ in
                            if let url { DispatchQueue.main.async { load(url) } }
                        }
                        return true
                    }

                VStack(alignment: .leading, spacing: 14) {
                    if let image {
                        Text(verbatim: fileName).font(.headline).lineLimit(1)
                        Group {
                            if image.frames.count > 1 { Text("Animation, frames: \(image.frames.count)") } else { Text("Still image") }
                            if image.truncated { Text("Only the first \(ScreenImage.maxFrames) frames are used").foregroundStyle(.orange) }
                            Text("Size: \(payloadKB) KB")
                        }
                        .foregroundStyle(.secondary)
                    } else {
                        Text("Drop a PNG, JPEG or GIF here").foregroundStyle(.secondary)
                    }
                    Button("Choose File…") { importing = true }
                    if let error { Text(verbatim: error).foregroundStyle(.red) }

                    Picker("Slot", selection: $store.config.screenSlot) {
                        Text(verbatim: "1").tag(1); Text(verbatim: "2").tag(2); Text(verbatim: "3").tag(3)
                    }
                    .pickerStyle(.segmented).frame(width: 220)
                    Text("The keyboard keeps up to three animations; which one is shown is chosen on the keyboard itself (see its manual).")
                        .font(.caption).foregroundStyle(.secondary).frame(maxWidth: 360, alignment: .leading)

                    Button { if let image { store.uploadScreen(image) } } label: {
                        Label("Send to screen", systemImage: "arrow.up.forward.app")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(image == nil || store.busy != nil || !store.wired)

                    Divider().frame(width: 300)
                    Button { store.syncClock() } label: { Label("Show clock and sync time", systemImage: "clock") }
                        .disabled(store.busy != nil || !store.connected)
                    Text("Syncing the clock switches the screen back to the clock.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.image]) { r in
            if case let .success(url) = r { load(url) }
        }
    }

    private func load(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let img = try ScreenImage(url: url)
            image = img
            payloadKB = img.payload().count / 1024
            fileName = url.lastPathComponent
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct Preview: View {
    let image: ScreenImage?

    var body: some View {
        if let image, !image.frames.isEmpty {
            TimelineView(.animation(paused: image.frames.count <= 1)) { ctx in
                let frame = currentFrame(image, at: ctx.date)
                Image(decorative: frame.image, scale: 1).interpolation(.none).resizable()
            }
        } else {
            Image(systemName: "photo").font(.system(size: 48)).foregroundStyle(.gray)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func currentFrame(_ img: ScreenImage, at date: Date) -> ScreenImage.Frame {
        guard img.frames.count > 1 else { return img.frames[0] }
        let total = img.frames.reduce(0) { $0 + $1.delayMs }
        var t = Int(date.timeIntervalSinceReferenceDate * 1000) % max(total, 1)
        for f in img.frames {
            if t < f.delayMs { return f }
            t -= f.delayMs
        }
        return img.frames[0]
    }
}
