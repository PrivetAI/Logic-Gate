import SwiftUI

/// Large DIP pin-out drawing for the chip detail screen.
struct ChipPinoutView: View {
    let def: ChipDefinition
    var height: CGFloat = 190

    var body: some View {
        GeometryReader { proxy in
            let w = benchUsableWidth(proxy.size.width)
            Canvas { ctx, _ in
                let n = max(def.inputNames.count, def.outputNames.count, 1)
                let bodyH = min(height - 24, CGFloat(n) * 22 + 24)
                let bodyW = min(w * 0.5, 170)
                let r = CGRect(x: (w - bodyW) / 2, y: (height - bodyH) / 2,
                               width: bodyW, height: bodyH)
                var body = Path()
                body.addRoundedRect(in: r, cornerSize: CGSize(width: 10, height: 10))
                ctx.fill(body, with: .color(Bench.surfaceHigh))
                ctx.stroke(body, with: .color(Bench.copper), lineWidth: 2)
                var notch = Path()
                notch.addArc(center: CGPoint(x: r.midX, y: r.minY), radius: 10,
                             startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
                ctx.stroke(notch, with: .color(Bench.copper), lineWidth: 1.6)
                ctx.draw(Text(def.name).font(Bench.mono(12, .bold)).foregroundColor(Bench.text),
                         at: CGPoint(x: r.midX, y: r.midY - 8), anchor: .center)
                ctx.draw(Text("cost \(def.cost)").font(Bench.mono(9, .regular))
                            .foregroundColor(Bench.textFaint),
                         at: CGPoint(x: r.midX, y: r.midY + 10), anchor: .center)

                func drawSide(_ names: [String], isOutput: Bool) {
                    guard !names.isEmpty else { return }
                    for (i, name) in names.enumerated() {
                        let p = GateArt.pinPoint(rect: r, index: i, count: names.count,
                                                 isOutput: isOutput)
                        var lead = Path()
                        let tip = isOutput ? p.x + 26 : p.x - 26
                        lead.move(to: p)
                        lead.addLine(to: CGPoint(x: tip, y: p.y))
                        ctx.stroke(lead, with: .color(Bench.wireLow), lineWidth: 2)
                        var dot = Path()
                        dot.addEllipse(in: CGRect(x: p.x - 3.5, y: p.y - 3.5, width: 7, height: 7))
                        ctx.fill(dot, with: .color(Bench.copper))
                        ctx.draw(Text(name).font(Bench.mono(9, .medium))
                                    .foregroundColor(Bench.textDim),
                                 at: CGPoint(x: isOutput ? tip + 3 : tip - 3, y: p.y),
                                 anchor: isOutput ? .leading : .trailing)
                    }
                }
                drawSide(def.inputNames, isOutput: false)
                drawSide(def.outputNames, isOutput: true)
            }
            .frame(width: w, height: height)
        }
        .frame(height: height)
    }
}

struct ChipLibraryTab: View {
    @EnvironmentObject var store: LogicGateStore
    @State private var openChip: String? = nil
    @State private var showInternals = false

    var body: some View {
        Group {
            if let id = openChip, let def = store.chips.definition(id) {
                detail(def)
            } else {
                list
            }
        }
    }

    private var list: some View {
        BenchScaffold(title: "Chip Library",
                      subtitle: "\(store.progress.unlockedChips.count) of \(store.chips.count) packaged and ready to place") {
            ScrollView {
                VStack(spacing: 10) {
                    Text("Every solved bench can be sealed into a chip. Its cost equals the reference circuit inside it, so a chip is never cheaper than building it yourself \u{2014} it is only faster.")
                        .font(Bench.label(11, .regular))
                        .foregroundColor(Bench.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 2)
                    ForEach(store.chips.ordered, id: \.id) { def in
                        chipRow(def)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
        }
    }

    private func chipRow(_ def: ChipDefinition) -> some View {
        let unlocked = store.chipUnlocked(def.id)
        return Button(action: {
            if unlocked {
                BenchFeedback.tap(store.progress.settings)
                showInternals = false
                openChip = def.id
            }
        }) {
            BenchCard {
                HStack(spacing: 12) {
                    if unlocked {
                        PartGlyphView(kind: .chip, chip: def, tint: Bench.copper)
                            .frame(width: 54, height: 44)
                    } else {
                        LockShape()
                            .stroke(Bench.textFaint, lineWidth: 1.6)
                            .frame(width: 20, height: 24)
                            .frame(width: 54, height: 44)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(def.name)
                            .font(Bench.label(14, .bold))
                            .foregroundColor(unlocked ? Bench.text : Bench.textFaint)
                        Text(unlocked ? def.blurb : "Locked \u{2014} clear level \(def.sourceLevel) to package this chip.")
                            .font(Bench.label(10.5, .regular))
                            .foregroundColor(Bench.textDim)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        HStack(spacing: 10) {
                            Text("COST \(def.cost)")
                                .font(Bench.mono(9, .bold))
                                .foregroundColor(Bench.copper)
                            Text("\(def.inputNames.count) IN \u{00B7} \(def.outputNames.count) OUT")
                                .font(Bench.mono(9, .regular))
                                .foregroundColor(Bench.textFaint)
                            Text("L\(def.sourceLevel)")
                                .font(Bench.mono(9, .regular))
                                .foregroundColor(Bench.textFaint)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .opacity(unlocked ? 1 : 0.55)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func detail(_ def: ChipDefinition) -> some View {
        let source = store.content.level(def.sourceLevel)
        return BenchScaffold(title: def.name,
                             subtitle: "From level \(def.sourceLevel) \u{00B7} cost \(def.cost)",
                             trailing: AnyView(
                                Button(action: { openChip = nil }) {
                                    HStack(spacing: 4) {
                                        ChevronShape()
                                            .stroke(Bench.copper,
                                                    style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                            .rotationEffect(.degrees(180))
                                            .frame(width: 11, height: 13)
                                        Text("Library")
                                            .font(Bench.label(12, .semibold))
                                            .foregroundColor(Bench.copper)
                                    }
                                    .padding(.vertical, 6)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())
                             )) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(def.blurb)
                        .font(Bench.label(12.5, .regular))
                        .foregroundColor(Bench.textDim)
                        .fixedSize(horizontal: false, vertical: true)

                    BenchCard(padding: 6) {
                        ChipPinoutView(def: def, height: CGFloat(max(def.inputNames.count,
                                                                    def.outputNames.count)) * 24 + 70)
                    }

                    HStack(spacing: 8) {
                        BenchButton(title: showInternals ? "Hide internals" : "View internals",
                                    glyph: .chip, tint: Bench.copper, compact: true) {
                            showInternals.toggle()
                        }
                        if let s = source {
                            Text("\(s.title)")
                                .font(Bench.label(11, .regular))
                                .foregroundColor(Bench.textFaint)
                        }
                    }

                    if showInternals {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("INTERNAL NETLIST \u{00B7} READ ONLY")
                                .font(Bench.mono(9, .bold))
                                .foregroundColor(Bench.textFaint)
                            BoardPreview(netlist: def.netlist, chips: store.chips,
                                         cols: source?.cols ?? 16, rows: source?.rows ?? 10,
                                         height: 210, showPinLabels: true)
                            Text("Chips are simulated by running this circuit inside the parent board. Nesting is capped at \(CircuitSimulator.maxChipDepth) levels deep.")
                                .font(Bench.label(10, .regular))
                                .foregroundColor(Bench.textFaint)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    BenchCard {
                        VStack(alignment: .leading, spacing: 6) {
                            pinList("INPUTS", def.inputNames)
                            pinList("OUTPUTS", def.outputNames)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
        }
    }

    private func pinList(_ title: String, _ names: [String]) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title)
                .font(Bench.mono(9, .bold))
                .foregroundColor(Bench.textFaint)
                .frame(width: 68, alignment: .leading)
            Text(names.joined(separator: "  "))
                .font(Bench.mono(11, .medium))
                .foregroundColor(Bench.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}
