import AK820Kit
import SwiftUI
import UniformTypeIdentifiers

struct ScreenView: View {
    @EnvironmentObject var store: Store
    @State private var image: ScreenImage?
    @State private var fileName = ""
    @State private var importing = false
    @State private var error: String?

    var body: some View {
        Page(hint: "Картинка или GIF для экрана 128×128. Изображение обрезается по центру до квадрата. GIF — до 140 кадров.") {
            HStack(alignment: .top, spacing: 24) {
                Preview(image: image)
                    .frame(width: 256, height: 256)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.2)))
                    .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                        _ = providers.first?.loadObject(ofClass: URL.self) { url, _ in
                            if let url { DispatchQueue.main.async { load(url) } }
                        }
                        return true
                    }

                VStack(alignment: .leading, spacing: 12) {
                    Button("Выбрать файл…") { importing = true }
                    if let image {
                        Text(fileName).bold()
                        Text(image.frames.count > 1 ? "Анимация: \(image.frames.count) кадров" : "Статичная картинка")
                        if image.truncated { Text("Взяты первые \(ScreenImage.maxFrames) кадров").foregroundStyle(.orange) }
                        Text("Объём: \(image.payload().count / 1024) КБ").foregroundStyle(.secondary)
                    } else {
                        Text("Перетащите сюда PNG, JPEG или GIF").foregroundStyle(.secondary)
                    }
                    if let error { Text(error).foregroundStyle(.red) }
                    WriteButton(title: "Отправить на экран") { if let image { store.uploadScreen(image) } }
                        .disabled(image == nil)
                    Divider().frame(width: 260)
                    Button("Показать часы и синхронизировать время") { store.syncClock() }
                        .disabled(store.busy != nil || !store.connected)
                    Text("Синхронизация часов переключает экран обратно на часы.").font(.caption).foregroundStyle(.secondary)
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
            image = try ScreenImage(url: url)
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
            TimelineView(.animation) { ctx in
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
