import AK820Kit
import SwiftUI

/// Draws the AK820 Pro layout; each key is clickable.
struct KeyboardView: View {
    var fill: (KeySpec) -> Color = { _ in Color(nsColor: .controlBackgroundColor) }
    var caption: (KeySpec) -> String? = { _ in nil }
    var selected: Set<Int> = []
    var disabled: (KeySpec) -> Bool = { _ in false }
    var onTap: (KeySpec) -> Void = { _ in }
    private let margin = 0.2

    var body: some View {
        GeometryReader { geo in
            let u = geo.size.width / (Layout.width + 2 * margin)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: u * 0.3)
                    .fill(Color(nsColor: .underPageBackgroundColor))
                    .frame(width: geo.size.width, height: u * (Layout.height + 2 * margin))
                ForEach(Layout.keys) { k in
                    KeyCap(spec: k, unit: u, fill: fill(k), caption: caption(k),
                           selected: selected.contains(k.index), disabled: disabled(k))
                        .onTapGesture { if !disabled(k) { onTap(k) } }
                        .offset(x: (k.x + 0.075 + margin) * u, y: (k.y + 0.075 + margin) * u)
                }
            }
        }
        .aspectRatio((Layout.width + 2 * margin) / (Layout.height + 2 * margin), contentMode: .fit)
    }
}

private struct KeyCap: View {
    let spec: KeySpec
    let unit: Double
    let fill: Color
    let caption: String?
    let selected: Bool
    let disabled: Bool

    var body: some View {
        let w = (spec.w - 0.15) * unit, h = (spec.h - 0.15) * unit
        ZStack {
            RoundedRectangle(cornerRadius: unit * 0.14)
                .fill(fill)
            RoundedRectangle(cornerRadius: unit * 0.14)
                .strokeBorder(selected ? Color.accentColor : Color.primary.opacity(0.18), lineWidth: selected ? 3 : 1)
            VStack(spacing: 1) {
                Text(spec.label).font(.system(size: unit * 0.26, weight: .medium))
                if let caption {
                    Text(caption).font(.system(size: unit * 0.2, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                        .lineLimit(2).minimumScaleFactor(0.5)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(2)
            .foregroundStyle(fill.isLight ? Color.black : Color.white)
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
}
