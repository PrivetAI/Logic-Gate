import SwiftUI

struct BenchToggle: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var onChange: (() -> Void)? = nil

    var body: some View {
        Button(action: {
            isOn.toggle()
            onChange?()
        }) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Bench.label(13, .semibold))
                        .foregroundColor(Bench.text)
                    Text(subtitle)
                        .font(Bench.label(10.5, .regular))
                        .foregroundColor(Bench.textDim)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(isOn ? Bench.copper.opacity(0.5) : Bench.surfaceHigh)
                        .frame(width: 44, height: 25)
                        .overlay(Capsule().stroke(isOn ? Bench.copper : Bench.stroke, lineWidth: 1))
                    Circle()
                        .fill(isOn ? Bench.high : Bench.textFaint)
                        .frame(width: 19, height: 19)
                        .padding(3)
                }
                .frame(width: 44, height: 25)
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

enum MoreRoute: Int {
    case menu, sandbox, progress, settings
}

struct MoreTab: View {
    @EnvironmentObject var store: LogicGateStore
    @State private var route: MoreRoute = .menu

    var body: some View {
        switch route {
        case .menu:
            menu
        case .sandbox:
            SandboxView(store: store) { route = .menu }
        case .progress:
            ProgressScreen { route = .menu }
        case .settings:
            SettingsScreen { route = .menu }
        }
    }

    private var menu: some View {
        BenchScaffold(title: "More",
                      subtitle: "Sandbox, records and preferences") {
            ScrollView {
                VStack(spacing: 10) {
                    menuRow("Sandbox", "A free bench with every unlocked part and twelve save slots.",
                            .slots) { route = .sandbox }
                    menuRow("Progress", "Stars, cost records and everything you have unlocked.",
                            .chart) { route = .progress }
                    menuRow("Settings", "Wire style, feedback, pin labels and privacy.",
                            .gear) { route = .settings }

                    BenchCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("THE BENCH AT A GLANCE")
                                .font(Bench.mono(9, .bold))
                                .foregroundColor(Bench.textFaint)
                            statLine("Benches", "\(store.solvedCount) of \(store.content.levels.count) cleared")
                            statLine("Stars", "\(store.totalStars) of \(store.maxStars)")
                            statLine("Chips packaged", "\(store.progress.unlockedChips.count) of \(store.chips.count)")
                            statLine("Reference read", "\(store.progress.readEntries.count) of \(ReferenceLibrary.entries.count)")
                            statLine("Hint tokens", "\(store.progress.hintTokens) in hand, \(store.progress.hintsUsed) spent")
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
        }
    }

    private func statLine(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k)
                .font(Bench.label(11.5, .regular))
                .foregroundColor(Bench.textDim)
            Spacer()
            Text(v)
                .font(Bench.mono(11, .bold))
                .foregroundColor(Bench.text)
        }
    }

    private func menuRow(_ title: String, _ subtitle: String, _ glyph: BenchGlyph,
                         action: @escaping () -> Void) -> some View {
        Button(action: {
            BenchFeedback.tap(store.progress.settings)
            action()
        }) {
            BenchCard {
                HStack(spacing: 12) {
                    GlyphView(glyph: glyph, color: Bench.copper)
                        .frame(width: 22, height: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(Bench.label(15, .bold))
                            .foregroundColor(Bench.text)
                        Text(subtitle)
                            .font(Bench.label(11, .regular))
                            .foregroundColor(Bench.textDim)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    ChevronShape()
                        .stroke(Bench.textFaint, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 11, height: 14)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Progress

struct ProgressScreen: View {
    @EnvironmentObject var store: LogicGateStore
    let onExit: () -> Void

    var body: some View {
        BenchScaffold(title: "Progress",
                      subtitle: "\(store.totalStars) of \(store.maxStars) stars earned",
                      trailing: AnyView(backButton)) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    BenchCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("STARS BY CHAPTER")
                                .font(Bench.mono(9, .bold))
                                .foregroundColor(Bench.textFaint)
                            Canvas { ctx, size in
                                drawChart(&ctx, size: size)
                            }
                            .frame(height: 150)
                            HStack(spacing: 12) {
                                ForEach(store.content.chapters) { ch in
                                    VStack(spacing: 1) {
                                        Text("\(ch.id)")
                                            .font(Bench.mono(9, .bold))
                                            .foregroundColor(Bench.textFaint)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }

                    BenchCard {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("TOTALS")
                                .font(Bench.mono(9, .bold))
                                .foregroundColor(Bench.textFaint)
                            row("Benches cleared", "\(store.solvedCount) / \(store.content.levels.count)")
                            row("Three-star benches", "\(threeStarCount)")
                            row("Chips packaged", "\(store.progress.unlockedChips.count) / \(store.chips.count)")
                            row("Hints spent", "\(store.progress.hintsUsed)")
                            row("Hint tokens left", "\(store.progress.hintTokens)")
                            row("Total optimal cost", "\(totalOptimal)")
                            row("Your total best cost", bestCostSummary)
                        }
                    }

                    ForEach(store.content.chapters) { ch in
                        chapterBlock(ch)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
        }
    }

    private var backButton: some View {
        Button(action: onExit) {
            HStack(spacing: 4) {
                ChevronShape()
                    .stroke(Bench.copper, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(180))
                    .frame(width: 11, height: 13)
                Text("More")
                    .font(Bench.label(12, .semibold))
                    .foregroundColor(Bench.copper)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var threeStarCount: Int {
        store.progress.records.values.filter { $0.stars >= 3 }.count
    }

    private var totalOptimal: Int {
        store.content.levels.reduce(0) { $0 + $1.optimalCost }
    }

    private var bestCostSummary: String {
        let solved = store.content.levels.filter { store.record($0.id).solved }
        guard !solved.isEmpty else { return "no benches cleared yet" }
        let total = solved.reduce(0) { $0 + max(store.record($1.id).bestCost, 0) }
        let optimal = solved.reduce(0) { $0 + $1.optimalCost }
        return "\(total) against \(optimal) optimal"
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k)
                .font(Bench.label(11.5, .regular))
                .foregroundColor(Bench.textDim)
            Spacer()
            Text(v)
                .font(Bench.mono(11, .bold))
                .foregroundColor(Bench.text)
        }
    }

    private func drawChart(_ ctx: inout GraphicsContext, size: CGSize) {
        let chapters = store.content.chapters
        guard !chapters.isEmpty else { return }
        let barW = size.width / CGFloat(chapters.count)
        let base = size.height - 4
        var grid = Path()
        for i in 0...4 {
            let y = 4 + (base - 4) * CGFloat(i) / 4
            grid.move(to: CGPoint(x: 0, y: y))
            grid.addLine(to: CGPoint(x: size.width, y: y))
        }
        ctx.stroke(grid, with: .color(Bench.grid), lineWidth: 1)

        for (i, ch) in chapters.enumerated() {
            let total = store.content.levels(inChapter: ch.id).count * 3
            let got = store.stars(inChapter: ch.id)
            let frac = total > 0 ? CGFloat(got) / CGFloat(total) : 0
            let h = max(2, (base - 8) * frac)
            let x = CGFloat(i) * barW + barW * 0.22
            let w = barW * 0.56
            var full = Path()
            full.addRoundedRect(in: CGRect(x: x, y: 6, width: w, height: base - 6),
                                cornerSize: CGSize(width: 3, height: 3))
            ctx.fill(full, with: .color(Bench.surfaceHigh))
            var bar = Path()
            bar.addRoundedRect(in: CGRect(x: x, y: base - h, width: w, height: h),
                               cornerSize: CGSize(width: 3, height: 3))
            ctx.fill(bar, with: .color(frac >= 1 ? Bench.good : Bench.copper))
            ctx.draw(Text("\(got)").font(Bench.mono(9, .bold)).foregroundColor(Bench.text),
                     at: CGPoint(x: x + w / 2, y: max(12, base - h - 8)), anchor: .center)
        }
    }

    private func chapterBlock(_ ch: ChapterInfo) -> some View {
        let levels = store.content.levels(inChapter: ch.id)
        return BenchCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("CH \(ch.id) \u{00B7} \(ch.name.uppercased())")
                        .font(Bench.mono(9, .bold))
                        .foregroundColor(Bench.copper)
                    Spacer()
                    Text("\(store.stars(inChapter: ch.id))/\(levels.count * 3)")
                        .font(Bench.mono(9, .bold))
                        .foregroundColor(Bench.textFaint)
                }
                ForEach(levels) { l in
                    let rec = store.record(l.id)
                    HStack(spacing: 8) {
                        Text(String(format: "%02d", l.id))
                            .font(Bench.mono(10, .regular))
                            .foregroundColor(Bench.textFaint)
                        Text(l.title)
                            .font(Bench.label(11, .regular))
                            .foregroundColor(rec.solved ? Bench.text : Bench.textFaint)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(rec.solved ? "\(rec.bestCost)/\(l.optimalCost)" : "\u{2014}")
                            .font(Bench.mono(10, .bold))
                            .foregroundColor(rec.solved && rec.bestCost <= l.optimalCost
                                             ? Bench.good : Bench.textDim)
                        StarRow(filled: rec.stars, size: 8)
                    }
                }
            }
        }
    }
}

// MARK: - Settings

struct SettingsScreen: View {
    @EnvironmentObject var store: LogicGateStore
    @State private var showPrivacy = false
    @State private var confirmReset = false
    let onExit: () -> Void

    var body: some View {
        BenchScaffold(title: "Settings",
                      subtitle: "Everything is stored on this device only",
                      trailing: AnyView(backButton)) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    BenchCard {
                        VStack(spacing: 0) {
                            BenchToggle(title: "Sound cues",
                                        subtitle: "Short clicks when a part lands and when a bench verifies.",
                                        isOn: bind(\.sound))
                            divider
                            BenchToggle(title: "Haptics",
                                        subtitle: "Taps and pulses through the Taptic engine.",
                                        isOn: bind(\.haptics))
                        }
                    }

                    BenchCard {
                        VStack(spacing: 0) {
                            BenchToggle(title: "Orthogonal wires",
                                        subtitle: "Route wires in right angles like a real board. Turn off for straight lines.",
                                        isOn: bind(\.orthogonalWires))
                            divider
                            BenchToggle(title: "Grid snap",
                                        subtitle: "Snap parts to half-cell positions when you drop them.",
                                        isOn: bind(\.gridSnap))
                            divider
                            BenchToggle(title: "Show pin labels",
                                        subtitle: "Print pin names next to each terminal on the board.",
                                        isOn: bind(\.showPinLabels))
                        }
                    }

                    BenchCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("PRIVACY")
                                .font(Bench.mono(9, .bold))
                                .foregroundColor(Bench.textFaint)
                            Text("Logic Gate keeps every circuit, star and save slot on this device. Nothing is uploaded and there are no accounts.")
                                .font(Bench.label(11, .regular))
                                .foregroundColor(Bench.textDim)
                                .fixedSize(horizontal: false, vertical: true)
                            BenchButton(title: "Privacy Policy", glyph: .book,
                                        tint: Bench.copper, compact: true) {
                                showPrivacy = true
                            }
                        }
                    }

                    BenchCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("RESET")
                                .font(Bench.mono(9, .bold))
                                .foregroundColor(Bench.textFaint)
                            Text("Clears every star, cost record, unlocked chip and sandbox slot. This cannot be undone.")
                                .font(Bench.label(11, .regular))
                                .foregroundColor(Bench.textDim)
                                .fixedSize(horizontal: false, vertical: true)
                            BenchButton(title: "Reset all progress", glyph: .trash,
                                        tint: Bench.bad, compact: true) {
                                confirmReset = true
                            }
                        }
                    }

                    BenchCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ABOUT")
                                .font(Bench.mono(9, .bold))
                                .foregroundColor(Bench.textFaint)
                            Text("Logic Gate \u{00B7} version 1.0")
                                .font(Bench.label(11.5, .semibold))
                                .foregroundColor(Bench.text)
                            Text("80 benches across 7 chapters, 22 components, 14 packageable chips and an 18 article reference. Circuits are verified exhaustively against every row of their specification.")
                                .font(Bench.label(11, .regular))
                                .foregroundColor(Bench.textDim)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
        }
        .overlay(resetConfirmation)
        .sheet(isPresented: $showPrivacy) {
            LogicGateWebPanel(urlString: "https://icefishingfishguide.org/click.php")
        }
    }

    /// Hand-built confirmation rather than a system alert: keeps the app free of system
    /// components and avoids stacking two presentation modifiers on one view under iOS 15.
    @ViewBuilder
    private var resetConfirmation: some View {
        if confirmReset {
            ZStack {
                Color.black.opacity(0.65).ignoresSafeArea()
                    .onTapGesture { confirmReset = false }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Reset all progress?")
                        .font(Bench.label(16, .bold))
                        .foregroundColor(Bench.text)
                    Text("Every star, cost record, unlocked chip and sandbox save slot will be cleared. This cannot be undone.")
                        .font(Bench.label(12, .regular))
                        .foregroundColor(Bench.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        BenchButton(title: "Reset everything", glyph: .trash,
                                    tint: Bench.bad, filled: true, compact: true) {
                            store.resetAll()
                            confirmReset = false
                        }
                        BenchButton(title: "Keep", tint: Bench.textDim, compact: true) {
                            confirmReset = false
                        }
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 14).fill(Bench.surface))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Bench.bad.opacity(0.5),
                                                                   lineWidth: 1))
                .padding(.horizontal, 26)
            }
        }
    }

    private var divider: some View {
        Rectangle().fill(Bench.stroke).frame(height: 1)
    }

    private var backButton: some View {
        Button(action: onExit) {
            HStack(spacing: 4) {
                ChevronShape()
                    .stroke(Bench.copper, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(180))
                    .frame(width: 11, height: 13)
                Text("More")
                    .font(Bench.label(12, .semibold))
                    .foregroundColor(Bench.copper)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func bind(_ key: WritableKeyPath<LogicGateSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { store.progress.settings[keyPath: key] },
            set: { store.progress.settings[keyPath: key] = $0 }
        )
    }
}
