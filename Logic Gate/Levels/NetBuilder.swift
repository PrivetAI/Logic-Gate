import Foundation

/// A reference to one output pin, used while authoring reference circuits.
struct Tap {
    let part: Int
    let pin: Int
    init(_ part: Int, _ pin: Int) {
        self.part = part
        self.pin = pin
    }
}

/// Compact authoring DSL for reference solutions and chip internals.
/// Every gate is created already wired, so a whole circuit reads like an expression tree.
/// Positions are assigned afterwards by a layered layout so the stored netlist renders
/// sensibly in the hint view and the chip internals view.
final class NetBuilder {
    private(set) var net = Netlist()
    private var layer: [Int: Int] = [:]
    private var order: [Int] = []
    private let chips: ChipCatalog

    init(chips: ChipCatalog) {
        self.chips = chips
    }

    // MARK: sources

    @discardableResult
    func inp(_ terminal: Int) -> Tap {
        let id = net.add(.inputSwitch, gx: 0, gy: 0, terminal: terminal, locked: true)
        layer[id] = 0
        order.append(id)
        return Tap(id, 0)
    }

    func lit(_ value: Bool) -> Tap {
        let id = net.add(value ? .const1 : .const0, gx: 0, gy: 0)
        layer[id] = 0
        order.append(id)
        return Tap(id, 0)
    }

    func clockSource() -> Tap {
        let id = net.add(.clock, gx: 0, gy: 0)
        layer[id] = 0
        order.append(id)
        return Tap(id, 0)
    }

    // MARK: sinks

    func out(_ terminal: Int, _ src: Tap) {
        let id = net.add(.outputLamp, gx: 0, gy: 0, terminal: terminal, locked: true)
        layer[id] = (layer[src.part] ?? 0) + 1
        order.append(id)
        net.connect(from: PinAddress(src.part, src.pin), to: PinAddress(id, 0))
    }

    // MARK: gates

    @discardableResult
    func g(_ kind: PartKind, _ sources: Tap...) -> Tap {
        return gate(kind, sources)
    }

    @discardableResult
    func gate(_ kind: PartKind, _ sources: [Tap]) -> Tap {
        let id = net.add(kind, gx: 0, gy: 0)
        var maxLayer = 0
        for (i, s) in sources.enumerated() {
            net.connect(from: PinAddress(s.part, s.pin), to: PinAddress(id, i))
            maxLayer = max(maxLayer, layer[s.part] ?? 0)
        }
        layer[id] = maxLayer + 1
        order.append(id)
        return Tap(id, 0)
    }

    /// Two-output parts (latches and flip-flops) return both Q and Q-bar.
    func mem(_ kind: PartKind, _ sources: [Tap]) -> (q: Tap, qbar: Tap) {
        let id = net.add(kind, gx: 0, gy: 0)
        var maxLayer = 0
        for (i, s) in sources.enumerated() {
            net.connect(from: PinAddress(s.part, s.pin), to: PinAddress(id, i))
            maxLayer = max(maxLayer, layer[s.part] ?? 0)
        }
        layer[id] = maxLayer + 1
        order.append(id)
        return (Tap(id, 0), Tap(id, 1))
    }

    /// Creates a part but leaves its inputs unwired, so feedback loops can be closed later.
    func open(_ kind: PartKind) -> Int {
        let id = net.add(kind, gx: 0, gy: 0)
        layer[id] = 1
        order.append(id)
        return id
    }

    func wire(_ src: Tap, into part: Int, pin: Int) {
        net.connect(from: PinAddress(src.part, src.pin), to: PinAddress(part, pin))
        layer[part] = max(layer[part] ?? 1, min((layer[src.part] ?? 0) + 1, 12))
    }

    func tap(_ part: Int, _ pin: Int = 0) -> Tap { Tap(part, pin) }

    // MARK: chips

    func chip(_ chipId: String, _ sources: [Tap]) -> [Tap] {
        let id = net.add(.chip, chipId: chipId, gx: 0, gy: 0)
        var maxLayer = 0
        for (i, s) in sources.enumerated() {
            net.connect(from: PinAddress(s.part, s.pin), to: PinAddress(id, i))
            maxLayer = max(maxLayer, layer[s.part] ?? 0)
        }
        layer[id] = maxLayer + 1
        order.append(id)
        let outs = chips.definition(chipId)?.outputNames.count ?? 0
        return (0..<outs).map { Tap(id, $0) }
    }

    // MARK: finish

    /// Lays parts out in columns by logic depth and returns the finished netlist.
    func finish(cols: Int, rows: Int) -> Netlist {
        var maxLayer = 0
        for id in order { maxLayer = max(maxLayer, layer[id] ?? 0) }
        // Output lamps always sit in the last column.
        for p in net.parts where p.kind == .outputLamp { layer[p.id] = maxLayer }
        var buckets: [Int: [Int]] = [:]
        for id in order {
            let l = layer[id] ?? 0
            buckets[l, default: []].append(id)
        }
        let columnCount = maxLayer + 1
        let usableW = Double(cols) - 2.4
        let xStep = columnCount > 1 ? usableW / Double(columnCount - 1) : 0
        for (l, ids) in buckets {
            let x = 1.2 + xStep * Double(l)
            let n = ids.count
            let usableH = Double(rows) - 1.6
            for (i, id) in ids.enumerated() {
                let y: Double
                if n == 1 {
                    y = Double(rows) / 2.0
                } else {
                    y = 0.8 + usableH * Double(i) / Double(n - 1)
                }
                if let idx = net.parts.firstIndex(where: { $0.id == id }) {
                    net.parts[idx].gx = x
                    net.parts[idx].gy = y
                }
            }
        }
        return net
    }

    var cost: Int { net.cost(chips: chips) }
}
