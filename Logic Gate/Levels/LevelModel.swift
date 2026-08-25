import Foundation

// MARK: - Goals

/// One scripted moment in a sequential test: apply the inputs, optionally pulse the clock,
/// then compare the lamps with `expected`.
struct SequentialStep {
    let inputs: [Bool]
    let pulse: Bool
    let expected: [Bool]
    let note: String

    init(_ inputs: [Bool], pulse: Bool, expect expected: [Bool], note: String = "") {
        self.inputs = inputs
        self.pulse = pulse
        self.expected = expected
        self.note = note
    }
}

enum LevelGoal {
    /// Pure function from the input vector to the output vector, checked over `vectors`.
    case combinational(([Bool]) -> [Bool])
    /// Ordered script; the board keeps its state between steps.
    case sequential([SequentialStep])

    var isSequential: Bool {
        if case .sequential = self { return true }
        return false
    }
}

enum VerdictRow: Equatable {
    case pass
    case fail
    case untested
}

struct VerifyResult {
    var passed: Bool
    var oscillating: Bool
    var rowVerdicts: [VerdictRow]
    var firstFailIndex: Int?
    var testedRows: Int
}

// MARK: - Level

struct LogicGateLevel: Identifiable {
    let id: Int              // 1...80
    let chapter: Int         // 1...7
    let title: String
    let brief: String
    let hint: String
    let inputNames: [String]
    let outputNames: [String]
    let goal: LevelGoal
    let palette: [PartKind]
    let chipPalette: [String]
    let cols: Int
    let rows: Int
    let referenceSolution: Netlist
    let parCost: Int
    let optimalCost: Int
    /// Chip unlocked by clearing this level, if any.
    let unlocksChip: String?
    /// Input vectors used for verification (exhaustive when small, sampled when huge).
    let vectors: [[Bool]]

    var isSequential: Bool { goal.isSequential }

    /// The board the player starts from: locked terminals only, no wires.
    var startingBoard: Netlist {
        var n = Netlist()
        let inCount = inputNames.count
        let outCount = outputNames.count
        let leftX = 1.0
        let rightX = Double(cols) - 2.0
        for i in 0..<inCount {
            let y = spread(index: i, count: inCount)
            _ = n.add(.inputSwitch, gx: leftX, gy: y, terminal: i, locked: true)
        }
        for i in 0..<outCount {
            let y = spread(index: i, count: outCount)
            _ = n.add(.outputLamp, gx: rightX, gy: y, terminal: i, locked: true)
        }
        return n
    }

    private func spread(index: Int, count: Int) -> Double {
        guard count > 1 else { return Double(rows) / 2.0 - 0.5 }
        let usable = Double(rows) - 2.0
        let step = usable / Double(count - 1)
        return 1.0 + step * Double(index)
    }

    func expectedOutputs(for vector: [Bool]) -> [Bool] {
        switch goal {
        case .combinational(let f): return f(vector)
        case .sequential: return Array(repeating: false, count: outputNames.count)
        }
    }
}

// MARK: - Verification

enum LevelVerifier {

    static func verify(level: LogicGateLevel, board: Netlist, chips: ChipCatalog) -> VerifyResult {
        switch level.goal {
        case .combinational(let fn):
            return verifyCombinational(level: level, board: board, chips: chips, fn: fn)
        case .sequential(let steps):
            return verifySequential(level: level, board: board, chips: chips, steps: steps)
        }
    }

    private static func verifyCombinational(level: LogicGateLevel, board: Netlist,
                                            chips: ChipCatalog,
                                            fn: ([Bool]) -> [Bool]) -> VerifyResult {
        let sim = CircuitSimulator(netlist: board, chips: chips)
        var verdicts = [VerdictRow](repeating: .untested, count: level.vectors.count)
        var passed = true
        var oscillating = false
        var firstFail: Int?
        var tested = 0
        for (i, v) in level.vectors.enumerated() {
            sim.prepare()
            sim.setInputs(v)
            sim.setClock(false)
            let status = sim.step()
            tested += 1
            if status == .oscillating {
                oscillating = true
                verdicts[i] = .fail
                passed = false
                if firstFail == nil { firstFail = i }
                break
            }
            let got = sim.lampValues(count: level.outputNames.count)
            if got == fn(v) {
                verdicts[i] = .pass
            } else {
                verdicts[i] = .fail
                passed = false
                if firstFail == nil { firstFail = i }
                break
            }
        }
        return VerifyResult(passed: passed, oscillating: oscillating, rowVerdicts: verdicts,
                            firstFailIndex: firstFail, testedRows: tested)
    }

    private static func verifySequential(level: LogicGateLevel, board: Netlist,
                                         chips: ChipCatalog,
                                         steps: [SequentialStep]) -> VerifyResult {
        let sim = CircuitSimulator(netlist: board, chips: chips)
        sim.prepare()
        var verdicts = [VerdictRow](repeating: .untested, count: steps.count)
        var passed = true
        var oscillating = false
        var firstFail: Int?
        var tested = 0
        for (i, s) in steps.enumerated() {
            sim.setInputs(s.inputs)
            sim.setClock(false)
            if sim.step() == .oscillating {
                oscillating = true; passed = false; verdicts[i] = .fail
                if firstFail == nil { firstFail = i }
                break
            }
            if s.pulse {
                sim.setClock(true)
                if sim.step() == .oscillating {
                    oscillating = true; passed = false; verdicts[i] = .fail
                    if firstFail == nil { firstFail = i }
                    break
                }
                sim.setClock(false)
                if sim.step() == .oscillating {
                    oscillating = true; passed = false; verdicts[i] = .fail
                    if firstFail == nil { firstFail = i }
                    break
                }
            }
            tested += 1
            let got = sim.lampValues(count: level.outputNames.count)
            if got == s.expected {
                verdicts[i] = .pass
            } else {
                verdicts[i] = .fail
                passed = false
                if firstFail == nil { firstFail = i }
                break
            }
        }
        return VerifyResult(passed: passed, oscillating: oscillating, rowVerdicts: verdicts,
                            firstFailIndex: firstFail, testedRows: tested)
    }

    /// Live per-row verdicts for the truth-table panel: evaluates every row without bailing out.
    static func fullTable(level: LogicGateLevel, board: Netlist,
                          chips: ChipCatalog, limit: Int = 256) -> [VerdictRow] {
        switch level.goal {
        case .combinational(let fn):
            let sim = CircuitSimulator(netlist: board, chips: chips)
            var verdicts = [VerdictRow](repeating: .untested, count: level.vectors.count)
            for (i, v) in level.vectors.enumerated() {
                if i >= limit { break }
                sim.prepare()
                sim.setInputs(v)
                sim.setClock(false)
                if sim.step() == .oscillating { verdicts[i] = .fail; continue }
                verdicts[i] = sim.lampValues(count: level.outputNames.count) == fn(v) ? .pass : .fail
            }
            return verdicts
        case .sequential(let steps):
            let sim = CircuitSimulator(netlist: board, chips: chips)
            sim.prepare()
            var verdicts = [VerdictRow](repeating: .untested, count: steps.count)
            for (i, s) in steps.enumerated() {
                sim.setInputs(s.inputs)
                sim.setClock(false)
                if sim.step() == .oscillating { verdicts[i] = .fail; break }
                if s.pulse {
                    sim.setClock(true)
                    if sim.step() == .oscillating { verdicts[i] = .fail; break }
                    sim.setClock(false)
                    if sim.step() == .oscillating { verdicts[i] = .fail; break }
                }
                verdicts[i] = sim.lampValues(count: level.outputNames.count) == s.expected ? .pass : .fail
            }
            return verdicts
        }
    }
}

// MARK: - Vector helpers

enum Vectors {
    /// Every combination of `n` bits, MSB first.
    static func exhaustive(_ n: Int) -> [[Bool]] {
        let total = 1 << n
        var out: [[Bool]] = []
        out.reserveCapacity(total)
        for m in 0..<total {
            var row = [Bool](repeating: false, count: n)
            for b in 0..<n { row[b] = (m >> (n - 1 - b)) & 1 == 1 }
            out.append(row)
        }
        return out
    }

    /// Deterministic sample for wide inputs: all-zero, all-one, single-bit walks, then a
    /// seeded pseudo-random spread. Used only when 2^n would be unreasonable to enumerate.
    static func sampled(_ n: Int, count: Int) -> [[Bool]] {
        var out: [[Bool]] = []
        out.append([Bool](repeating: false, count: n))
        out.append([Bool](repeating: true, count: n))
        for b in 0..<n {
            var row = [Bool](repeating: false, count: n); row[b] = true; out.append(row)
            var inv = [Bool](repeating: true, count: n); inv[b] = false; out.append(inv)
        }
        var seed: UInt64 = 0x5EED_10D1C
        while out.count < count {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            var row = [Bool](repeating: false, count: n)
            for b in 0..<n { row[b] = ((seed >> UInt64(b * 3 + 11)) & 1) == 1 }
            if !out.contains(row) { out.append(row) }
        }
        return out
    }

    static func vectors(_ n: Int) -> [[Bool]] {
        if n <= 11 { return exhaustive(n) }
        return sampled(n, count: 320)
    }

    static func number(_ bits: ArraySlice<Bool>) -> Int {
        var v = 0
        for b in bits { v = (v << 1) | (b ? 1 : 0) }
        return v
    }

    static func bits(_ value: Int, width: Int) -> [Bool] {
        var out = [Bool](repeating: false, count: width)
        for i in 0..<width { out[i] = (value >> (width - 1 - i)) & 1 == 1 }
        return out
    }
}
