import SwiftUI

enum BenchPanel: Identifiable {
    case table, timing, hint, brief
    var id: Int {
        switch self {
        case .table: return 0
        case .timing: return 1
        case .hint: return 2
        case .brief: return 3
        }
    }
}

struct WorkbenchView: View {
    @EnvironmentObject var store: LogicGateStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var vm: BenchViewModel
    @State private var panel: BenchPanel? = nil
    @State private var dashPhase: CGFloat = 0
    /// Landscape and very short screens drop the brief line and shrink the palette so the
    /// board never has to collapse. Read from the real screen, which rotates with the UI.
    private var compact: Bool { UIScreen.main.bounds.height < 500 }

    let level: LogicGateLevel
    let onExit: () -> Void
    let onGoTo: (Int) -> Void

    init(level: LogicGateLevel, board: Netlist, chips: ChipCatalog,
         settings: LogicGateSettings,
         onExit: @escaping () -> Void, onGoTo: @escaping (Int) -> Void) {
        self.level = level
        self.onExit = onExit
        self.onGoTo = onGoTo
        _vm = StateObject(wrappedValue: BenchViewModel(level: level, board: board,
                                                       chips: chips, settings: settings))
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

                if let p = panel {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                        .onTapGesture { panel = nil }
                    panelContent(p)
                        .frame(maxHeight: min(420, max(200, proxy.size.height - 70)))
                        .background(Bench.surface)
                        .overlay(Rectangle().fill(Bench.stroke).frame(height: 1), alignment: .top)
                }
            }
        }
        .onAppear {
            vm.updateSettings(store.progress.settings)
        }
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
            if phase != .active {
                DispatchQueue.main.async {
                    vm.persist(store: store)
                    store.saveNow()
                }
            }
        }
        .onDisappear { DispatchQueue.main.async { vm.persist(store: store) } }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button(action: { vm.persist(store: store); onExit() }) {
                    HStack(spacing: 4) {
                        ChevronShape()
                            .stroke(Bench.copper, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .rotationEffect(.degrees(180))
                            .frame(width: 12, height: 14)
                        Text("Bench")
                            .font(Bench.label(12, .semibold))
                            .foregroundColor(Bench.copper)
                    }
                    .padding(.vertical, 6)
                    .padding(.trailing, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())

                VStack(alignment: .leading, spacing: 1) {
                    Text("LEVEL \(level.id)  \u{00B7}  CH \(level.chapter)")
                        .font(Bench.mono(9, .bold))
                        .foregroundColor(Bench.textFaint)
                    Text(level.title)
                        .font(Bench.label(16, .bold))
                        .foregroundColor(Bench.text)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("COST \(vm.cost)")
                        .font(Bench.mono(13, .bold))
                        .foregroundColor(costColor)
                    Text("par \(level.parCost) \u{00B7} opt \(level.optimalCost)")
                        .font(Bench.mono(9, .regular))
                        .foregroundColor(Bench.textFaint)
                }
            }
            .padding(.horizontal, 14)

            Button(action: { panel = .brief }) {
                HStack(alignment: .top, spacing: 8) {
                    Text(level.brief)
                        .font(Bench.label(11, .regular))
                        .foregroundColor(Bench.textDim)
                        .lineLimit(compact ? 1 : 2)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Text("MORE")
                        .font(Bench.mono(9, .bold))
                        .foregroundColor(Bench.copper)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, compact ? 4 : 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.top, compact ? 2 : 6)
        .background(Bench.background)
    }

    private var costColor: Color {
        if vm.cost <= level.optimalCost { return Bench.good }
        if vm.cost <= level.parCost { return Bench.high }
        return Bench.textDim
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                BenchButton(title: "Verify", glyph: .verify, tint: Bench.copper,
                            filled: true, compact: true) {
                    vm.verify(store: store)
                }
                BenchButton(title: "Step", glyph: .step, tint: Bench.text, compact: true) {
                    vm.stepTest()
                }
                BenchButton(title: "Reset", glyph: .reset, tint: Bench.text, compact: true) {
                    vm.resetSimulation()
                }
                BenchButton(title: "Table", glyph: .table, tint: Bench.text, compact: true) {
                    vm.refreshVerdicts()
                    panel = .table
                }
                if level.isSequential || hasClockPart {
                    BenchButton(title: "Timing", glyph: .timing, tint: Bench.text, compact: true) {
                        panel = .timing
                    }
                }
                if hasClockPart {
                    BenchButton(title: "Pulse", glyph: .clock, tint: Bench.high, compact: true) {
                        vm.pulseClock()
                    }
                }
                BenchButton(title: hintPaid ? "Hint" : "Hint (\(store.progress.hintTokens))",
                            glyph: .hint, tint: Bench.high, compact: true) {
                    if hintPaid {
                        vm.hintRevealed = true
                        panel = .hint
                    } else if store.spendHint(on: level.id) {
                        vm.hintRevealed = true
                        panel = .hint
                    } else {
                        vm.banner = BenchViewModel.BenchBanner(
                            title: "No hint tokens",
                            detail: "Earn one by finishing any level at three stars.",
                            stars: 0, good: false)
                    }
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
                    vm.clearBoard(to: level.startingBoard)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
        .background(Bench.background)
    }

    private var hasClockPart: Bool {
        vm.board.parts.contains { $0.kind == .clock }
    }

    /// A hint is bought once per level, not once per visit to the bench.
    private var hintPaid: Bool {
        vm.hintRevealed || store.record(level.id).hintUsed
    }

    // MARK: - Board

    private var boardArea: some View {
        GeometryReader { proxy in
            let w = benchUsableWidth(proxy.size.width) - 12
            let h = max(80, proxy.size.height - 8)
            let size = CGSize(width: w, height: h)
            let geo = BoardGeometry(cols: level.cols, rows: level.rows, size: size)
            let layout = BoardLayout(netlist: vm.board, chips: vm.chips, geo: geo)
            ZStack(alignment: .top) {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    BoardCanvas(layout: layout,
                                values: vm.values,
                                selection: vm.selection,
                                showPinLabels: store.progress.settings.showPinLabels,
                                orthogonal: store.progress.settings.orthogonalWires,
                                showGrid: true,
                                pendingWire: vm.pendingWire.map { ($0.from, $0.to) },
                                dashPhase: dashPhase,
                                inputTerminalNames: level.inputNames,
                                outputTerminalNames: level.outputNames)
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
                if vm.values.status == .oscillating {
                    Text("OSCILLATING \u{2014} the circuit never settles")
                        .font(Bench.mono(10, .bold))
                        .foregroundColor(Bench.background)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Bench.osc))
                        .padding(.top, 8)
                }
                if let b = vm.banner {
                    bannerView(b)
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func bannerView(_ b: BenchViewModel.BenchBanner) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                GlyphView(glyph: b.good ? .check : .cross,
                          color: b.good ? Bench.good : Bench.bad)
                    .frame(width: 16, height: 16)
                Text(b.title)
                    .font(Bench.label(14, .bold))
                    .foregroundColor(b.good ? Bench.good : Bench.bad)
                Spacer()
                if b.good { StarRow(filled: b.stars, size: 13) }
                Button(action: { vm.banner = nil }) {
                    GlyphView(glyph: .close, color: Bench.textDim)
                        .frame(width: 14, height: 14)
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            Text(b.detail)
                .font(Bench.label(11, .regular))
                .foregroundColor(Bench.textDim)
                .fixedSize(horizontal: false, vertical: true)
            if b.good && level.id < store.content.levels.count {
                HStack(spacing: 8) {
                    BenchButton(title: "Next level", glyph: .verify, tint: Bench.copper,
                                filled: true, compact: true) {
                        vm.persist(store: store)
                        onGoTo(level.id + 1)
                    }
                    BenchButton(title: "Keep tuning", tint: Bench.textDim, compact: true) {
                        vm.banner = nil
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Bench.surface)
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(b.good ? Bench.good.opacity(0.6) : Bench.bad.opacity(0.6), lineWidth: 1))
        )
    }

    // MARK: - Palette

    private var palette: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Bench.stroke).frame(height: 1)
            HStack(spacing: 6) {
                Text(vm.pending == nil ? "TAP A PART, THEN TAP THE BOARD"
                                       : "PLACING: \(vm.pending!.name.uppercased())")
                    .font(Bench.mono(9, .bold))
                    .foregroundColor(vm.pending == nil ? Bench.textFaint : Bench.high)
                Spacer()
                if let sel = vm.selection, let p = vm.board.part(sel) {
                    Text("SELECTED: \(partName(p).uppercased())")
                        .font(Bench.mono(9, .bold))
                        .foregroundColor(Bench.copper)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 6)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(vm.paletteItems) { item in
                        paletteButton(item)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
        }
        .background(Bench.surface)
    }

    private func partName(_ p: CircuitPart) -> String {
        if p.kind == .chip { return vm.chips.definition(p.chipId)?.name ?? "Chip" }
        return p.kind.displayName
    }

    private func paletteButton(_ item: PaletteItem) -> some View {
        let selected = vm.pending?.id == item.id
        return Button(action: {
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
                if !compact {
                    Text(item.cost == 0 ? "free" : "\(item.cost)")
                        .font(Bench.mono(8, .regular))
                        .foregroundColor(Bench.textFaint)
                }
            }
            .frame(width: 62, height: compact ? 42 : 62)
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

    // MARK: - Panels

    @ViewBuilder
    private func panelContent(_ p: BenchPanel) -> some View {
        switch p {
        case .table:
            TruthTablePanel(vm: vm) { panel = nil }
        case .timing:
            TimingDiagramView(vm: vm) { panel = nil }
        case .hint:
            hintPanel
        case .brief:
            briefPanel
        }
    }

    private var briefPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Level \(level.id) \u{00B7} \(level.title)")
                    .font(Bench.label(15, .bold))
                    .foregroundColor(Bench.text)
                Spacer()
                Button(action: { panel = nil }) {
                    GlyphView(glyph: .close, color: Bench.textDim)
                        .frame(width: 18, height: 18).padding(8).contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(level.brief)
                        .font(Bench.label(13, .regular))
                        .foregroundColor(Bench.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                    BenchCard {
                        VStack(alignment: .leading, spacing: 6) {
                            labelledRow("Inputs", level.inputNames.joined(separator: ", "))
                            labelledRow("Outputs", level.outputNames.joined(separator: ", "))
                            labelledRow("Rows checked", level.isSequential
                                        ? "\(sequentialStepCount) ordered steps"
                                        : "\(level.vectors.count) input combinations")
                            labelledRow("Par cost", "\(level.parCost) for two stars")
                            labelledRow("Optimal cost", "\(level.optimalCost) for three stars")
                        }
                    }
                }
                .padding(14)
            }
        }
    }

    private var sequentialStepCount: Int {
        if case .sequential(let s) = level.goal { return s.count }
        return 0
    }

    private func labelledRow(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(k.uppercased())
                .font(Bench.mono(9, .bold))
                .foregroundColor(Bench.textFaint)
                .frame(width: 96, alignment: .leading)
            Text(v)
                .font(Bench.label(11, .regular))
                .foregroundColor(Bench.text)
            Spacer(minLength: 0)
        }
    }

    private var hintPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Hint")
                    .font(Bench.label(15, .bold))
                    .foregroundColor(Bench.high)
                Spacer()
                Button(action: { panel = nil }) {
                    GlyphView(glyph: .close, color: Bench.textDim)
                        .frame(width: 18, height: 18).padding(8).contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(level.hint)
                        .font(Bench.label(13, .regular))
                        .foregroundColor(Bench.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("REFERENCE CIRCUIT \u{00B7} COST \(level.optimalCost)")
                        .font(Bench.mono(9, .bold))
                        .foregroundColor(Bench.textFaint)
                    BoardPreview(netlist: level.referenceSolution, chips: vm.chips,
                                 cols: level.cols, rows: level.rows, height: 180,
                                 showPinLabels: false)
                    Text("This is one solution that reaches three stars. You do not have to copy it.")
                        .font(Bench.label(10, .regular))
                        .foregroundColor(Bench.textFaint)
                }
                .padding(14)
            }
        }
    }
}
