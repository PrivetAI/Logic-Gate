import SwiftUI

struct SandboxView: View {
    @EnvironmentObject var store: LogicGateStore
    @StateObject private var vm: BenchViewModel
    @State private var showSlots = false
    @State private var showTiming = false
    @State private var renaming: Int? = nil
    @State private var draftName = ""
    @State private var dashPhase: CGFloat = 0
    /// Landscape and very short screens drop the brief line and shrink the palette so the
    /// board never has to collapse. Read from the real screen, which rotates with the UI.
    private var compact: Bool { UIScreen.main.bounds.height < 500 }
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var nameFocused: Bool

    let onExit: () -> Void

    static func makeLevel(unlockedChips: [String]) -> LogicGateLevel {
        LogicGateLevel(
            id: 0, chapter: 0, title: "Sandbox",
            brief: "A free bench with every part you have unlocked. Nothing is verified here.",
            hint: "", inputNames: ["A", "B", "C", "D", "E", "F"],
            outputNames: ["W", "X", "Y", "Z", "P", "Q"],
            goal: .combinational { _ in Array(repeating: false, count: 6) },
            palette: Palettes.everything, chipPalette: unlockedChips,
            cols: 18, rows: 12,
            referenceSolution: Netlist(), parCost: 0, optimalCost: 0,
            unlocksChip: nil, vectors: [])
    }

    static let autosaveKey = "sandbox"

    init(store: LogicGateStore, onExit: @escaping () -> Void) {
        self.onExit = onExit
        let level = SandboxView.makeLevel(unlockedChips: store.progress.unlockedChips)
        var start = level.startingBoard
        if let saved = store.progress.boards[SandboxView.autosaveKey],
           saved.terminals(.inputSwitch).count == level.inputNames.count,
           saved.terminals(.outputLamp).count == level.outputNames.count {
            start = saved
        }
        _vm = StateObject(wrappedValue: BenchViewModel(level: level,
                                                       board: start,
                                                       chips: store.chips,
                                                       settings: store.progress.settings,
                                                       isSandbox: true))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Bench.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    header
                    toolbar
                    boardArea
                    palette
                }

                if showSlots {
                    Color.black.opacity(0.45).ignoresSafeArea()
                        .onTapGesture { showSlots = false }
                    slotPanel
                        .frame(maxHeight: min(430, max(200, proxy.size.height - 70)))
                        .background(Bench.surface)
                        .overlay(Rectangle().fill(Bench.stroke).frame(height: 1), alignment: .top)
                } else if showTiming {
                    Color.black.opacity(0.45).ignoresSafeArea()
                        .onTapGesture { showTiming = false }
                    TimingDiagramView(vm: vm) { showTiming = false }
                        .frame(maxHeight: min(400, max(200, proxy.size.height - 70)))
                        .background(Bench.surface)
                        .overlay(Rectangle().fill(Bench.stroke).frame(height: 1), alignment: .top)
                }

                if let index = renaming {
                    renamePanel(index)
                }
            }
        }
        .onAppear { vm.updateSettings(store.progress.settings) }
        .onChange(of: vm.values.status) { status in
            if status == .oscillating {
                dashPhase = 0
                withAnimation(Animation.linear(duration: 0.6).repeatForever(autoreverses: false)) {
                    dashPhase = 18
                }
            } else {
                withAnimation(.linear(duration: 0)) { dashPhase = 0 }
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active { autosave() }
        }
        .onDisappear { autosave() }
    }

    private func autosave() {
        let net = vm.board
        DispatchQueue.main.async {
            store.progress.boards[SandboxView.autosaveKey] = net
            store.saveNow()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button(action: onExit) {
                HStack(spacing: 4) {
                    ChevronShape()
                        .stroke(Bench.copper, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(180))
                        .frame(width: 12, height: 14)
                    Text("More")
                        .font(Bench.label(12, .semibold))
                        .foregroundColor(Bench.copper)
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            VStack(alignment: .leading, spacing: 1) {
                Text("SANDBOX")
                    .font(Bench.mono(9, .bold))
                    .foregroundColor(Bench.textFaint)
                Text("Free bench")
                    .font(Bench.label(16, .bold))
                    .foregroundColor(Bench.text)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 1) {
                Text("COST \(vm.cost)")
                    .font(Bench.mono(13, .bold))
                    .foregroundColor(Bench.copper)
                Text("\(vm.board.partCount) parts")
                    .font(Bench.mono(9, .regular))
                    .foregroundColor(Bench.textFaint)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private var toolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                    BenchButton(title: "Slots", glyph: .slots, tint: Bench.copper,
                                filled: true, compact: true) {
                        showSlots = true
                    }
                    BenchButton(title: "Pulse", glyph: .clock, tint: Bench.high, compact: true) {
                        vm.pulseClock()
                    }
                    BenchButton(title: "Reset", glyph: .reset, tint: Bench.text, compact: true) {
                        vm.resetSimulation()
                    }
                    BenchButton(title: "Timing", glyph: .timing, tint: Bench.text, compact: true) {
                        showSlots = false
                        showTiming = true
                    }
                    BenchButton(title: "Undo", glyph: .undo, tint: Bench.text,
                                compact: true, enabled: vm.canUndo) {
                        vm.undo()
                    }
                    if vm.selection != nil {
                        BenchButton(title: "Delete", glyph: .trash, tint: Bench.bad, compact: true) {
                            vm.deleteSelection()
                        }
                    }
                    BenchButton(title: "Clear", glyph: .cross, tint: Bench.textDim, compact: true) {
                        vm.clearBoard(to: vm.level.startingBoard)
                    }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
    }

    private var boardArea: some View {
        GeometryReader { proxy in
            let w = benchUsableWidth(proxy.size.width) - 12
            let h = max(80, proxy.size.height - 8)
            let geo = BoardGeometry(cols: vm.level.cols, rows: vm.level.rows,
                                    size: CGSize(width: w, height: h))
            let layout = BoardLayout(netlist: vm.board, chips: vm.chips, geo: geo)
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                BoardCanvas(layout: layout, values: vm.values, selection: vm.selection,
                            showPinLabels: store.progress.settings.showPinLabels,
                            orthogonal: store.progress.settings.orthogonalWires,
                            showGrid: true,
                            pendingWire: vm.pendingWire.map { ($0.from, $0.to) },
                            dashPhase: dashPhase,
                            inputTerminalNames: vm.level.inputNames,
                            outputTerminalNames: vm.level.outputNames)
                    .frame(width: w, height: h)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { v in
                                vm.dragChanged(start: v.startLocation, current: v.location,
                                               layout: layout)
                            }
                            .onEnded { v in
                                vm.dragEnded(start: v.startLocation, end: v.location,
                                             layout: layout)
                            }
                    )
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var palette: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Bench.stroke).frame(height: 1)
            HStack {
                Text(vm.pending == nil ? "TAP A PART, THEN TAP THE BOARD"
                                       : "PLACING: \(vm.pending!.name.uppercased())")
                    .font(Bench.mono(9, .bold))
                    .foregroundColor(vm.pending == nil ? Bench.textFaint : Bench.high)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 6)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(vm.paletteItems) { item in
                        let selected = vm.pending?.id == item.id
                        Button(action: {
                            vm.pending = selected ? nil : item
                            vm.selection = nil
                            BenchFeedback.tap(store.progress.settings)
                        }) {
                            VStack(spacing: 3) {
                                PartGlyphView(kind: item.kind, chip: item.chip,
                                              tint: selected ? Bench.high : Bench.copper)
                                    .frame(width: 46, height: compact ? 22 : 30)
                                Text(item.chip?.name ?? item.kind.shortName)
                                    .font(Bench.mono(8, .bold))
                                    .foregroundColor(selected ? Bench.high : Bench.textDim)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
                            .frame(width: 62, height: compact ? 40 : 54)
                            .padding(4)
                            .background(
                                RoundedRectangle(cornerRadius: 9)
                                    .fill(selected ? Bench.surfaceHigh : Bench.background)
                                    .overlay(RoundedRectangle(cornerRadius: 9)
                                        .stroke(selected ? Bench.high : Bench.stroke, lineWidth: 1))
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
        }
        .background(Bench.surface)
    }

    // MARK: - Slots

    private var slotPanel: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Save Slots")
                        .font(Bench.label(15, .bold))
                        .foregroundColor(Bench.text)
                    Text("\(store.progress.slots.filter { $0.used }.count) of \(LogicGateProgress.slotCount) used")
                        .font(Bench.label(11, .regular))
                        .foregroundColor(Bench.textDim)
                }
                Spacer()
                Button(action: { showSlots = false }) {
                    GlyphView(glyph: .close, color: Bench.textDim)
                        .frame(width: 18, height: 18).padding(8).contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)
            Rectangle().fill(Bench.stroke).frame(height: 1)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(store.progress.slots) { slot in
                        slotRow(slot)
                    }
                }
                .padding(14)
            }
        }
    }

    private func slotRow(_ slot: SandboxSlot) -> some View {
        BenchCard(padding: 10) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(String(format: "%02d", slot.id + 1))
                        .font(Bench.mono(11, .bold))
                        .foregroundColor(Bench.textFaint)
                    Text(slot.used ? (slot.name.isEmpty ? "Untitled circuit" : slot.name) : "Empty")
                        .font(Bench.label(13, .semibold))
                        .foregroundColor(slot.used ? Bench.text : Bench.textFaint)
                    Spacer(minLength: 0)
                    if slot.used {
                        Text("\(slot.netlist.partCount) parts \u{00B7} cost \(slot.netlist.cost(chips: store.chips))")
                            .font(Bench.mono(9, .regular))
                            .foregroundColor(Bench.textFaint)
                    }
                }
                HStack(spacing: 6) {
                    BenchButton(title: "Save here", glyph: .save, tint: Bench.copper, compact: true) {
                        let name = slot.name.isEmpty ? "Circuit \(slot.id + 1)" : slot.name
                        store.saveSlot(slot.id, name: name, netlist: vm.board)
                        BenchFeedback.tap(store.progress.settings)
                        showSlots = false
                    }
                    if slot.used {
                        BenchButton(title: "Load", glyph: .verify, tint: Bench.good, compact: true) {
                            vm.clearBoard(to: slot.netlist)
                            BenchFeedback.tap(store.progress.settings)
                            showSlots = false
                        }
                        BenchButton(title: "Rename", glyph: .pencil, tint: Bench.text, compact: true) {
                            draftName = slot.name
                            renaming = slot.id
                        }
                        BenchButton(title: "Erase", glyph: .trash, tint: Bench.bad, compact: true) {
                            store.clearSlot(slot.id)
                        }
                    }
                }
            }
        }
    }

    private func renamePanel(_ index: Int) -> some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
                .onTapGesture { renaming = nil }
            VStack(alignment: .leading, spacing: 12) {
                Text("Rename slot \(index + 1)")
                    .font(Bench.label(15, .bold))
                    .foregroundColor(Bench.text)
                TextField("", text: $draftName)
                    .font(Bench.label(14, .regular))
                    .foregroundColor(Bench.text)
                    .accentColor(Bench.copper)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Bench.background))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Bench.stroke, lineWidth: 1))
                    .focused($nameFocused)
                    .onTapGesture { nameFocused = true }
                HStack(spacing: 8) {
                    BenchButton(title: "Save", tint: Bench.copper, filled: true, compact: true) {
                        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                        store.renameSlot(index, to: trimmed.isEmpty ? "Circuit \(index + 1)" : trimmed)
                        nameFocused = false
                        renaming = nil
                    }
                    BenchButton(title: "Cancel", tint: Bench.textDim, compact: true) {
                        nameFocused = false
                        renaming = nil
                    }
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 14).fill(Bench.surface))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Bench.stroke, lineWidth: 1))
            .padding(.horizontal, 28)
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { nameFocused = true } }
    }
}
