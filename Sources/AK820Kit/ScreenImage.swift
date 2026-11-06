import CoreGraphics
import Foundation
import ImageIO

/// Frames for the 128×128 screen: center-cropped, RGB565 little-endian.
public struct ScreenImage {
    public static let side = 128
    public static let headerSize = 256
    public static let blockSize = 4096
    public static let maxFrames = 140

    public struct Frame {
        public let image: CGImage      // 128×128 preview
        public let delayMs: Int
    }

    public let frames: [Frame]
    public let truncated: Bool

    public init(frames: [Frame], truncated: Bool = false) {
        self.frames = frames
        self.truncated = truncated
    }

    public init(url: URL) throws {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw AK820Error.invalid("Не удалось открыть изображение")
        }
        let count = CGImageSourceGetCount(src)
        guard count > 0 else { throw AK820Error.invalid("В файле нет изображений") }
        var frames: [Frame] = []
        for i in 0..<min(count, ScreenImage.maxFrames) {
            guard let img = CGImageSourceCreateImageAtIndex(src, i, nil) else { continue }
            let delay = count > 1 ? ScreenImage.delay(src, i) : 0
            frames.append(Frame(image: try ScreenImage.fit(img), delayMs: delay))
        }
        self.init(frames: frames, truncated: count > ScreenImage.maxFrames)
    }

    static func delay(_ src: CGImageSource, _ i: Int) -> Int {
        let props = CGImageSourceCopyPropertiesAtIndex(src, i, nil) as? [CFString: Any]
        let dict = (props?[kCGImagePropertyGIFDictionary] ?? props?[kCGImagePropertyPNGDictionary]) as? [CFString: Any]
        let sec = (dict?[kCGImagePropertyGIFUnclampedDelayTime] ?? dict?[kCGImagePropertyGIFDelayTime]
            ?? dict?[kCGImagePropertyAPNGUnclampedDelayTime] ?? dict?[kCGImagePropertyAPNGDelayTime]) as? Double ?? 0.1
        // The official driver allows 30…500 ms per frame.
        return min(max(Int(sec * 1000), 30), 500)
    }

    /// Scales to fill 128×128 and crops the center.
    public static func fit(_ img: CGImage) throws -> CGImage {
        let s = side
        guard let ctx = CGContext(data: nil, width: s, height: s, bitsPerComponent: 8, bytesPerRow: s * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
            throw AK820Error.invalid("CGContext")
        }
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: s, height: s))
        ctx.interpolationQuality = .high
        let scale = max(Double(s) / Double(img.width), Double(s) / Double(img.height))
        let w = Double(img.width) * scale, h = Double(img.height) * scale
        ctx.draw(img, in: CGRect(x: (Double(s) - w) / 2, y: (Double(s) - h) / 2, width: w, height: h))
        guard let out = ctx.makeImage() else { throw AK820Error.invalid("CGContext.makeImage") }
        return out
    }

    static func rgb565(_ img: CGImage) -> [UInt8] {
        let s = side
        var px = [UInt8](repeating: 0, count: s * s * 4)
        px.withUnsafeMutableBytes { buf in
            let ctx = CGContext(data: buf.baseAddress, width: s, height: s, bitsPerComponent: 8, bytesPerRow: s * 4,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
            ctx.draw(img, in: CGRect(x: 0, y: 0, width: s, height: s))
        }
        var out = [UInt8](repeating: 0, count: s * s * 2)
        for i in 0..<(s * s) {
            let r = UInt16(px[i * 4]), g = UInt16(px[i * 4 + 1]), b = UInt16(px[i * 4 + 2])
            let v = (r >> 3) << 11 | (g >> 2) << 5 | (b >> 3)
            out[i * 2] = UInt8(v & 0xFF)
            out[i * 2 + 1] = UInt8(v >> 8)
        }
        return out
    }

    /// Header (`[N, delay/2 ms …]`, 0xFF filled) + frames, padded with 0xFF to 4096-byte blocks.
    public func payload() -> [UInt8] {
        var header = [UInt8](repeating: 0xFF, count: ScreenImage.headerSize)
        header[0] = UInt8(frames.count)
        for (i, f) in frames.enumerated() {
            header[1 + i] = UInt8(clamping: max(1, f.delayMs / 2))
        }
        var data = header
        for f in frames { data += ScreenImage.rgb565(f.image) }
        let blocks = (data.count + ScreenImage.blockSize - 1) / ScreenImage.blockSize
        data += [UInt8](repeating: 0xFF, count: blocks * ScreenImage.blockSize - data.count)
        return data
    }
}
