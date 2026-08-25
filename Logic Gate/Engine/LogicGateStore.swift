import Foundation
import SwiftUI
import AudioToolbox

// MARK: - Saved shapes
// Every field decodes with `decodeIfPresent ?? default`, so adding a field in a future
// version can never throw and wipe a player's progress.

struct LevelRecord: Codable, Equatable {
    var solved: Bool
    var stars: Int
    var bestCost: Int      // -1 when never solved
    var attempts: Int
    var hintUsed: Bool

    init(solved: Bool = false, stars: Int = 0, bestCost: Int = -1,
         attempts: Int = 0, hintUsed: Bool = false) {
        self.solved = solved
        self.stars = stars
        self.bestCost = bestCost
        self.attempts = attempts
        self.hintUsed = hintUsed
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        solved = try c.decodeIfPresent(Bool.self, forKey: .solved) ?? false
        stars = try c.decodeIfPresent(Int.self, forKey: .stars) ?? 0
        bestCost = try c.decodeIfPresent(Int.self, forKey: .bestCost) ?? -1
        attempts = try c.decodeIfPresent(Int.self, forKey: .attempts) ?? 0
        hintUsed = try c.decodeIfPresent(Bool.self, forKey: .hintUsed) ?? false
    }
}

struct SandboxSlot: Codable, Equatable, Identifiable {
    var id: Int
    var name: String
    var used: Bool
    var netlist: Netlist
    var savedAt: Double

    init(id: Int, name: String = "", used: Bool = false,
         netlist: Netlist = Netlist(), savedAt: Double = 0) {
        self.id = id
        self.name = name
        self.used = used
        self.netlist = netlist
        self.savedAt = savedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        used = try c.decodeIfPresent(Bool.self, forKey: .used) ?? false
        netlist = try c.decodeIfPresent(Netlist.self, forKey: .netlist) ?? Netlist()
        savedAt = try c.decodeIfPresent(Double.self, forKey: .savedAt) ?? 0
    }
}

struct LogicGateSettings: Codable, Equatable {
    var sound: Bool
    var haptics: Bool
    var orthogonalWires: Bool
    var gridSnap: Bool
    var showPinLabels: Bool

    init(sound: Bool = true, haptics: Bool = true, orthogonalWires: Bool = true,
         gridSnap: Bool = true, showPinLabels: Bool = true) {
        self.sound = sound
        self.haptics = haptics
        self.orthogonalWires = orthogonalWires
        self.gridSnap = gridSnap
        self.showPinLabels = showPinLabels
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sound = try c.decodeIfPresent(Bool.self, forKey: .sound) ?? true
        haptics = try c.decodeIfPresent(Bool.self, forKey: .haptics) ?? true
        orthogonalWires = try c.decodeIfPresent(Bool.self, forKey: .orthogonalWires) ?? true
        gridSnap = try c.decodeIfPresent(Bool.self, forKey: .gridSnap) ?? true
        showPinLabels = try c.decodeIfPresent(Bool.self, forKey: .showPinLabels) ?? true
    }
}

struct LogicGateProgress: Codable, Equatable {
    var records: [String: LevelRecord]
    var boards: [String: Netlist]
    var unlockedChips: [String]
    var slots: [SandboxSlot]
    var readEntries: [String]
    var hintTokens: Int
    var hintsUsed: Int
    var lastLevel: Int
    var settings: LogicGateSettings

    static let slotCount = 12

    init() {
        records = [:]
        boards = [:]
        unlockedChips = []
        slots = (0..<LogicGateProgress.slotCount).map { SandboxSlot(id: $0) }
        readEntries = []
        hintTokens = 3
        hintsUsed = 0
        lastLevel = 1
        settings = LogicGateSettings()
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        records = try c.decodeIfPresent([String: LevelRecord].self, forKey: .records) ?? [:]
        boards = try c.decodeIfPresent([String: Netlist].self, forKey: .boards) ?? [:]
        unlockedChips = try c.decodeIfPresent([String].self, forKey: .unlockedChips) ?? []
        var loaded = try c.decodeIfPresent([SandboxSlot].self, forKey: .slots) ?? []
        while loaded.count < LogicGateProgress.slotCount {
            loaded.append(SandboxSlot(id: loaded.count))
        }
        if loaded.count > LogicGateProgress.slotCount {
            loaded = Array(loaded.prefix(LogicGateProgress.slotCount))
        }
        slots = loaded
        readEntries = try c.decodeIfPresent([String].self, forKey: .readEntries) ?? []
        hintTokens = try c.decodeIfPresent(Int.self, forKey: .hintTokens) ?? 3
        hintsUsed = try c.decodeIfPresent(Int.self, forKey: .hintsUsed) ?? 0
        lastLevel = try c.decodeIfPresent(Int.self, forKey: .lastLevel) ?? 1
        settings = try c.decodeIfPresent(LogicGateSettings.self, forKey: .settings) ?? LogicGateSettings()
    }
}

// MARK: - Store

final class LogicGateStore: ObservableObject {
    static let storageKey = "lgw.state.v1"

    @Published var progress: LogicGateProgress {
        didSet { scheduleSave() }
    }

    let content = LogicGateContent.shared
    var chips: ChipCatalog { content.chips }

    private var saveScheduled = false

    init() {
        if let data = UserDefaults.standard.data(forKey: LogicGateStore.storageKey),
           let decoded = try? JSONDecoder().decode(LogicGateProgress.self, from: data) {
            progress = decoded
        } else {
            progress = LogicGateProgress()
        }
    }

    // MARK: persistence

    private func scheduleSave() {
        guard !saveScheduled else { return }
        saveScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.saveScheduled = false
            self?.saveNow()
        }
    }

    func saveNow() {
        if let data = try? JSONEncoder().encode(progress) {
            UserDefaults.standard.set(data, forKey: LogicGateStore.storageKey)
        }
    }

    func resetAll() {
        progress = LogicGateProgress()
        saveNow()
    }

    // MARK: level state

    func record(_ levelId: Int) -> LevelRecord {
        progress.records["\(levelId)"] ?? LevelRecord()
    }

    func isUnlocked(_ levelId: Int) -> Bool {
        if levelId <= 1 { return true }
        return record(levelId - 1).solved
    }

    func board(for level: LogicGateLevel) -> Netlist {
        if let saved = progress.boards["\(level.id)"], !saved.parts.isEmpty {
            // Keep the level's own locked terminals authoritative in case a level ever changes.
            if saved.terminals(.inputSwitch).count == level.inputNames.count,
               saved.terminals(.outputLamp).count == level.outputNames.count {
                return saved
            }
        }
        return level.startingBoard
    }

    func storeBoard(_ net: Netlist, for levelId: Int) {
        progress.boards["\(levelId)"] = net
    }

    func clearBoard(for level: LogicGateLevel) {
        progress.boards["\(level.id)"] = level.startingBoard
    }

    /// Records a successful verification. Returns the star count awarded this run.
    @discardableResult
    func submit(level: LogicGateLevel, cost: Int, passed: Bool, usedHint: Bool) -> Int {
        var r = record(level.id)
        r.attempts += 1
        if usedHint { r.hintUsed = true }
        var stars = 0
        if passed {
            stars = 1
            if cost <= level.parCost { stars = 2 }
            if cost <= level.optimalCost { stars = 3 }
            let hadThree = r.stars >= 3
            r.solved = true
            r.stars = max(r.stars, stars)
            r.bestCost = r.bestCost < 0 ? cost : min(r.bestCost, cost)
            if !hadThree && r.stars >= 3 {
                progress.hintTokens += 1
            }
            if let chipId = level.unlocksChip, !progress.unlockedChips.contains(chipId) {
                progress.unlockedChips.append(chipId)
            }
        }
        progress.records["\(level.id)"] = r
        progress.lastLevel = level.id
        return stars
    }

    func spendHint(on levelId: Int) -> Bool {
        guard progress.hintTokens > 0 else { return false }
        progress.hintTokens -= 1
        progress.hintsUsed += 1
        var r = record(levelId)
        r.hintUsed = true
        progress.records["\(levelId)"] = r
        return true
    }

    // MARK: chips

    func chipUnlocked(_ id: String) -> Bool { progress.unlockedChips.contains(id) }

    var unlockedChipDefs: [ChipDefinition] {
        chips.ordered.filter { progress.unlockedChips.contains($0.id) }
    }

    // MARK: aggregate stats

    var totalStars: Int { progress.records.values.reduce(0) { $0 + $1.stars } }
    var maxStars: Int { content.levels.count * 3 }
    var solvedCount: Int { progress.records.values.filter { $0.solved }.count }

    func stars(inChapter c: Int) -> Int {
        content.levels(inChapter: c).reduce(0) { $0 + record($1.id).stars }
    }

    func solved(inChapter c: Int) -> Int {
        content.levels(inChapter: c).filter { record($0.id).solved }.count
    }

    func chapterUnlocked(_ c: Int) -> Bool {
        guard let info = content.chapter(c) else { return false }
        return isUnlocked(info.range.lowerBound)
    }

    /// Lowest unsolved level that is currently reachable.
    var nextLevel: LogicGateLevel {
        for l in content.levels where !record(l.id).solved && isUnlocked(l.id) {
            return l
        }
        return content.level(min(progress.lastLevel, content.levels.count)) ?? content.levels[0]
    }

    func markRead(_ entryId: String) {
        if !progress.readEntries.contains(entryId) {
            progress.readEntries.append(entryId)
        }
    }

    func isRead(_ entryId: String) -> Bool { progress.readEntries.contains(entryId) }

    // MARK: sandbox

    func saveSlot(_ index: Int, name: String, netlist: Netlist) {
        guard index >= 0, index < progress.slots.count else { return }
        progress.slots[index] = SandboxSlot(id: index, name: name, used: true,
                                            netlist: netlist,
                                            savedAt: Date().timeIntervalSince1970)
    }

    func clearSlot(_ index: Int) {
        guard index >= 0, index < progress.slots.count else { return }
        progress.slots[index] = SandboxSlot(id: index)
    }

    func renameSlot(_ index: Int, to name: String) {
        guard index >= 0, index < progress.slots.count else { return }
        progress.slots[index].name = name
    }
}

// MARK: - Feedback

enum BenchFeedback {
    static func tap(_ settings: LogicGateSettings) {
        if settings.haptics {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        if settings.sound { AudioServicesPlaySystemSound(1104) }
    }

    static func success(_ settings: LogicGateSettings) {
        if settings.haptics {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        if settings.sound { AudioServicesPlaySystemSound(1057) }
    }

    static func failure(_ settings: LogicGateSettings) {
        if settings.haptics {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
        if settings.sound { AudioServicesPlaySystemSound(1053) }
    }
}
