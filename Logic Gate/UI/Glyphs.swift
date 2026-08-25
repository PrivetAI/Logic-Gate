import SwiftUI

// MARK: - Shapes used directly

struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.42
        for i in 0..<10 {
            let r = i % 2 == 0 ? outer : inner
            let a = -CGFloat.pi / 2 + CGFloat(i) * CGFloat.pi / 5
            let pt = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

struct LockShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let bodyRect = CGRect(x: rect.minX + w * 0.14, y: rect.minY + h * 0.45,
                              width: w * 0.72, height: h * 0.48)
        p.addRoundedRect(in: bodyRect, cornerSize: CGSize(width: w * 0.1, height: w * 0.1))
        let shackle = CGRect(x: rect.minX + w * 0.28, y: rect.minY + h * 0.13,
                             width: w * 0.44, height: h * 0.5)
        p.addPath(Path { s in
            s.addArc(center: CGPoint(x: shackle.midX, y: shackle.midY),
                     radius: shackle.width / 2,
                     startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        })
        return p
    }
}

struct ChevronShape: Shape {
    var pointsDown = false
    func path(in rect: CGRect) -> Path {
        var p = Path()
        if pointsDown {
            p.move(to: CGPoint(x: rect.minX + rect.width * 0.16, y: rect.minY + rect.height * 0.34))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.68))
            p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.16, y: rect.minY + rect.height * 0.34))
        } else {
            p.move(to: CGPoint(x: rect.minX + rect.width * 0.34, y: rect.minY + rect.height * 0.16))
            p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.68, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.34, y: rect.maxY - rect.height * 0.16))
        }
        return p
    }
}

// MARK: - Chrome glyph set (all hand drawn, no system icons)

enum BenchGlyph {
    case verify, step, reset, table, timing, hint, undo, trash, gear, chip, book, chart
    case bench, chapters, slots, save, close, pencil, check, cross, clock, plus, wrench
}

struct GlyphView: View {
    let glyph: BenchGlyph
    var color: Color = Bench.text

    var body: some View {
        Canvas { ctx, size in
            let r = CGRect(origin: .zero, size: size).insetBy(dx: size.width * 0.06,
                                                              dy: size.height * 0.06)
            drawGlyph(glyph, &ctx, r, color)
        }
    }
}

func drawGlyph(_ glyph: BenchGlyph, _ ctx: inout GraphicsContext, _ r: CGRect, _ color: Color) {
    let lw = max(1.3, min(r.width, r.height) * 0.11)
    let sh = GraphicsContext.Shading.color(color)

    func stroke(_ p: Path) { ctx.stroke(p, with: sh, lineWidth: lw) }
    func fill(_ p: Path) { ctx.fill(p, with: sh) }

    switch glyph {
    case .verify:
        var p = Path()
        p.move(to: CGPoint(x: r.minX + r.width * 0.22, y: r.minY + r.height * 0.12))
        p.addLine(to: CGPoint(x: r.maxX - r.width * 0.16, y: r.midY))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.22, y: r.maxY - r.height * 0.12))
        p.closeSubpath()
        fill(p)
    case .step:
        var p = Path()
        p.move(to: CGPoint(x: r.minX + r.width * 0.14, y: r.minY + r.height * 0.14))
        p.addLine(to: CGPoint(x: r.midX + r.width * 0.06, y: r.midY))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.14, y: r.maxY - r.height * 0.14))
        p.closeSubpath()
        fill(p)
        var bar = Path()
        bar.addRect(CGRect(x: r.maxX - r.width * 0.22, y: r.minY + r.height * 0.14,
                           width: max(1.5, r.width * 0.14), height: r.height * 0.72))
        fill(bar)
    case .reset:
        var p = Path()
        p.addArc(center: CGPoint(x: r.midX, y: r.midY), radius: min(r.width, r.height) * 0.36,
                 startAngle: .degrees(-40), endAngle: .degrees(250), clockwise: false)
        stroke(p)
        var head = Path()
        let a = CGFloat.pi * -40 / 180
        let c = CGPoint(x: r.midX + cos(a) * min(r.width, r.height) * 0.36,
                        y: r.midY + sin(a) * min(r.width, r.height) * 0.36)
        head.move(to: CGPoint(x: c.x - r.width * 0.02, y: c.y - r.height * 0.2))
        head.addLine(to: CGPoint(x: c.x + r.width * 0.18, y: c.y + r.height * 0.02))
        head.addLine(to: CGPoint(x: c.x - r.width * 0.16, y: c.y + r.height * 0.1))
        head.closeSubpath()
        fill(head)
    case .table:
        var p = Path()
        p.addRoundedRect(in: r.insetBy(dx: r.width * 0.08, dy: r.height * 0.1),
                         cornerSize: CGSize(width: 2, height: 2))
        p.move(to: CGPoint(x: r.minX + r.width * 0.08, y: r.minY + r.height * 0.38))
        p.addLine(to: CGPoint(x: r.maxX - r.width * 0.08, y: r.minY + r.height * 0.38))
        p.move(to: CGPoint(x: r.minX + r.width * 0.08, y: r.minY + r.height * 0.64))
        p.addLine(to: CGPoint(x: r.maxX - r.width * 0.08, y: r.minY + r.height * 0.64))
        p.move(to: CGPoint(x: r.midX, y: r.minY + r.height * 0.1))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY - r.height * 0.1))
        stroke(p)
    case .timing, .clock:
        var p = Path()
        let y0 = r.minY + r.height * 0.28, y1 = r.maxY - r.height * 0.28
        let step = r.width / 6
        p.move(to: CGPoint(x: r.minX, y: y1))
        for i in 0..<3 {
            let x = r.minX + CGFloat(i) * 2 * step
            p.addLine(to: CGPoint(x: x, y: y0))
            p.addLine(to: CGPoint(x: x + step, y: y0))
            p.addLine(to: CGPoint(x: x + step, y: y1))
            p.addLine(to: CGPoint(x: x + 2 * step, y: y1))
        }
        stroke(p)
    case .hint:
        var bulb = Path()
        bulb.addEllipse(in: CGRect(x: r.minX + r.width * 0.22, y: r.minY + r.height * 0.08,
                                   width: r.width * 0.56, height: r.height * 0.56))
        stroke(bulb)
        var stem = Path()
        stem.move(to: CGPoint(x: r.minX + r.width * 0.38, y: r.maxY - r.height * 0.24))
        stem.addLine(to: CGPoint(x: r.maxX - r.width * 0.38, y: r.maxY - r.height * 0.24))
        stem.move(to: CGPoint(x: r.minX + r.width * 0.42, y: r.maxY - r.height * 0.08))
        stem.addLine(to: CGPoint(x: r.maxX - r.width * 0.42, y: r.maxY - r.height * 0.08))
        stroke(stem)
    case .undo:
        var p = Path()
        p.addArc(center: CGPoint(x: r.midX, y: r.midY + r.height * 0.06),
                 radius: min(r.width, r.height) * 0.32,
                 startAngle: .degrees(200), endAngle: .degrees(-20), clockwise: false)
        stroke(p)
        var head = Path()
        head.move(to: CGPoint(x: r.minX + r.width * 0.06, y: r.minY + r.height * 0.12))
        head.addLine(to: CGPoint(x: r.minX + r.width * 0.34, y: r.minY + r.height * 0.30))
        head.addLine(to: CGPoint(x: r.minX + r.width * 0.06, y: r.minY + r.height * 0.46))
        head.closeSubpath()
        fill(head)
    case .trash:
        var p = Path()
        p.addRoundedRect(in: CGRect(x: r.minX + r.width * 0.2, y: r.minY + r.height * 0.28,
                                    width: r.width * 0.6, height: r.height * 0.62),
                         cornerSize: CGSize(width: 2, height: 2))
        p.move(to: CGPoint(x: r.minX + r.width * 0.1, y: r.minY + r.height * 0.24))
        p.addLine(to: CGPoint(x: r.maxX - r.width * 0.1, y: r.minY + r.height * 0.24))
        p.move(to: CGPoint(x: r.minX + r.width * 0.36, y: r.minY + r.height * 0.1))
        p.addLine(to: CGPoint(x: r.maxX - r.width * 0.36, y: r.minY + r.height * 0.1))
        stroke(p)
    case .gear:
        let cx = r.midX, cy = r.midY
        let outer = min(r.width, r.height) * 0.44
        let inner = outer * 0.72
        var p = Path()
        for i in 0..<16 {
            let a = CGFloat(i) * CGFloat.pi / 8
            let rad = i % 2 == 0 ? outer : inner
            let pt = CGPoint(x: cx + cos(a) * rad, y: cy + sin(a) * rad)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        stroke(p)
        var hole = Path()
        hole.addEllipse(in: CGRect(x: cx - outer * 0.3, y: cy - outer * 0.3,
                                   width: outer * 0.6, height: outer * 0.6))
        stroke(hole)
    case .chip:
        var p = Path()
        p.addRoundedRect(in: CGRect(x: r.minX + r.width * 0.2, y: r.minY + r.height * 0.2,
                                    width: r.width * 0.6, height: r.height * 0.6),
                         cornerSize: CGSize(width: 2, height: 2))
        stroke(p)
        var legs = Path()
        for i in 0..<3 {
            let y = r.minY + r.height * (0.3 + 0.2 * CGFloat(i))
            legs.move(to: CGPoint(x: r.minX + r.width * 0.04, y: y))
            legs.addLine(to: CGPoint(x: r.minX + r.width * 0.2, y: y))
            legs.move(to: CGPoint(x: r.maxX - r.width * 0.2, y: y))
            legs.addLine(to: CGPoint(x: r.maxX - r.width * 0.04, y: y))
        }
        stroke(legs)
    case .book:
        var p = Path()
        p.move(to: CGPoint(x: r.minX + r.width * 0.14, y: r.minY + r.height * 0.14))
        p.addLine(to: CGPoint(x: r.midX, y: r.minY + r.height * 0.26))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY - r.height * 0.1))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.14, y: r.maxY - r.height * 0.22))
        p.closeSubpath()
        p.move(to: CGPoint(x: r.maxX - r.width * 0.14, y: r.minY + r.height * 0.14))
        p.addLine(to: CGPoint(x: r.midX, y: r.minY + r.height * 0.26))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY - r.height * 0.1))
        p.addLine(to: CGPoint(x: r.maxX - r.width * 0.14, y: r.maxY - r.height * 0.22))
        p.closeSubpath()
        stroke(p)
    case .chart:
        var p = Path()
        let base = r.maxY - r.height * 0.12
        let heights: [CGFloat] = [0.42, 0.68, 0.3, 0.8]
        for (i, h) in heights.enumerated() {
            let w = r.width * 0.16
            let x = r.minX + r.width * 0.1 + CGFloat(i) * (r.width * 0.22)
            p.addRect(CGRect(x: x, y: base - r.height * h, width: w, height: r.height * h))
        }
        fill(p)
    case .bench:
        var p = Path()
        p.addRoundedRect(in: CGRect(x: r.minX + r.width * 0.08, y: r.minY + r.height * 0.2,
                                    width: r.width * 0.84, height: r.height * 0.6),
                         cornerSize: CGSize(width: 2, height: 2))
        stroke(p)
        var inner = Path()
        inner.move(to: CGPoint(x: r.minX + r.width * 0.24, y: r.midY))
        inner.addLine(to: CGPoint(x: r.midX, y: r.midY))
        inner.addLine(to: CGPoint(x: r.midX, y: r.minY + r.height * 0.34))
        inner.addLine(to: CGPoint(x: r.maxX - r.width * 0.22, y: r.minY + r.height * 0.34))
        stroke(inner)
    case .chapters:
        var p = Path()
        for i in 0..<3 {
            let y = r.minY + r.height * (0.18 + 0.28 * CGFloat(i))
            p.addRoundedRect(in: CGRect(x: r.minX + r.width * 0.1, y: y,
                                        width: r.width * 0.8, height: r.height * 0.16),
                             cornerSize: CGSize(width: 1.5, height: 1.5))
        }
        fill(p)
    case .slots:
        var p = Path()
        for i in 0..<2 {
            for j in 0..<2 {
                p.addRoundedRect(in: CGRect(x: r.minX + r.width * (0.1 + 0.46 * CGFloat(j)),
                                            y: r.minY + r.height * (0.1 + 0.46 * CGFloat(i)),
                                            width: r.width * 0.34, height: r.height * 0.34),
                                 cornerSize: CGSize(width: 1.5, height: 1.5))
            }
        }
        stroke(p)
    case .save:
        var p = Path()
        p.addRoundedRect(in: r.insetBy(dx: r.width * 0.1, dy: r.height * 0.1),
                         cornerSize: CGSize(width: 2, height: 2))
        stroke(p)
        var tab = Path()
        tab.addRect(CGRect(x: r.minX + r.width * 0.3, y: r.minY + r.height * 0.1,
                           width: r.width * 0.4, height: r.height * 0.28))
        fill(tab)
    case .close, .cross:
        var p = Path()
        p.move(to: CGPoint(x: r.minX + r.width * 0.2, y: r.minY + r.height * 0.2))
        p.addLine(to: CGPoint(x: r.maxX - r.width * 0.2, y: r.maxY - r.height * 0.2))
        p.move(to: CGPoint(x: r.maxX - r.width * 0.2, y: r.minY + r.height * 0.2))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.2, y: r.maxY - r.height * 0.2))
        stroke(p)
    case .pencil:
        var p = Path()
        p.move(to: CGPoint(x: r.minX + r.width * 0.16, y: r.maxY - r.height * 0.16))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.28, y: r.maxY - r.height * 0.32))
        p.addLine(to: CGPoint(x: r.maxX - r.width * 0.18, y: r.minY + r.height * 0.16))
        p.addLine(to: CGPoint(x: r.maxX - r.width * 0.04, y: r.minY + r.height * 0.3))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.32, y: r.maxY - r.height * 0.2))
        p.closeSubpath()
        stroke(p)
    case .check:
        var p = Path()
        p.move(to: CGPoint(x: r.minX + r.width * 0.16, y: r.midY))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.42, y: r.maxY - r.height * 0.22))
        p.addLine(to: CGPoint(x: r.maxX - r.width * 0.14, y: r.minY + r.height * 0.2))
        stroke(p)
    case .plus:
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY + r.height * 0.16))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY - r.height * 0.16))
        p.move(to: CGPoint(x: r.minX + r.width * 0.16, y: r.midY))
        p.addLine(to: CGPoint(x: r.maxX - r.width * 0.16, y: r.midY))
        stroke(p)
    case .wrench:
        var p = Path()
        p.move(to: CGPoint(x: r.minX + r.width * 0.16, y: r.maxY - r.height * 0.16))
        p.addLine(to: CGPoint(x: r.midX + r.width * 0.1, y: r.midY - r.height * 0.1))
        stroke(p)
        var head = Path()
        head.addArc(center: CGPoint(x: r.maxX - r.width * 0.28, y: r.minY + r.height * 0.3),
                    radius: min(r.width, r.height) * 0.22,
                    startAngle: .degrees(40), endAngle: .degrees(320), clockwise: false)
        stroke(head)
    }
}
