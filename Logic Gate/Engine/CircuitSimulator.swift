import Foundation

enum SettleStatus: Equatable {
    case settled
    case oscillating
}

/// Result of one evaluation pass over a netlist.
struct SimSnapshot {
    var status: SettleStatus
    /// Value on every output pin, indexed [partIndex][pinIndex].
    var outputs: [[Bool]]
    /// Value seen by every input pin, indexed [partIndex][pinIndex].
    var inputs: [[Bool]]
    var iterations: Int
}

/// Pure-Swift netlist simulator. No UIKit, no SwiftUI — the headless audit compiles the exact
/// same file.
final class CircuitSimulator {

    static let maxSettleIterations = 64
    static let maxEdgePasses = 24
    static let maxChipDepth = 8

    let netlist: Netlist
    private let chips: ChipCatalog
    private let depth: Int

    private var indexOf: [Int: Int] = [:]
    private var kinds: [PartKind] = []
    private var outCount: [Int] = []
    private var inCount: [Int] = []
    /// For each part, for each input pin, the driving output pin (or nil).
    private var sources: [[(Int, Int)?]] = []
    private var outValues: [[Bool]] = []
    /// Stored Q for latches and flip-flops, indexed by part index.
    private var stateQ: [Bool] = []
    /// SR latch forbidden state (S = R = 1): both outputs low.
    private var stateInvalid: [Bool] = []
    private var prevClock: [Bool] = []
    private var subSimulators: [Int: CircuitSimulator] = [:]
    private var terminalInputIndex: [Int] = []   // part index -> level input index, -1 if none

    private(set) var lastIterations = 0
    private(set) var lastStatus: SettleStatus = .settled
    private(set) var deepestChipNesting = 0

    init(netlist: Netlist, chips: ChipCatalog, depth: Int = 0) {
        self.netlist = netlist
        self.chips = chips
        self.depth = depth
        build()
    }

    private func build() {
        let parts = netlist.parts
        for (i, p) in parts.enumerated() { indexOf[p.id] = i }
        kinds = parts.map { $0.kind }
        outCount = parts.map { pinCountOut($0) }
        inCount = parts.map { pinCountIn($0) }
        outValues = outCount.map { Array(repeating: false, count: $0) }
        stateQ = Array(repeating: false, count: parts.count)
        stateInvalid = Array(repeating: false, count: parts.count)
        prevClock = Array(repeating: false, count: parts.count)
        terminalInputIndex = parts.map { p in
            (p.kind == .inputSwitch) ? (p.terminal ?? -1) : -1
        }
        sources = parts.enumerated().map { (i, _) in
            Array(repeating: nil, count: inCount[i]) as [(Int, Int)?]
        }
        for w in netlist.wires {
            guard let ti = indexOf[w.to.part], let si = indexOf[w.from.part] else { continue }
            guard w.to.pin >= 0, w.to.pin < inCount[ti] else { continue }
            guard w.from.pin >= 0, w.from.pin < outCount[si] else { continue }
            sources[ti][w.to.pin] = (si, w.from.pin)
        }
        deepestChipNesting = depth
        if depth < CircuitSimulator.maxChipDepth {
            for (i, p) in parts.enumerated() where p.kind == .chip {
                if let def = chips.definition(p.chipId) {
                    let sub = CircuitSimulator(netlist: def.netlist, chips: chips, depth: depth + 1)
                    subSimulators[i] = sub
                    deepestChipNesting = max(deepestChipNesting, sub.deepestChipNesting)
                }
            }
        }
    }

    private func pinCountIn(_ p: CircuitPart) -> Int {
        if p.kind == .chip { return chips.definition(p.chipId)?.inputNames.count ?? 0 }
        return p.kind.inputPinNames.count
    }

    private func pinCountOut(_ p: CircuitPart) -> Int {
        if p.kind == .chip { return chips.definition(p.chipId)?.outputNames.count ?? 0 }
        return p.kind.outputPinNames.count
    }

    // MARK: - Public API

    /// Restores every stored bit to zero. Combinational levels do not need it, sequential
    /// harnesses call it before each run.
    func resetState() {
        for i in 0..<stateQ.count {
            stateQ[i] = false
            stateInvalid[i] = false
            prevClock[i] = false
            outValues[i] = Array(repeating: false, count: outCount[i])
        }
        for (_, sub) in subSimulators { sub.resetState() }
    }

    /// True when this netlist (or anything nested inside it) contains an edge-triggered part.
    lazy var containsEdgeParts: Bool = {
        for k in kinds where k.isEdgeTriggered { return true }
        for (_, sub) in subSimulators where sub.containsEdgeParts { return true }
        return false
    }()

    /// Records the power-up level of every clock input so the very first settle cannot be
    /// mistaken for a rising edge. Without this a Q-bar output coming up high at reset would
    /// spuriously clock the next stage of a ripple counter.
    func primeClocks() {
        _ = settle()
        primeClockLevels()
    }

    private func primeClockLevels() {
        for i in 0..<kinds.count {
            if kinds[i].isEdgeTriggered, let cp = kinds[i].clockPinIndex {
                prevClock[i] = inputValue(i, cp)
            } else if kinds[i] == .chip, let sub = subSimulators[i] {
                sub.primeClockLevels()
            }
        }
    }

    /// Clean start for a verification run.
    func prepare() {
        resetState()
        if containsEdgeParts { primeClocks() }
    }

    /// Values pushed into the level's input switches.
    private var inputVector: [Bool] = []
    /// Value forced onto every `clock` part.
    private var clockLevel = false
    /// Values pushed into a chip's input terminals when this simulator is a sub-circuit.
    private var externalInputs: [Bool] = []

    func setInputs(_ v: [Bool]) { inputVector = v }
    func setClock(_ v: Bool) { clockLevel = v }

    /// Evaluate combinational logic until stable.
    @discardableResult
    func settle() -> SettleStatus {
        var iterations = 0
        while iterations < CircuitSimulator.maxSettleIterations {
            iterations += 1
            var changed = false
            for i in 0..<kinds.count {
                if evaluatePart(i) { changed = true }
            }
            if !changed {
                lastIterations = iterations
                lastStatus = .settled
                return .settled
            }
        }
        lastIterations = iterations
        lastStatus = .oscillating
        return .oscillating
    }

    /// Settle, then let clock edges ripple through flip-flops (and chips), re-settling between
    /// passes. This is what makes ripple counters and shift registers behave.
    @discardableResult
    func step() -> SettleStatus {
        if settle() == .oscillating { return .oscillating }
        for _ in 0..<CircuitSimulator.maxEdgePasses {
            if !resolveEdgesOnce() { break }
            if settle() == .oscillating { return .oscillating }
        }
        return .settled
    }

    private func resolveEdgesOnce() -> Bool {
        var any = false
        for i in 0..<kinds.count {
            let kind = kinds[i]
            if kind.isEdgeTriggered, let cp = kind.clockPinIndex {
                let clk = inputValue(i, cp)
                if clk && !prevClock[i] {
                    any = true
                    switch kind {
                    case .dFlipFlop:
                        stateQ[i] = inputValue(i, 0)
                    case .tFlipFlop:
                        if inputValue(i, 0) { stateQ[i].toggle() }
                    case .jkFlipFlop:
                        let j = inputValue(i, 0), k = inputValue(i, 1)
                        if j && k { stateQ[i].toggle() }
                        else if j { stateQ[i] = true }
                        else if k { stateQ[i] = false }
                    default: break
                    }
                }
                prevClock[i] = clk
            } else if kind == .chip, let sub = subSimulators[i] {
                if sub.resolveEdgesOnce() {
                    any = true
                    _ = sub.settle()
                }
            }
        }
        return any
    }

    func snapshot() -> SimSnapshot {
        var ins: [[Bool]] = []
        ins.reserveCapacity(kinds.count)
        for i in 0..<kinds.count {
            var row: [Bool] = []
            row.reserveCapacity(inCount[i])
            for p in 0..<inCount[i] { row.append(inputValue(i, p)) }
            ins.append(row)
        }
        return SimSnapshot(status: lastStatus, outputs: outValues, inputs: ins,
                           iterations: lastIterations)
    }

    func outputValue(partId: Int, pin: Int) -> Bool {
        guard let i = indexOf[partId], pin >= 0, pin < outValues[i].count else { return false }
        return outValues[i][pin]
    }

    func inputValueFor(partId: Int, pin: Int) -> Bool {
        guard let i = indexOf[partId] else { return false }
        return inputValue(i, pin)
    }

    /// Values currently shown by the level's output lamps, ordered by terminal index.
    func lampValues(count: Int) -> [Bool] {
        var out = Array(repeating: false, count: count)
        for (i, p) in netlist.parts.enumerated() where p.kind == .outputLamp {
            guard let t = p.terminal, t >= 0, t < count else { continue }
            out[t] = inputValue(i, 0)
        }
        return out
    }

    func hasSequentialParts() -> Bool {
        for k in kinds where k.isSequential { return true }
        for (_, sub) in subSimulators where sub.hasSequentialParts() { return true }
        return false
    }

    // MARK: - Evaluation

    private func inputValue(_ part: Int, _ pin: Int) -> Bool {
        guard pin >= 0, pin < sources[part].count else { return false }
        guard let s = sources[part][pin] else { return false }
        return outValues[s.0][s.1]
    }

    /// Returns true when any output of this part changed.
    private func evaluatePart(_ i: Int) -> Bool {
        let kind = kinds[i]
        var next = outValues[i]
        switch kind {
        case .inputSwitch:
            let t = terminalInputIndex[i]
            if !externalInputs.isEmpty {
                next[0] = (t >= 0 && t < externalInputs.count) ? externalInputs[t] : false
            } else {
                next[0] = (t >= 0 && t < inputVector.count) ? inputVector[t] : false
            }
        case .const0:
            next[0] = false
        case .const1:
            next[0] = true
        case .clock:
            next[0] = clockLevel
        case .buffer:
            next[0] = inputValue(i, 0)
        case .not:
            next[0] = !inputValue(i, 0)
        case .and:
            next[0] = inputValue(i, 0) && inputValue(i, 1)
        case .or:
            next[0] = inputValue(i, 0) || inputValue(i, 1)
        case .nand:
            next[0] = !(inputValue(i, 0) && inputValue(i, 1))
        case .nor:
            next[0] = !(inputValue(i, 0) || inputValue(i, 1))
        case .xor:
            next[0] = inputValue(i, 0) != inputValue(i, 1)
        case .xnor:
            next[0] = inputValue(i, 0) == inputValue(i, 1)
        case .and3:
            next[0] = inputValue(i, 0) && inputValue(i, 1) && inputValue(i, 2)
        case .junction:
            let v = inputValue(i, 0)
            next[0] = v; next[1] = v; next[2] = v
        case .srLatch:
            let s = inputValue(i, 0), r = inputValue(i, 1)
            if s && r {
                stateInvalid[i] = true
            } else if s {
                stateQ[i] = true; stateInvalid[i] = false
            } else if r {
                stateQ[i] = false; stateInvalid[i] = false
            } else {
                stateInvalid[i] = false
            }
            if stateInvalid[i] { next[0] = false; next[1] = false }
            else { next[0] = stateQ[i]; next[1] = !stateQ[i] }
        case .dLatch:
            if inputValue(i, 1) { stateQ[i] = inputValue(i, 0) }
            next[0] = stateQ[i]; next[1] = !stateQ[i]
        case .dFlipFlop, .jkFlipFlop, .tFlipFlop:
            next[0] = stateQ[i]; next[1] = !stateQ[i]
        case .outputLamp, .sevenSegment, .busProbe:
            break
        case .chip:
            guard let sub = subSimulators[i] else { break }
            var vals: [Bool] = []
            vals.reserveCapacity(inCount[i])
            for p in 0..<inCount[i] { vals.append(inputValue(i, p)) }
            sub.externalInputs = vals
            _ = sub.settle()
            let lamps = sub.lampValues(count: outCount[i])
            for p in 0..<outCount[i] { next[p] = lamps[p] }
        }
        if next != outValues[i] {
            outValues[i] = next
            return true
        }
        return false
    }
}
