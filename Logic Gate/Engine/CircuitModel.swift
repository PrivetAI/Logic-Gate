import Foundation

// MARK: - Component kinds

/// Every part that can sit on the workbench. 22 primitives plus the chip wrapper.
enum PartKind: String, Codable, CaseIterable {
    // Gates (9)
    case not, buffer, nand, nor, and, or, xor, xnor, and3
    // Sequential (5)
    case srLatch, dLatch, dFlipFlop, jkFlipFlop, tFlipFlop
    // I/O and wiring (8)
    case inputSwitch, outputLamp, const0, const1, clock, junction, sevenSegment, busProbe
    // Composite
    case chip

    var displayName: String {
        switch self {
        case .not: return "NOT"
        case .buffer: return "BUFFER"
        case .nand: return "NAND"
        case .nor: return "NOR"
        case .and: return "AND"
        case .or: return "OR"
        case .xor: return "XOR"
        case .xnor: return "XNOR"
        case .and3: return "AND-3"
        case .srLatch: return "SR Latch"
        case .dLatch: return "D Latch"
        case .dFlipFlop: return "D Flip-Flop"
        case .jkFlipFlop: return "JK Flip-Flop"
        case .tFlipFlop: return "T Flip-Flop"
        case .inputSwitch: return "Input Switch"
        case .outputLamp: return "Output Lamp"
        case .const0: return "Constant 0"
        case .const1: return "Constant 1"
        case .clock: return "Clock"
        case .junction: return "Junction"
        case .sevenSegment: return "7-Segment"
        case .busProbe: return "Bus Probe"
        case .chip: return "Chip"
        }
    }

    var shortName: String {
        switch self {
        case .not: return "NOT"
        case .buffer: return "BUF"
        case .nand: return "NAND"
        case .nor: return "NOR"
        case .and: return "AND"
        case .or: return "OR"
        case .xor: return "XOR"
        case .xnor: return "XNOR"
        case .and3: return "AND3"
        case .srLatch: return "SR"
        case .dLatch: return "DL"
        case .dFlipFlop: return "DFF"
        case .jkFlipFlop: return "JK"
        case .tFlipFlop: return "TFF"
        case .inputSwitch: return "IN"
        case .outputLamp: return "OUT"
        case .const0: return "0"
        case .const1: return "1"
        case .clock: return "CLK"
        case .junction: return "NODE"
        case .sevenSegment: return "7SEG"
        case .busProbe: return "BUS"
        case .chip: return "CHIP"
        }
    }

    /// Build cost in the level budget. I/O and wiring nodes are free.
    var cost: Int {
        switch self {
        case .not, .buffer: return 2
        case .nand, .nor: return 4
        case .and, .or: return 6
        case .xor, .xnor: return 10
        case .and3: return 9
        case .srLatch: return 8
        case .dLatch: return 12
        case .dFlipFlop: return 16
        case .jkFlipFlop: return 20
        case .tFlipFlop: return 18
        case .inputSwitch, .outputLamp, .const0, .const1, .clock, .junction,
             .sevenSegment, .busProbe: return 0
        case .chip: return 0 // resolved from the chip definition
        }
    }

    var inputPinNames: [String] {
        switch self {
        case .not, .buffer: return ["A"]
        case .nand, .nor, .and, .or, .xor, .xnor: return ["A", "B"]
        case .and3: return ["A", "B", "C"]
        case .srLatch: return ["S", "R"]
        case .dLatch: return ["D", "EN"]
        case .dFlipFlop: return ["D", "CLK"]
        case .jkFlipFlop: return ["J", "K", "CLK"]
        case .tFlipFlop: return ["T", "CLK"]
        case .inputSwitch, .const0, .const1, .clock: return []
        case .outputLamp: return ["IN"]
        case .junction: return ["IN"]
        case .sevenSegment: return ["a", "b", "c", "d", "e", "f", "g"]
        case .busProbe: return ["b0", "b1", "b2", "b3"]
        case .chip: return []
        }
    }

    var outputPinNames: [String] {
        switch self {
        case .not, .buffer, .nand, .nor, .and, .or, .xor, .xnor, .and3: return ["Y"]
        case .srLatch, .dLatch, .dFlipFlop, .jkFlipFlop, .tFlipFlop: return ["Q", "Q'"]
        case .inputSwitch, .const0, .const1, .clock: return ["Y"]
        case .outputLamp, .sevenSegment, .busProbe: return []
        case .junction: return ["1", "2", "3"]
        case .chip: return []
        }
    }

    var isSequential: Bool {
        switch self {
        case .srLatch, .dLatch, .dFlipFlop, .jkFlipFlop, .tFlipFlop: return true
        default: return false
        }
    }

    /// Latches respond to levels, flip-flops respond to a clock edge.
    var isEdgeTriggered: Bool {
        switch self {
        case .dFlipFlop, .jkFlipFlop, .tFlipFlop: return true
        default: return false
        }
    }

    var clockPinIndex: Int? {
        switch self {
        case .dFlipFlop, .tFlipFlop: return 1
        case .jkFlipFlop: return 2
        default: return nil
        }
    }

    var category: PartCategory {
        switch self {
        case .not, .buffer, .nand, .nor, .and, .or, .xor, .xnor, .and3: return .gate
        case .srLatch, .dLatch, .dFlipFlop, .jkFlipFlop, .tFlipFlop: return .memory
        case .chip: return .chip
        default: return .io
        }
    }
}

enum PartCategory: String {
    case gate, memory, io, chip
    var title: String {
        switch self {
        case .gate: return "Gates"
        case .memory: return "Memory"
        case .io: return "I/O & Wiring"
        case .chip: return "Chips"
        }
    }
}

// MARK: - Netlist

struct PinAddress: Codable, Hashable {
    var part: Int
    var pin: Int

    init(_ part: Int, _ pin: Int) {
        self.part = part
        self.pin = pin
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        part = try c.decodeIfPresent(Int.self, forKey: .part) ?? 0
        pin = try c.decodeIfPresent(Int.self, forKey: .pin) ?? 0
    }
}

struct CircuitPart: Codable, Identifiable, Equatable {
    var id: Int
    var kind: PartKind
    var chipId: String?
    /// Board coordinates in grid cells.
    var gx: Double
    var gy: Double
    /// For input switches and output lamps: which level terminal this part represents.
    var terminal: Int?
    /// Locked parts are placed by the level and cannot be moved or deleted.
    var locked: Bool

    init(id: Int, kind: PartKind, chipId: String? = nil, gx: Double, gy: Double,
         terminal: Int? = nil, locked: Bool = false) {
        self.id = id
        self.kind = kind
        self.chipId = chipId
        self.gx = gx
        self.gy = gy
        self.terminal = terminal
        self.locked = locked
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        kind = try c.decodeIfPresent(PartKind.self, forKey: .kind) ?? .buffer
        chipId = try c.decodeIfPresent(String.self, forKey: .chipId)
        gx = try c.decodeIfPresent(Double.self, forKey: .gx) ?? 0
        gy = try c.decodeIfPresent(Double.self, forKey: .gy) ?? 0
        terminal = try c.decodeIfPresent(Int.self, forKey: .terminal)
        locked = try c.decodeIfPresent(Bool.self, forKey: .locked) ?? false
    }
}

struct CircuitWire: Codable, Identifiable, Equatable {
    var id: Int
    var from: PinAddress
    var to: PinAddress

    init(id: Int, from: PinAddress, to: PinAddress) {
        self.id = id
        self.from = from
        self.to = to
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        self.from = try c.decodeIfPresent(PinAddress.self, forKey: .from) ?? PinAddress(0, 0)
        to = try c.decodeIfPresent(PinAddress.self, forKey: .to) ?? PinAddress(0, 0)
    }
}

struct Netlist: Codable, Equatable {
    var parts: [CircuitPart]
    var wires: [CircuitWire]
    var nextId: Int

    init(parts: [CircuitPart] = [], wires: [CircuitWire] = [], nextId: Int = 1) {
        self.parts = parts
        self.wires = wires
        self.nextId = max(nextId, (parts.map { $0.id }.max() ?? 0) + 1)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        parts = try c.decodeIfPresent([CircuitPart].self, forKey: .parts) ?? []
        wires = try c.decodeIfPresent([CircuitWire].self, forKey: .wires) ?? []
        let stored = try c.decodeIfPresent(Int.self, forKey: .nextId) ?? 1
        nextId = max(stored, (parts.map { $0.id }.max() ?? 0) + 1)
    }

    func part(_ id: Int) -> CircuitPart? { parts.first(where: { $0.id == id }) }

    mutating func add(_ kind: PartKind, chipId: String? = nil, gx: Double, gy: Double,
                      terminal: Int? = nil, locked: Bool = false) -> Int {
        let id = nextId
        nextId += 1
        parts.append(CircuitPart(id: id, kind: kind, chipId: chipId, gx: gx, gy: gy,
                                 terminal: terminal, locked: locked))
        return id
    }

    /// Connects an output pin to an input pin. An input takes exactly one wire, so any
    /// existing wire into that input is replaced.
    mutating func connect(from: PinAddress, to: PinAddress) {
        wires.removeAll { $0.to == to }
        let id = nextId
        nextId += 1
        wires.append(CircuitWire(id: id, from: from, to: to))
    }

    mutating func removePart(_ id: Int) {
        parts.removeAll { $0.id == id }
        wires.removeAll { $0.from.part == id || $0.to.part == id }
    }

    mutating func removeWire(_ id: Int) {
        wires.removeAll { $0.id == id }
    }

    func cost(chips: ChipCatalog) -> Int {
        var total = 0
        for p in parts {
            if p.kind == .chip {
                total += chips.definition(p.chipId)?.cost ?? 0
            } else {
                total += p.kind.cost
            }
        }
        return total
    }

    var partCount: Int { parts.filter { $0.kind.cost > 0 || $0.kind == .chip }.count }

    /// Terminal-bound parts sorted by terminal index.
    func terminals(_ kind: PartKind) -> [CircuitPart] {
        parts.filter { $0.kind == kind && $0.terminal != nil }
            .sorted { ($0.terminal ?? 0) < ($1.terminal ?? 0) }
    }
}

// MARK: - Chips

struct ChipDefinition {
    let id: String
    let name: String
    let inputNames: [String]
    let outputNames: [String]
    let netlist: Netlist
    let cost: Int
    let sourceLevel: Int
    let blurb: String
}

/// Lookup for chip definitions. A protocol-free box keeps the engine free of dependencies
/// and lets the headless audit share the exact same code.
final class ChipCatalog {
    private var map: [String: ChipDefinition] = [:]
    private(set) var ordered: [ChipDefinition] = []

    init() {}

    func register(_ def: ChipDefinition) {
        map[def.id] = def
        ordered.append(def)
    }

    func definition(_ id: String?) -> ChipDefinition? {
        guard let id = id else { return nil }
        return map[id]
    }

    var count: Int { ordered.count }
}
