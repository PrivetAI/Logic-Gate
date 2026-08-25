import SwiftUI

/// Pre-computed screen geometry for every part on a board. Drawing and hit-testing both read
/// from this, so a tap can never land somewhere different from what was painted.
struct BoardLayout {
    let netlist: Netlist
    let chips: ChipCatalog
    let geo: BoardGeometry
    private(set) var rects: [Int: CGRect] = [:]
    private(set) var inPins: [Int: [CGPoint]] = [:]
    private(set) var outPins: [Int: [CGPoint]] = [:]
    private(set) var inNames: [Int: [String]] = [:]
    private(set) var outNames: [Int: [String]] = [:]

    init(netlist: Netlist, chips: ChipCatalog, geo: BoardGeometry) {
        self.netlist = netlist
        self.chips = chips
        self.geo = geo
        for p in netlist.parts {
            let def = p.kind == .chip ? chips.definition(p.chipId) : nil
            let inN = def?.inputNames ?? p.kind.inputPinNames
            let outN = def?.outputNames ?? p.kind.outputPinNames
            let r = GateArt.rect(for: p, pinsIn: inN.count, pinsOut: outN.count, geo: geo)
            rects[p.id] = r
            inNames[p.id] = inN
            outNames[p.id] = outN
            inPins[p.id] = (0..<inN.count).map {
                GateArt.pinPoint(rect: r, index: $0, count: inN.count, isOutput: false)
            }
            outPins[p.id] = (0..<outN.count).map {
                GateArt.pinPoint(rect: r, index: $0, count: outN.count, isOutput: true)
            }
        }
    }

    /// Generous when looking for a wire's destination, tighter when deciding whether a touch
    /// that landed on a part was meant to grab a pin rather than the body.
    var pinHitRadius: CGFloat { max(20, geo.cell * 0.6) }
    var pinGrabRadius: CGFloat { max(13, geo.cell * 0.42) }
    var wireHitRadius: CGFloat { max(11, geo.cell * 0.3) }

    func outputPinAt(_ p: CGPoint, radius: CGFloat? = nil) -> PinAddress? {
        let r = radius ?? pinHitRadius
        var best: (PinAddress, CGFloat)?
        for part in netlist.parts {
            guard let pins = outPins[part.id] else { continue }
            for (i, q) in pins.enumerated() {
                let d = hypot(q.x - p.x, q.y - p.y)
                if d <= r, best == nil || d < best!.1 {
                    best = (PinAddress(part.id, i), d)
                }
            }
        }
        return best?.0
    }

    func inputPinAt(_ p: CGPoint, radius: CGFloat? = nil) -> PinAddress? {
        let r = radius ?? pinHitRadius
        var best: (PinAddress, CGFloat)?
        for part in netlist.parts {
            guard let pins = inPins[part.id] else { continue }
            for (i, q) in pins.enumerated() {
                let d = hypot(q.x - p.x, q.y - p.y)
                if d <= r, best == nil || d < best!.1 {
                    best = (PinAddress(part.id, i), d)
                }
            }
        }
        return best?.0
    }

    func partAt(_ p: CGPoint) -> Int? {
        // Later parts sit on top, so search backwards.
        for part in netlist.parts.reversed() {
            if let r = rects[part.id], r.insetBy(dx: -2, dy: -2).contains(p) { return part.id }
        }
        return nil
    }

    func point(of addr: PinAddress, isOutput: Bool) -> CGPoint? {
        let table = isOutput ? outPins : inPins
        guard let pins = table[addr.part], addr.pin >= 0, addr.pin < pins.count else { return nil }
        return pins[addr.pin]
    }

    func wirePoints(_ w: CircuitWire) -> (CGPoint, CGPoint)? {
        guard let a = point(of: w.from, isOutput: true),
              let b = point(of: w.to, isOutput: false) else { return nil }
        return (a, b)
    }

    func wirePath(_ w: CircuitWire, orthogonal: Bool) -> Path? {
        guard let (a, b) = wirePoints(w) else { return nil }
        return BoardLayout.routePath(a, b, orthogonal: orthogonal)
    }

    static func routePath(_ a: CGPoint, _ b: CGPoint, orthogonal: Bool) -> Path {
        var p = Path()
        p.move(to: a)
        if orthogonal {
            let midX = (a.x + b.x) / 2
            p.addLine(to: CGPoint(x: midX, y: a.y))
            p.addLine(to: CGPoint(x: midX, y: b.y))
            p.addLine(to: b)
        } else {
            p.addLine(to: b)
        }
        return p
    }

    static func segments(_ a: CGPoint, _ b: CGPoint, orthogonal: Bool) -> [(CGPoint, CGPoint)] {
        if orthogonal {
            let midX = (a.x + b.x) / 2
            let m1 = CGPoint(x: midX, y: a.y)
            let m2 = CGPoint(x: midX, y: b.y)
            return [(a, m1), (m1, m2), (m2, b)]
        }
        return [(a, b)]
    }

    func wireAt(_ p: CGPoint, orthogonal: Bool) -> Int? {
        var best: (Int, CGFloat)?
        for w in netlist.wires {
            guard let (a, b) = wirePoints(w) else { continue }
            for seg in BoardLayout.segments(a, b, orthogonal: orthogonal) {
                let d = BoardLayout.distance(p, seg.0, seg.1)
                if d <= wireHitRadius, best == nil || d < best!.1 { best = (w.id, d) }
            }
        }
        return best?.0
    }

    static func distance(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let len2 = dx * dx + dy * dy
        if len2 < 0.0001 { return hypot(p.x - a.x, p.y - a.y) }
        var t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2
        t = max(0, min(1, t))
        return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
    }
}

/// Live pin values for a board, produced by the simulator.
struct BoardValues {
    var outputs: [Int: [Bool]] = [:]
    var inputs: [Int: [Bool]] = [:]
    var status: SettleStatus = .settled

    static func compute(netlist: Netlist, chips: ChipCatalog, inputVector: [Bool],
                        clock: Bool, sim: CircuitSimulator? = nil) -> BoardValues {
        let s = sim ?? CircuitSimulator(netlist: netlist, chips: chips)
        if sim == nil { s.prepare() }
        s.setInputs(inputVector)
        s.setClock(clock)
        let status = s.step()
        return read(netlist: netlist, sim: s, status: status)
    }

    static func read(netlist: Netlist, sim: CircuitSimulator, status: SettleStatus) -> BoardValues {
        var v = BoardValues()
        v.status = status
        let snap = sim.snapshot()
        for (i, p) in netlist.parts.enumerated() {
            if i < snap.outputs.count { v.outputs[p.id] = snap.outputs[i] }
            if i < snap.inputs.count { v.inputs[p.id] = snap.inputs[i] }
        }
        return v
    }
}

/// Draws a board. Used by the workbench, the chip internals viewer and the reference diagrams.
struct BoardCanvas: View {
    let layout: BoardLayout
    let values: BoardValues
    var selection: Int? = nil
    var showPinLabels: Bool = true
    var orthogonal: Bool = true
    var showGrid: Bool = true
    var pendingWire: (CGPoint, CGPoint)? = nil
    var dashPhase: CGFloat = 0
    /// Level terminal names (A/B/C and X/Y/Z). Empty for reference diagrams, which have none.
    var inputTerminalNames: [String] = []
    var outputTerminalNames: [String] = []

    var body: some View {
        Canvas { ctx, _ in
            let geo = layout.geo
            if showGrid {
                var frame = Path()
                frame.addRoundedRect(in: geo.boardRect, cornerSize: CGSize(width: 8, height: 8))
                ctx.fill(frame, with: .color(Bench.board))
                var dots = Path()
                let r: CGFloat = max(0.8, geo.cell * 0.045)
                var gx = 1
                while gx < geo.cols {
                    var gy = 1
                    while gy < geo.rows {
                        let p = geo.point(Double(gx), Double(gy))
                        dots.addEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
                        gy += 1
                    }
                    gx += 1
                }
                ctx.fill(dots, with: .color(Bench.grid))
                ctx.stroke(frame, with: .color(Bench.stroke), lineWidth: 1)
            }

            // Wires under parts.
            for w in layout.netlist.wires {
                guard let (a, b) = layout.wirePoints(w) else { continue }
                let live = values.outputs[w.from.part].flatMap { arr -> Bool? in
                    w.from.pin < arr.count ? arr[w.from.pin] : nil
                } ?? false
                let path = BoardLayout.routePath(a, b, orthogonal: orthogonal)
                if values.status == .oscillating {
                    ctx.stroke(path, with: .color(Bench.osc),
                               style: StrokeStyle(lineWidth: max(1.6, geo.cell * 0.075),
                                                  lineCap: .round, dash: [5, 4],
                                                  dashPhase: dashPhase))
                } else {
                    ctx.stroke(path, with: .color(live ? Bench.high : Bench.wireLow),
                               style: StrokeStyle(lineWidth: max(1.6, geo.cell * 0.075),
                                                  lineCap: .round, lineJoin: .round))
                }
            }

            if let pending = pendingWire {
                let path = BoardLayout.routePath(pending.0, pending.1, orthogonal: false)
                ctx.stroke(path, with: .color(Bench.copper),
                           style: StrokeStyle(lineWidth: max(1.6, geo.cell * 0.07),
                                              lineCap: .round, dash: [4, 3]))
                var tip = Path()
                tip.addEllipse(in: CGRect(x: pending.1.x - 5, y: pending.1.y - 5,
                                          width: 10, height: 10))
                ctx.fill(tip, with: .color(Bench.copper))
            }

            for p in layout.netlist.parts {
                guard let r = layout.rects[p.id] else { continue }
                var style = GateArt.RenderStyle()
                style.selected = (selection == p.id)
                style.outline = p.locked ? Bench.textDim : Bench.copper
                style.lineWidth = max(1.2, geo.cell * 0.06)
                let def = p.kind == .chip ? layout.chips.definition(p.chipId) : nil
                var termLabel: String? = nil
                if let t = p.terminal, t >= 0 {
                    if p.kind == .inputSwitch, t < inputTerminalNames.count {
                        termLabel = inputTerminalNames[t]
                    } else if p.kind == .outputLamp, t < outputTerminalNames.count {
                        termLabel = outputTerminalNames[t]
                    }
                }
                GateArt.draw(part: p, chip: def, rect: r,
                             inValues: values.inputs[p.id] ?? [],
                             outValues: values.outputs[p.id] ?? [],
                             showPinLabels: showPinLabels, style: style,
                             terminalLabel: termLabel, ctx: &ctx)
            }
        }
    }
}

/// Read-only board preview that sizes itself from a parent GeometryReader.
struct BoardPreview: View {
    let netlist: Netlist
    let chips: ChipCatalog
    var cols: Int = 16
    var rows: Int = 10
    var height: CGFloat = 170
    var inputVector: [Bool] = []
    var showPinLabels: Bool = false

    var body: some View {
        GeometryReader { proxy in
            let w = benchUsableWidth(proxy.size.width)
            let size = CGSize(width: w, height: height)
            let geo = BoardGeometry(cols: cols, rows: rows, size: size)
            let layout = BoardLayout(netlist: netlist, chips: chips, geo: geo)
            let vector = inputVector.isEmpty
                ? Array(repeating: false, count: netlist.terminals(.inputSwitch).count)
                : inputVector
            let values = BoardValues.compute(netlist: netlist, chips: chips,
                                             inputVector: vector, clock: false)
            BoardCanvas(layout: layout, values: values, selection: nil,
                        showPinLabels: showPinLabels, orthogonal: true, showGrid: true)
                .frame(width: w, height: height)
        }
        .frame(height: height)
    }
}
