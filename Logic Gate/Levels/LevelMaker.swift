import Foundation

struct ChipUnlock {
    let id: String
    let name: String
    let blurb: String
}

/// Palette shorthands used by the chapter files.
enum Palettes {
    static let wiringOnly: [PartKind] = [.buffer, .junction]
    static let basic: [PartKind] = [.not, .and, .or, .junction]
    static let allGates: [PartKind] = [.not, .buffer, .and, .or, .nand, .nor, .xor, .xnor,
                                       .and3, .junction]
    static let withConstants: [PartKind] = [.not, .buffer, .and, .or, .nand, .nor, .xor, .xnor,
                                            .and3, .junction, .const0, .const1]
    static let nandOnly: [PartKind] = [.nand, .junction]
    static let norOnly: [PartKind] = [.nor, .junction]
    static let memory: [PartKind] = [.not, .buffer, .and, .or, .nand, .nor, .xor, .xnor, .and3,
                                     .junction, .const0, .const1, .srLatch, .dLatch,
                                     .dFlipFlop, .jkFlipFlop, .tFlipFlop]
    static let everything: [PartKind] = [.not, .buffer, .and, .or, .nand, .nor, .xor, .xnor,
                                         .and3, .srLatch, .dLatch, .dFlipFlop, .jkFlipFlop,
                                         .tFlipFlop, .const0, .const1, .clock, .junction,
                                         .sevenSegment, .busProbe]
}

/// Builds levels and registers the chips they unlock. Chapters are constructed in order so a
/// level can always reference a chip an earlier level created.
final class LevelMaker {
    let chips: ChipCatalog

    init(chips: ChipCatalog) {
        self.chips = chips
    }

    private func boardSize(ins: Int, outs: Int, parts: Int) -> (Int, Int) {
        let rows = max(8, max(ins, outs) + 2)
        let cols = parts > 12 ? 17 : (parts > 6 ? 15 : 13)
        return (cols, rows)
    }

    func comb(_ id: Int, _ chapter: Int, _ title: String, _ brief: String, hint: String,
              ins: [String], outs: [String],
              palette: [PartKind], chipIds: [String] = [],
              unlocks: ChipUnlock? = nil,
              fn: @escaping ([Bool]) -> [Bool],
              build: (NetBuilder) -> Void) -> LogicGateLevel {
        let b = NetBuilder(chips: chips)
        build(b)
        let partCount = b.net.parts.count
        let (cols, rows) = boardSize(ins: ins.count, outs: outs.count, parts: partCount)
        let reference = b.finish(cols: cols, rows: rows)
        let refCost = reference.cost(chips: chips)
        let optimal = refCost
        let par = refCost == 0 ? 6 : refCost + max(4, (refCost * 4) / 10)
        let level = LogicGateLevel(
            id: id, chapter: chapter, title: title, brief: brief, hint: hint,
            inputNames: ins, outputNames: outs,
            goal: .combinational(fn), palette: palette, chipPalette: chipIds,
            cols: cols, rows: rows,
            referenceSolution: reference, parCost: par, optimalCost: optimal,
            unlocksChip: unlocks?.id, vectors: Vectors.vectors(ins.count))
        if let u = unlocks {
            chips.register(ChipDefinition(id: u.id, name: u.name, inputNames: ins,
                                          outputNames: outs, netlist: reference,
                                          cost: refCost, sourceLevel: id, blurb: u.blurb))
        }
        return level
    }

    func seq(_ id: Int, _ chapter: Int, _ title: String, _ brief: String, hint: String,
             ins: [String], outs: [String],
             palette: [PartKind], chipIds: [String] = [],
             unlocks: ChipUnlock? = nil,
             steps: [SequentialStep],
             build: (NetBuilder) -> Void) -> LogicGateLevel {
        let b = NetBuilder(chips: chips)
        build(b)
        let partCount = b.net.parts.count
        let (cols, rows) = boardSize(ins: ins.count, outs: outs.count, parts: partCount)
        let reference = b.finish(cols: cols, rows: rows)
        let refCost = reference.cost(chips: chips)
        let optimal = refCost
        let par = refCost == 0 ? 6 : refCost + max(4, (refCost * 4) / 10)
        let level = LogicGateLevel(
            id: id, chapter: chapter, title: title, brief: brief, hint: hint,
            inputNames: ins, outputNames: outs,
            goal: .sequential(steps), palette: palette, chipPalette: chipIds,
            cols: cols, rows: rows,
            referenceSolution: reference, parCost: par, optimalCost: optimal,
            unlocksChip: unlocks?.id, vectors: [])
        if let u = unlocks {
            chips.register(ChipDefinition(id: u.id, name: u.name, inputNames: ins,
                                          outputNames: outs, netlist: reference,
                                          cost: refCost, sourceLevel: id, blurb: u.blurb))
        }
        return level
    }
}

// MARK: - Chapters

struct ChapterInfo: Identifiable {
    let id: Int
    let name: String
    let subtitle: String
    let range: ClosedRange<Int>
}

/// The whole content pack: 80 levels, 14 chips, 7 chapters.
final class LogicGateContent {
    static let shared = LogicGateContent()

    let chips = ChipCatalog()
    let levels: [LogicGateLevel]
    let chapters: [ChapterInfo] = [
        ChapterInfo(id: 1, name: "Signals", subtitle: "Switches, lamps and the first gates",
                    range: 1...10),
        ChapterInfo(id: 2, name: "Boolean Laws", subtitle: "Universality, De Morgan, simplification",
                    range: 11...22),
        ChapterInfo(id: 3, name: "Arithmetic", subtitle: "Adders, complements, subtraction",
                    range: 23...35),
        ChapterInfo(id: 4, name: "Routing", subtitle: "Multiplexers, decoders, encoders",
                    range: 36...48),
        ChapterInfo(id: 5, name: "Comparison", subtitle: "Equality, magnitude, selectors",
                    range: 49...58),
        ChapterInfo(id: 6, name: "Memory", subtitle: "Latches, flip-flops, counters",
                    range: 59...70),
        ChapterInfo(id: 7, name: "The Machine", subtitle: "Displays, flags and the ALU",
                    range: 71...80)
    ]

    private init() {
        let maker = LevelMaker(chips: chips)
        var all: [LogicGateLevel] = []
        all += maker.chapterSignals()
        all += maker.chapterBooleanLaws()
        all += maker.chapterArithmetic()
        all += maker.chapterRouting()
        all += maker.chapterComparison()
        all += maker.chapterMemory()
        all += maker.chapterMachine()
        levels = all
    }

    func level(_ id: Int) -> LogicGateLevel? {
        guard id >= 1, id <= levels.count else { return nil }
        return levels[id - 1]
    }

    func chapter(_ id: Int) -> ChapterInfo? { chapters.first(where: { $0.id == id }) }

    func levels(inChapter c: Int) -> [LogicGateLevel] { levels.filter { $0.chapter == c } }
}
