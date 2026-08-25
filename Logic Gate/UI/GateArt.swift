import SwiftUI

/// Board <-> screen transform. Every measurement comes from the size handed in by the PARENT
/// GeometryReader, never from a Canvas closure's own `size` argument.
struct BoardGeometry {
    let cols: Int
    let rows: Int
    let size: CGSize
    let cell: CGFloat
    let origin: CGPoint

    init(cols: Int, rows: Int, size: CGSize) {
        self.cols = max(cols, 2)
        self.rows = max(rows, 2)
        self.size = size
        let c = min(size.width / CGFloat(self.cols), size.height / CGFloat(self.rows))
        self.cell = max(c, 6)
        self.origin = CGPoint(x: (size.width - self.cell * CGFloat(self.cols)) / 2,
                              y: (size.height - self.cell * CGFloat(self.rows)) / 2)
    }

    func point(_ gx: Double, _ gy: Double) -> CGPoint {
        CGPoint(x: origin.x + CGFloat(gx) * cell, y: origin.y + CGFloat(gy) * cell)
    }

    func gridX(_ x: CGFloat) -> Double { Double((x - origin.x) / cell) }
    func gridY(_ y: CGFloat) -> Double { Double((y - origin.y) / cell) }

    var boardRect: CGRect {
        CGRect(x: origin.x, y: origin.y, width: cell * CGFloat(cols), height: cell * CGFloat(rows))
    }
}

enum GateArt {

    /// Part footprint in grid cells.
    static func partSize(_ kind: PartKind, pinsIn: Int, pinsOut: Int) -> CGSize {
        switch kind {
        case .junction:
            return CGSize(width: 0.7, height: 0.7)
        case .inputSwitch:
            return CGSize(width: 1.7, height: 1.0)
        case .outputLamp:
            return CGSize(width: 1.2, height: 1.2)
        case .const0, .const1:
            return CGSize(width: 1.0, height: 1.0)
        case .clock:
            return CGSize(width: 1.7, height: 1.0)
        case .sevenSegment:
            return CGSize(width: 2.4, height: 5.2)
        case .busProbe:
            return CGSize(width: 2.0, height: 3.4)
        case .chip:
            let n = max(pinsIn, pinsOut, 1)
            return CGSize(width: 2.8, height: max(1.6, Double(n - 1) * 0.7 + 1.1))
        default:
            let n = max(pinsIn, pinsOut, 1)
            return CGSize(width: 2.1, height: max(1.4, Double(n - 1) * 0.7 + 1.0))
        }
    }

    static func rect(for part: CircuitPart, pinsIn: Int, pinsOut: Int,
                     geo: BoardGeometry) -> CGRect {
        let s = partSize(part.kind, pinsIn: pinsIn, pinsOut: pinsOut)
        let c = geo.point(part.gx, part.gy)
        return CGRect(x: c.x - CGFloat(s.width) * geo.cell / 2,
                      y: c.y - CGFloat(s.height) * geo.cell / 2,
                      width: CGFloat(s.width) * geo.cell,
                      height: CGFloat(s.height) * geo.cell)
    }

    static func pinPoint(rect: CGRect, index: Int, count: Int, isOutput: Bool) -> CGPoint {
        guard count > 0 else { return CGPoint(x: rect.midX, y: rect.midY) }
        let x = isOutput ? rect.maxX : rect.minX
        if count == 1 { return CGPoint(x: x, y: rect.midY) }
        let usable = rect.height * 0.82
        let top = rect.midY - usable / 2
        let step = usable / CGFloat(count - 1)
        return CGPoint(x: x, y: top + step * CGFloat(index))
    }

    // MARK: - Body paths

    static func andBody(_ r: CGRect) -> Path {
        var p = Path()
        let rad = r.height / 2
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: max(r.minX, r.maxX - rad), y: r.minY))
        p.addArc(center: CGPoint(x: max(r.minX, r.maxX - rad), y: r.midY), radius: rad,
                 startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }

    static func orBody(_ r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.midY),
                       control: CGPoint(x: r.minX + r.width * 0.62, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY),
                       control: CGPoint(x: r.minX + r.width * 0.62, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.minY),
                       control: CGPoint(x: r.minX + r.width * 0.3, y: r.midY))
        p.closeSubpath()
        return p
    }

    static func xorTail(_ r: CGRect) -> Path {
        var p = Path()
        let dx = r.width * 0.13
        p.move(to: CGPoint(x: r.minX - dx, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.minX - dx, y: r.maxY),
                       control: CGPoint(x: r.minX + r.width * 0.3 - dx, y: r.midY))
        return p
    }

    static func triangleBody(_ r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }

    static func dipBody(_ r: CGRect) -> Path {
        var p = Path()
        p.addRoundedRect(in: r, cornerSize: CGSize(width: r.width * 0.07, height: r.width * 0.07))
        return p
    }

    // MARK: - Full part rendering

    struct RenderStyle {
        var body = Bench.surfaceHigh
        var outline = Bench.copper
        var label = Bench.text
        var lineWidth: CGFloat = 1.6
        var selected = false
        var dimmed = false
    }

    static func draw(part: CircuitPart, chip: ChipDefinition?, rect r: CGRect,
                     inValues: [Bool], outValues: [Bool],
                     showPinLabels: Bool, style: RenderStyle,
                     terminalLabel: String? = nil,
                     ctx: inout GraphicsContext) {
        let kind = part.kind
        let outline = style.selected ? Bench.high : style.outline
        let lw = style.lineWidth
        let bodyShade = GraphicsContext.Shading.color(style.body)
        let lineShade = GraphicsContext.Shading.color(outline)

        func label(_ s: String, at p: CGPoint, size: CGFloat, color: Color = Bench.text) {
            ctx.draw(Text(s).font(Bench.mono(size, .bold)).foregroundColor(color),
                     at: p, anchor: .center)
        }

        switch kind {
        case .and, .nand, .and3:
            let bodyRect = bubbleAdjusted(r, hasBubble: kind == .nand)
            let path = andBody(bodyRect)
            ctx.fill(path, with: bodyShade)
            ctx.stroke(path, with: lineShade, lineWidth: lw)
            if kind == .nand { drawBubble(bodyRect, ctx: &ctx, color: outline, lw: lw) }
            label(kind == .and3 ? "&3" : "&",
                  at: CGPoint(x: bodyRect.minX + bodyRect.width * 0.36, y: bodyRect.midY),
                  size: min(bodyRect.height * 0.4, 13))
        case .or, .nor, .xor, .xnor:
            let bodyRect = bubbleAdjusted(r, hasBubble: kind == .nor || kind == .xnor)
            let path = orBody(bodyRect)
            ctx.fill(path, with: bodyShade)
            ctx.stroke(path, with: lineShade, lineWidth: lw)
            if kind == .xor || kind == .xnor {
                ctx.stroke(xorTail(bodyRect), with: lineShade, lineWidth: lw)
            }
            if kind == .nor || kind == .xnor { drawBubble(bodyRect, ctx: &ctx, color: outline, lw: lw) }
            label(kind == .xor || kind == .xnor ? "=1" : "\u{2265}1",
                  at: CGPoint(x: bodyRect.minX + bodyRect.width * 0.42, y: bodyRect.midY),
                  size: min(bodyRect.height * 0.36, 12))
        case .not, .buffer:
            let bodyRect = bubbleAdjusted(r, hasBubble: kind == .not)
            let path = triangleBody(bodyRect)
            ctx.fill(path, with: bodyShade)
            ctx.stroke(path, with: lineShade, lineWidth: lw)
            if kind == .not { drawBubble(bodyRect, ctx: &ctx, color: outline, lw: lw) }
        case .junction:
            var dot = Path()
            dot.addEllipse(in: r)
            ctx.fill(dot, with: .color(outValues.first == true ? Bench.high : Bench.wireLow))
            ctx.stroke(dot, with: lineShade, lineWidth: max(1, lw * 0.7))
        case .inputSwitch:
            let on = outValues.first ?? false
            var body = Path()
            body.addRoundedRect(in: r, cornerSize: CGSize(width: r.height / 2, height: r.height / 2))
            ctx.fill(body, with: .color(on ? Bench.copper.opacity(0.45) : Bench.surfaceHigh))
            ctx.stroke(body, with: .color(on ? Bench.high : Bench.stroke), lineWidth: lw)
            var knob = Path()
            let kd = r.height * 0.66
            knob.addEllipse(in: CGRect(x: on ? r.maxX - kd - r.height * 0.17 : r.minX + r.height * 0.17,
                                       y: r.midY - kd / 2, width: kd, height: kd))
            ctx.fill(knob, with: .color(on ? Bench.high : Bench.textFaint))
        case .outputLamp:
            let on = inValues.first ?? false
            var body = Path()
            body.addEllipse(in: r)
            ctx.fill(body, with: .color(on ? Bench.high : Bench.surfaceHigh))
            ctx.stroke(body, with: .color(on ? Bench.high : Bench.stroke), lineWidth: lw)
            if on {
                var rays = Path()
                for i in 0..<8 {
                    let a = CGFloat(i) * CGFloat.pi / 4
                    let c = CGPoint(x: r.midX, y: r.midY)
                    rays.move(to: CGPoint(x: c.x + cos(a) * r.width * 0.62,
                                          y: c.y + sin(a) * r.width * 0.62))
                    rays.addLine(to: CGPoint(x: c.x + cos(a) * r.width * 0.82,
                                             y: c.y + sin(a) * r.width * 0.82))
                }
                ctx.stroke(rays, with: .color(Bench.high.opacity(0.7)), lineWidth: max(1, lw * 0.8))
            }
        case .const0, .const1:
            var body = Path()
            body.addRoundedRect(in: r, cornerSize: CGSize(width: 3, height: 3))
            ctx.fill(body, with: bodyShade)
            ctx.stroke(body, with: lineShade, lineWidth: lw)
            label(kind == .const1 ? "1" : "0", at: CGPoint(x: r.midX, y: r.midY),
                  size: min(r.height * 0.62, 15),
                  color: kind == .const1 ? Bench.high : Bench.textDim)
        case .clock:
            var body = Path()
            body.addRoundedRect(in: r, cornerSize: CGSize(width: 3, height: 3))
            ctx.fill(body, with: bodyShade)
            ctx.stroke(body, with: lineShade, lineWidth: lw)
            var wave = Path()
            let y0 = r.minY + r.height * 0.3, y1 = r.maxY - r.height * 0.3
            let st = r.width / 5
            wave.move(to: CGPoint(x: r.minX + st * 0.4, y: y1))
            wave.addLine(to: CGPoint(x: r.minX + st * 0.4, y: y0))
            wave.addLine(to: CGPoint(x: r.minX + st * 1.8, y: y0))
            wave.addLine(to: CGPoint(x: r.minX + st * 1.8, y: y1))
            wave.addLine(to: CGPoint(x: r.minX + st * 3.2, y: y1))
            wave.addLine(to: CGPoint(x: r.minX + st * 3.2, y: y0))
            wave.addLine(to: CGPoint(x: r.maxX - st * 0.4, y: y0))
            ctx.stroke(wave, with: .color(outValues.first == true ? Bench.high : Bench.textDim),
                       lineWidth: max(1, lw * 0.8))
        case .sevenSegment:
            drawSevenSegment(r, values: inValues, ctx: &ctx, outline: outline, lw: lw,
                             bodyShade: bodyShade)
        case .busProbe:
            var body = Path()
            body.addRoundedRect(in: r, cornerSize: CGSize(width: 3, height: 3))
            ctx.fill(body, with: bodyShade)
            ctx.stroke(body, with: lineShade, lineWidth: lw)
            var value = 0
            for (i, b) in inValues.enumerated() where b { value |= (1 << i) }
            label(String(format: "%X", value & 0xF),
                  at: CGPoint(x: r.midX, y: r.minY + r.height * 0.22),
                  size: min(r.width * 0.5, 16), color: Bench.high)
            for i in 0..<4 {
                var box = Path()
                let bw = r.width * 0.16
                box.addRect(CGRect(x: r.minX + r.width * 0.14 + CGFloat(i) * (bw * 1.35),
                                   y: r.maxY - r.height * 0.3, width: bw, height: bw))
                let on = i < inValues.count ? inValues[3 - i] : false
                ctx.fill(box, with: .color(on ? Bench.high : Bench.low))
            }
        case .srLatch, .dLatch, .dFlipFlop, .jkFlipFlop, .tFlipFlop, .chip:
            let path = dipBody(r)
            ctx.fill(path, with: bodyShade)
            ctx.stroke(path, with: lineShade, lineWidth: lw)
            var notch = Path()
            notch.addArc(center: CGPoint(x: r.minX + r.width * 0.5, y: r.minY),
                         radius: r.width * 0.09, startAngle: .degrees(0),
                         endAngle: .degrees(180), clockwise: false)
            ctx.stroke(notch, with: lineShade, lineWidth: max(1, lw * 0.8))
            let name = chip?.name ?? kind.shortName
            let size = min(r.width * 0.17, 10)
            let lines = splitLabel(name)
            if lines.count == 1 {
                label(lines[0], at: CGPoint(x: r.midX, y: r.midY), size: size)
            } else {
                label(lines[0], at: CGPoint(x: r.midX, y: r.midY - size * 0.62), size: size)
                label(lines[1], at: CGPoint(x: r.midX, y: r.midY + size * 0.62), size: size)
            }
            if kind.isEdgeTriggered, let cp = kind.clockPinIndex {
                let pin = pinPoint(rect: r, index: cp, count: kind.inputPinNames.count,
                                   isOutput: false)
                var tri = Path()
                let s = r.width * 0.09
                tri.move(to: CGPoint(x: pin.x, y: pin.y - s))
                tri.addLine(to: CGPoint(x: pin.x + s * 1.4, y: pin.y))
                tri.addLine(to: CGPoint(x: pin.x, y: pin.y + s))
                ctx.stroke(tri, with: lineShade, lineWidth: max(1, lw * 0.7))
            }
        }

        // Pins
        var inNames = chip?.inputNames ?? kind.inputPinNames
        var outNames = chip?.outputNames ?? kind.outputPinNames
        // A switch or lamp is identified by its LEVEL TERMINAL name (A/B/C, X/Y/Z), never by the
        // generic pin name. Without it every switch reads "Y" and every lamp reads "IN", and a
        // brief like "X must follow C" becomes unsolvable. Terminal names are therefore drawn
        // unconditionally and emphasised, independent of the pin-label setting.
        let isTerminal = (kind == .inputSwitch || kind == .outputLamp) && terminalLabel != nil
        if let term = terminalLabel {
            if kind == .inputSwitch { outNames = [term] }
            else if kind == .outputLamp { inNames = [term] }
        }
        drawPins(rect: r, names: inNames, values: inValues, isOutput: false,
                 showLabels: showPinLabels, emphasise: isTerminal, ctx: &ctx, lw: lw)
        drawPins(rect: r, names: outNames, values: outValues, isOutput: true,
                 showLabels: showPinLabels, emphasise: isTerminal, ctx: &ctx, lw: lw)
    }

    /// Keeps a chip's name inside its DIP outline: long names break at the last space that
    /// balances the two halves, short ones stay on one line.
    static func splitLabel(_ name: String) -> [String] {
        guard name.count > 9 else { return [name] }
        let words = name.split(separator: " ").map(String.init)
        guard words.count > 1 else { return [String(name.prefix(9))] }
        var best = 1
        var bestDiff = Int.max
        for cut in 1..<words.count {
            let a = words[0..<cut].joined(separator: " ").count
            let b = words[cut...].joined(separator: " ").count
            let diff = abs(a - b)
            if diff < bestDiff { bestDiff = diff; best = cut }
        }
        return [words[0..<best].joined(separator: " "),
                words[best...].joined(separator: " ")]
    }

    private static func bubbleAdjusted(_ r: CGRect, hasBubble: Bool) -> CGRect {
        hasBubble ? CGRect(x: r.minX, y: r.minY, width: r.width * 0.84, height: r.height) : r
    }

    private static func drawBubble(_ bodyRect: CGRect, ctx: inout GraphicsContext,
                                   color: Color, lw: CGFloat) {
        let d = bodyRect.height * 0.24
        var b = Path()
        b.addEllipse(in: CGRect(x: bodyRect.maxX, y: bodyRect.midY - d / 2, width: d, height: d))
        ctx.fill(b, with: .color(Bench.board))
        ctx.stroke(b, with: .color(color), lineWidth: max(1, lw * 0.85))
    }

    private static func drawPins(rect r: CGRect, names: [String], values: [Bool],
                                 isOutput: Bool, showLabels: Bool,
                                 emphasise: Bool = false,
                                 ctx: inout GraphicsContext, lw: CGFloat) {
        guard !names.isEmpty else { return }
        for i in 0..<names.count {
            let p = pinPoint(rect: r, index: i, count: names.count, isOutput: isOutput)
            let on = i < values.count ? values[i] : false
            var dot = Path()
            let d = max(4.5, r.width * 0.075)
            dot.addEllipse(in: CGRect(x: p.x - d / 2, y: p.y - d / 2, width: d, height: d))
            ctx.fill(dot, with: .color(on ? Bench.high : Bench.wireLow))
            if emphasise || (showLabels && r.width > 26) {
                let tx = isOutput ? p.x + d : p.x - d
                let font = emphasise ? Bench.mono(11, .bold) : Bench.mono(7, .medium)
                let colour = emphasise ? Bench.text : Bench.textFaint
                ctx.draw(Text(names[i]).font(font).foregroundColor(colour),
                         at: CGPoint(x: tx, y: p.y), anchor: isOutput ? .leading : .trailing)
            }
        }
    }

    private static func drawSevenSegment(_ r: CGRect, values: [Bool], ctx: inout GraphicsContext,
                                         outline: Color, lw: CGFloat,
                                         bodyShade: GraphicsContext.Shading) {
        var body = Path()
        body.addRoundedRect(in: r, cornerSize: CGSize(width: 4, height: 4))
        ctx.fill(body, with: bodyShade)
        ctx.stroke(body, with: .color(outline), lineWidth: lw)
        let inner = r.insetBy(dx: r.width * 0.24, dy: r.height * 0.12)
        let t = min(inner.width, inner.height) * 0.13
        let segs: [CGRect] = [
            CGRect(x: inner.minX + t, y: inner.minY, width: inner.width - 2 * t, height: t),
            CGRect(x: inner.maxX - t, y: inner.minY + t, width: t, height: inner.height / 2 - 1.5 * t),
            CGRect(x: inner.maxX - t, y: inner.midY + 0.5 * t, width: t, height: inner.height / 2 - 1.5 * t),
            CGRect(x: inner.minX + t, y: inner.maxY - t, width: inner.width - 2 * t, height: t),
            CGRect(x: inner.minX, y: inner.midY + 0.5 * t, width: t, height: inner.height / 2 - 1.5 * t),
            CGRect(x: inner.minX, y: inner.minY + t, width: t, height: inner.height / 2 - 1.5 * t),
            CGRect(x: inner.minX + t, y: inner.midY - t / 2, width: inner.width - 2 * t, height: t)
        ]
        for (i, s) in segs.enumerated() {
            var path = Path()
            path.addRoundedRect(in: s, cornerSize: CGSize(width: 1, height: 1))
            let on = i < values.count ? values[i] : false
            ctx.fill(path, with: .color(on ? Bench.high : Bench.low.opacity(0.5)))
        }
    }
}

/// Small standalone render of one part, used by the palette and the chip library.
struct PartGlyphView: View {
    let kind: PartKind
    var chip: ChipDefinition? = nil
    var tint: Color = Bench.copper
    var value: Bool = false

    var body: some View {
        Canvas { ctx, size in
            let pinsIn = chip?.inputNames.count ?? kind.inputPinNames.count
            let pinsOut = chip?.outputNames.count ?? kind.outputPinNames.count
            let s = GateArt.partSize(kind, pinsIn: pinsIn, pinsOut: pinsOut)
            let scale = min(size.width / (CGFloat(s.width) + 0.6),
                            size.height / (CGFloat(s.height) + 0.4))
            let w = CGFloat(s.width) * scale
            let h = CGFloat(s.height) * scale
            let r = CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
            var style = GateArt.RenderStyle()
            style.outline = tint
            style.lineWidth = 1.4
            GateArt.draw(part: CircuitPart(id: 0, kind: kind, chipId: chip?.id, gx: 0, gy: 0),
                         chip: chip, rect: r,
                         inValues: Array(repeating: value, count: pinsIn),
                         outValues: Array(repeating: value, count: pinsOut),
                         showPinLabels: false, style: style, ctx: &ctx)
        }
    }
}
