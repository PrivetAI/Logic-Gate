import SwiftUI

/// Engineering-blueprint palette. Every colour is fixed so the app looks identical whatever
/// the device theme is set to.
enum Bench {
    static func hex(_ v: UInt32) -> Color {
        Color(.sRGB,
              red: Double((v >> 16) & 0xFF) / 255.0,
              green: Double((v >> 8) & 0xFF) / 255.0,
              blue: Double(v & 0xFF) / 255.0,
              opacity: 1.0)
    }

    static let background = hex(0x0C1116)
    static let board = hex(0x121A21)
    static let grid = hex(0x1C2833)
    static let surface = hex(0x16202A)
    static let surfaceHigh = hex(0x1E2B37)
    static let stroke = hex(0x2A3946)
    static let copper = hex(0xD98A3B)
    static let high = hex(0xF5C542)
    static let low = hex(0x3A4A5B)
    static let wireLow = hex(0x3A4A63)
    static let good = hex(0x3DD68C)
    static let bad = hex(0xE2506A)
    static let osc = hex(0xFF4D5E)
    static let text = hex(0xE8EDF2)
    static let textDim = hex(0x93A6B8)
    static let textFaint = hex(0x5E7387)

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func label(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

/// Screen scaffold shared by every tab: fixed dark ground, a title strip that always sits
/// below the status bar, and a scroll area with enough bottom padding to clear the tab bar.
struct BenchScaffold<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var trailing: AnyView? = nil
    let content: Content

    init(title: String, subtitle: String? = nil, trailing: AnyView? = nil,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Bench.label(21, .bold))
                        .foregroundColor(Bench.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if let s = subtitle {
                        Text(s)
                            .font(Bench.label(12, .regular))
                            .foregroundColor(Bench.textDim)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                if let t = trailing { t }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 12)

            Rectangle()
                .fill(Bench.stroke)
                .frame(height: 1)

            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Bench.background.ignoresSafeArea())
    }
}

/// Clamps to the real screen width so iPad compatibility mode cannot report a width wider
/// than what is actually visible and push content off the right edge.
func benchUsableWidth(_ proposed: CGFloat) -> CGFloat {
    min(proposed, UIScreen.main.bounds.width)
}

struct BenchCard<Content: View>: View {
    var padding: CGFloat = 14
    let content: Content
    init(padding: CGFloat = 14, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }
    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Bench.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Bench.stroke, lineWidth: 1)
                    )
            )
    }
}

/// Flat action button with a custom-drawn glyph and no system chrome.
struct BenchButton: View {
    let title: String
    var glyph: BenchGlyph? = nil
    var tint: Color = Bench.copper
    var filled: Bool = false
    var compact: Bool = false
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: { if enabled { action() } }) {
            HStack(spacing: 6) {
                if let g = glyph {
                    GlyphView(glyph: g, color: filled ? Bench.background : tint)
                        .frame(width: compact ? 13 : 15, height: compact ? 13 : 15)
                }
                Text(title)
                    .font(Bench.label(compact ? 12 : 13, .semibold))
                    .foregroundColor(filled ? Bench.background : tint)
                    .lineLimit(1)
            }
            .padding(.horizontal, compact ? 10 : 14)
            .padding(.vertical, compact ? 7 : 10)
            .frame(minHeight: compact ? 30 : 38)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(filled ? tint : Bench.surfaceHigh)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(filled ? Color.clear : tint.opacity(0.45), lineWidth: 1)
                    )
            )
            .opacity(enabled ? 1.0 : 0.35)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct StarRow: View {
    let filled: Int
    var size: CGFloat = 12
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                StarShape()
                    .fill(i < filled ? Bench.high : Bench.textFaint.opacity(0.35))
                    .frame(width: size, height: size)
            }
        }
    }
}
