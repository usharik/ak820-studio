import AK820Kit
import SwiftUI

/// Draws the AK820 Pro layout. Keys are clickable; with `onPaint`, dragging paints across keys.
struct KeyboardView: View {
    var fill: (KeySpec) -> Color = { _ in Color(nsColor: .controlBackgroundColor) }
    var caption: (KeySpec) -> String? = { _ in nil }
    var selected: Set<Int> = []
    var disabled: (KeySpec) -> Bool = { _ in false }
    /// Lit keys get a glow, like backlighting (for lighting previews).
    var glow = false
    var onTap: ((KeySpec) -> Void)?
    var onPaint: ((KeySpec) -> Void)?
    private let margin = 0.2

    var body: some View {
        GeometryReader { geo in
            let u = geo.size.width / (Layout.width + 2 * margin)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: u * 0.35)
                    .fill(LinearGradient(colors: [Color(white: 0.2), Color(white: 0.12)], startPoint: .top, endPoint: .bottom))
                    .frame(width: geo.size.width, height: u * (Layout.height + 2 * margin))
                ForEach(Layout.keys) { k in
                    KeyCap(spec: k, unit: u, fill: fill(k), caption: caption(k), glow: glow,
                           selected: selected.contains(k.index), disabled: disabled(k))
                        .onTapGesture { if onPaint == nil, !disabled(k) { onTap?(k) } }
                        .offset(x: (k.x + 0.075 + margin) * u, y: (k.y + 0.075 + margin) * u)
                }
            }
            .contentShape(Rectangle())
            .gesture(onPaint == nil ? nil : DragGesture(minimumDistance: 0).onChanged { g in
                if let k = key(at: g.location, unit: u), !disabled(k) { onPaint?(k) }
            })
        }
        .aspectRatio((Layout.width + 2 * margin) / (Layout.height + 2 * margin), contentMode: .fit)
    }

    private func key(at p: CGPoint, unit u: Double) -> KeySpec? {
        let x = p.x / u - margin, y = p.y / u - margin
        return Layout.keys.first { x >= $0.x && x < $0.x + $0.w && y >= $0.y && y < $0.y + $0.h }
    }
}

private struct KeyCap: View {
    let spec: KeySpec
    let unit: Double
    let fill: Color
    let caption: String?
    let glow: Bool
    let selected: Bool
    let disabled: Bool

    var body: some View {
        let w = (spec.w - 0.15) * unit, h = (spec.h - 0.15) * unit
        let light = fill.isLight
        ZStack {
            RoundedRectangle(cornerRadius: unit * 0.16)
                .fill(fill.gradient)
            // Backlit keys: a bright inner rim instead of shadows (cheap to draw, stays inside the case).
            RoundedRectangle(cornerRadius: unit * 0.16)
                .strokeBorder(selected ? Color.accentColor : glow ? Color.white.opacity(0.35) : Color.white.opacity(0.12),
                              lineWidth: selected ? 3 : glow ? 1.5 : 1)
            VStack(spacing: 1) {
                Text(verbatim: spec.label).font(.system(size: unit * 0.25, weight: .medium, design: .rounded))
                if let caption {
                    Text(verbatim: caption).font(.system(size: unit * 0.19, weight: .bold))
                        .lineLimit(2).minimumScaleFactor(0.5)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(2)
            .foregroundStyle(light ? Color.black.opacity(0.8) : Color.white.opacity(0.92))
        }
        .frame(width: w, height: h)
        .opacity(disabled ? 0.35 : 1)
        .contentShape(Rectangle())
    }
}

extension Color {
    var isLight: Bool {
        let c = RGB(self)
        return 0.299 * Double(c.r) + 0.587 * Double(c.g) + 0.114 * Double(c.b) > 140
    }

    /// Unlit key cap.
    static let keyCap = Color(white: 0.27)
}
