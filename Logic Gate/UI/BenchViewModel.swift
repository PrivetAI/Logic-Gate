import SwiftUI

struct PaletteItem: Identifiable {
    let id: String
    let kind: PartKind
    let chip: ChipDefinition?
    var cost: Int { chip?.cost ?? kind.cost }
    var name: String { chip?.name ?? kind.displayName }
}

struct PendingWire {
    var from: CGPoint
    var to: CGPoint
}

enum BenchDragMode {
    case idle
    case place
    case wire(PinAddress)
    case move(Int, CGSize)
    case tapPart(Int)
    case tapWire(Int)
}

/// One row of the timing diagram: every input then every output at a moment in time.
struct TimingSample {
    var inputs: [Bool]
    var outputs: [Bool]
    var clock: Bool
}

final class BenchViewModel: ObservableObject {

    let level: LogicGateLevel
    let chips: ChipCatalog
    let isSandbox: Bool

    @Published var board: Netlist
    @Published var switches: [Bool]
    @Published var clockLevel = false
    @Published var selection: Int? = nil
    @Published var pending: PaletteItem? = nil
    @Published var values = BoardValues()
    @Published var verdicts: [VerdictRow] = []
    @Published var lastResult: VerifyResult? = nil
    @Published var banner: BenchBanner? = nil
    @Published var pendingWire: PendingWire? = nil
    @Published var timing: [TimingSample] = []
    @Published var activeRow: Int = -1
    @Published var canUndo = false
    @Published var hintRevealed = false

    private var liveSim: CircuitSimulator
    private var undoStack: [Netlist] = []
    private var dragMode: BenchDragMode? = nil
    private var dragOriginal: Netlist? = nil
    private var settings: LogicGateSettings

    struct BenchBanner: Identifiable {
        let id = UUID()
        let title: String
        let detail: String
        let stars: Int
        let good: Bool
    }

    init(level: LogicGateLevel, board: Netlist, chips: ChipCatalog,
         settings: LogicGateSettings, isSandbox: Bool = false) {
        self.level = level
        self.chips = chips
        self.settings = settings
        self.isSandbox = isSandbox
        self.board = board
        self.switches = Array(repeating: false, count: max(level.inputNames.count, 1))
        self.liveSim = CircuitSimulator(netlist: board, chips: chips)
        liveSim.prepare()
        evaluate(record: false)
        refreshVerdicts()
    }

    func updateSettings(_ s: LogicGateSettings) { settings = s }
    var currentSettings: LogicGateSettings { settings }

    // MARK: - Palette

    var paletteItems: [PaletteItem] {
        var out: [PaletteItem] = level.palette.map {
            PaletteItem(id: "k-\($0.rawValue)", kind: $0, chip: nil)
        }
        for id in level.chipPalette {
            if let def = chips.definition(id) {
                out.append(PaletteItem(id: "c-\(id)", kind: .chip, chip: def))
            }
        }
        return out
    }

    var cost: Int { board.cost(chips: chips) }

    var starPreview: Int {
        guard let r = lastResult, r.passed else { return 0 }
        if cost <= level.optimalCost { return 3 }
        if cost <= level.parCost { return 2 }
        return 1
    }

    // MARK: - Simulation

    func rebuildSim() {
        liveSim = CircuitSimulator(netlist: board, chips: chips)
        liveSim.prepare()
        evaluate(record: false)
        refreshVerdicts()
    }

    func evaluate(record: Bool) {
        liveSim.setInputs(switches)
        liveSim.setClock(clockLevel)
        let status = liveSim.step()
        values = BoardValues.read(netlist: board, sim: liveSim, status: status)
        if record {
            let outs = liveSim.lampValues(count: level.outputNames.count)
            timing.append(TimingSample(inputs: switches, outputs: outs, clock: clockLevel))
            if timing.count > 32 { timing.removeFirst(timing.count - 32) }
        }
    }

    func refreshVerdicts() {
        guard !isSandbox else { verdicts = []; return }
        verdicts = LevelVerifier.fullTable(level: level, board: board, chips: chips, limit: 160)
    }

    func setSwitch(_ index: Int, _ value: Bool) {
        guard index >= 0, index < switches.count else { return }
        switches[index] = value
        evaluate(record: true)
    }

    func toggleSwitch(_ index: Int) {
        guard index >= 0, index < switches.count else { return }
        switches[index].toggle()
        BenchFeedback.tap(settings)
        evaluate(record: true)
    }

    func pulseClock() {
        clockLevel = true
        evaluate(record: true)
        clockLevel = false
        evaluate(record: true)
        BenchFeedback.tap(settings)
    }

    func resetSimulation() {
        liveSim.prepare()
        timing.removeAll()
        activeRow = -1
        evaluate(record: false)
    }

    /// Applies the next test row (or script step) to the board.
    func stepTest() {
        switch level.goal {
        case .combinational:
            guard !level.vectors.isEmpty else { return }
            activeRow = (activeRow + 1) % level.vectors.count
            switches = level.vectors[activeRow]
            liveSim.prepare()
            evaluate(record: true)
        case .sequential(let steps):
            guard !steps.isEmpty else { return }
            // A sequential step is only meaningful from a defined starting state, so every
            // advance replays the script from reset rather than stacking on the current state.
            activeRow = (activeRow + 1) % steps.count
            liveSim.prepare()
            timing.removeAll()
            replaySequential(upTo: activeRow, steps: steps)
        }
    }

    func applyRow(_ index: Int) {
        switch level.goal {
        case .combinational:
            guard index >= 0, index < level.vectors.count else { return }
            activeRow = index
            switches = level.vectors[index]
            liveSim.prepare()
            evaluate(record: true)
        case .sequential(let steps):
            guard index >= 0, index < steps.count else { return }
            activeRow = index
            liveSim.prepare()
            timing.removeAll()
            replaySequential(upTo: index, steps: steps)
        }
    }

    private func replaySequential(upTo index: Int, steps: [SequentialStep]) {
        for i in 0...index {
            let s = steps[i]
            switches = s.inputs
            clockLevel = false
            evaluate(record: true)
            if s.pulse {
                clockLevel = true
                evaluate(record: true)
                clockLevel = false
                evaluate(record: true)
            }
        }
    }

    // MARK: - Editing

    private func pushUndo() {
        undoStack.append(board)
        if undoStack.count > 40 { undoStack.removeFirst() }
        canUndo = !undoStack.isEmpty
    }

    func undo() {
        guard let last = undoStack.popLast() else { return }
        board = last
        canUndo = !undoStack.isEmpty
        selection = nil
        rebuildSim()
        BenchFeedback.tap(settings)
    }

    func clearBoard(to base: Netlist) {
        pushUndo()
        board = base
        selection = nil
        rebuildSim()
    }

    func deleteSelection() {
        guard let id = selection, let part = board.part(id), !part.locked else { return }
        pushUndo()
        board.removePart(id)
        selection = nil
        rebuildSim()
        BenchFeedback.tap(settings)
    }

    // MARK: - Gesture handling

    func dragChanged(start: CGPoint, current: CGPoint, layout: BoardLayout) {
        if dragMode == nil { classify(start: start, layout: layout) }
        switch dragMode {
        case .wire(let from):
            let anchor = layout.point(of: from, isOutput: true) ?? start
            pendingWire = PendingWire(from: anchor, to: current)
        case .move(let id, let offset):
            guard let idx = board.parts.firstIndex(where: { $0.id == id }) else { return }
            let (cx, cy) = clampedPart(id,
                                       gx: layout.geo.gridX(current.x + offset.width),
                                       gy: layout.geo.gridY(current.y + offset.height))
            board.parts[idx].gx = cx
            board.parts[idx].gy = cy
        default:
            break
        }
    }

    func dragEnded(start: CGPoint, end: CGPoint, layout: BoardLayout) {
        let distance = hypot(end.x - start.x, end.y - start.y)
        let mode = dragMode ?? .idle
        dragMode = nil
        pendingWire = nil

        switch mode {
        case .place:
            place(at: end, layout: layout)
        case .wire(let from):
            if distance < 12 {
                // A tap that happened to land on an output pin is a tap on the part, not a
                // zero-length wire. Without this a small part whose body is entirely inside its
                // own pin radius could never be selected or deleted.
                selectOrToggle(from.part)
            } else if let target = layout.inputPinAt(end), target.part != from.part {
                pushUndo()
                board.connect(from: from, to: target)
                rebuildSim()
                BenchFeedback.tap(settings)
            } else if let hitPart = layout.partAt(end),
                      hitPart != from.part,
                      let names = layout.inNames[hitPart], !names.isEmpty,
                      distance > 6 {
                // Dropping on a part body wires to its nearest free input.
                let taken = Set(board.wires.filter { $0.to.part == hitPart }.map { $0.to.pin })
                if let free = (0..<names.count).first(where: { !taken.contains($0) }) {
                    pushUndo()
                    board.connect(from: from, to: PinAddress(hitPart, free))
                    rebuildSim()
                    BenchFeedback.tap(settings)
                }
            }
        case .move(let id, _):
            if distance < 12 {
                if let orig = dragOriginal { board = orig }
                selectOrToggle(id)
            } else {
                if let idx = board.parts.firstIndex(where: { $0.id == id }), settings.gridSnap {
                    let (cx, cy) = clampedPart(id,
                                               gx: (board.parts[idx].gx * 2).rounded() / 2,
                                               gy: (board.parts[idx].gy * 2).rounded() / 2)
                    board.parts[idx].gx = cx
                    board.parts[idx].gy = cy
                }
                rebuildSim()
            }
            dragOriginal = nil
        case .tapPart(let id):
            if distance < 14 {
                selectOrToggle(id)
            }
        case .tapWire(let id):
            if distance < 14 {
                pushUndo()
                board.removeWire(id)
                rebuildSim()
                BenchFeedback.tap(settings)
            }
        case .idle:
            if distance < 14 {
                selection = nil
                pending = nil
            }
        }
    }

    /// A tap on an input switch flips it. A tap on any other movable part selects it.
    /// Locked terminals never become the selection, so the Delete button can never appear
    /// pointing at something that cannot be deleted.
    private func selectOrToggle(_ id: Int) {
        guard let p = board.part(id) else { return }
        if p.kind == .inputSwitch, let t = p.terminal {
            toggleSwitch(t)
            return
        }
        if p.locked {
            selection = nil
            return
        }
        selection = (selection == id) ? nil : id
    }

    private func classify(start: CGPoint, layout: BoardLayout) {
        if pending != nil {
            dragMode = .place
            return
        }
        if let out = layout.outputPinAt(start, radius: layout.pinGrabRadius) {
            dragMode = .wire(out)
            pendingWire = PendingWire(from: layout.point(of: out, isOutput: true) ?? start,
                                      to: start)
            return
        }
        if let id = layout.partAt(start), let part = board.part(id) {
            if part.locked {
                dragMode = .tapPart(id)
            } else {
                let r = layout.rects[id] ?? .zero
                dragOriginal = board
                dragMode = .move(id, CGSize(width: r.midX - start.x, height: r.midY - start.y))
            }
            return
        }
        if let w = layout.wireAt(start, orthogonal: settings.orthogonalWires) {
            dragMode = .tapWire(w)
            return
        }
        dragMode = .idle
    }

    /// Keeps a part fully inside the board no matter how big its footprint is, so nothing can
    /// ever spill over the edge of the drawn grid.
    private func clamped(kind: PartKind, chip: ChipDefinition?,
                         gx: Double, gy: Double) -> (Double, Double) {
        let pinsIn = chip?.inputNames.count ?? kind.inputPinNames.count
        let pinsOut = chip?.outputNames.count ?? kind.outputPinNames.count
        let s = GateArt.partSize(kind, pinsIn: pinsIn, pinsOut: pinsOut)
        let halfW = s.width / 2 + 0.25
        let halfH = s.height / 2 + 0.2
        let cols = Double(level.cols), rows = Double(level.rows)
        let x = (halfW * 2 >= cols) ? cols / 2 : min(max(gx, halfW), cols - halfW)
        let y = (halfH * 2 >= rows) ? rows / 2 : min(max(gy, halfH), rows - halfH)
        return (x, y)
    }

    private func clampedPart(_ id: Int, gx: Double, gy: Double) -> (Double, Double) {
        guard let p = board.part(id) else { return (gx, gy) }
        let chip = p.kind == .chip ? chips.definition(p.chipId) : nil
        return clamped(kind: p.kind, chip: chip, gx: gx, gy: gy)
    }

    private func place(at point: CGPoint, layout: BoardLayout) {
        guard let item = pending else { return }
        var gx = layout.geo.gridX(point.x)
        var gy = layout.geo.gridY(point.y)
        if settings.gridSnap {
            gx = (gx * 2).rounded() / 2
            gy = (gy * 2).rounded() / 2
        }
        let (cx, cy) = clamped(kind: item.kind, chip: item.chip, gx: gx, gy: gy)
        pushUndo()
        _ = board.add(item.kind, chipId: item.chip?.id, gx: cx, gy: cy)
        pending = nil
        rebuildSim()
        BenchFeedback.tap(settings)
    }

    // MARK: - Verification

    func verify(store: LogicGateStore) {
        let result = LevelVerifier.verify(level: level, board: board, chips: chips)
        lastResult = result
        refreshVerdicts()
        if result.passed {
            let stars = store.submit(level: level, cost: cost, passed: true,
                                     usedHint: hintRevealed)
            var detail = "Cost \(cost) against par \(level.parCost) and optimal \(level.optimalCost)."
            if stars == 3 { detail = "Optimal at cost \(cost). Nothing wasted." }
            else if stars == 2 { detail = "Cost \(cost). Optimal is \(level.optimalCost)." }
            if let chipId = level.unlocksChip, let def = chips.definition(chipId) {
                detail += " Chip unlocked: \(def.name)."
            }
            banner = BenchBanner(title: "Verified", detail: detail, stars: stars, good: true)
            BenchFeedback.success(settings)
        } else {
            _ = store.submit(level: level, cost: cost, passed: false, usedHint: hintRevealed)
            let detail: String
            if result.oscillating {
                detail = "The circuit never settles. Somewhere a signal feeds back into itself without a latch to hold it."
            } else if let idx = result.firstFailIndex {
                detail = "Row \(idx + 1) does not match. Open the table to see which output is wrong."
            } else {
                detail = "The circuit does not satisfy the specification yet."
            }
            banner = BenchBanner(title: result.oscillating ? "Oscillating" : "Not yet",
                                 detail: detail, stars: 0, good: false)
            BenchFeedback.failure(settings)
        }
        store.storeBoard(board, for: level.id)
    }

    func persist(store: LogicGateStore) {
        guard !isSandbox else { return }
        store.storeBoard(board, for: level.id)
    }
}
