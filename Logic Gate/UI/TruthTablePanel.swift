import SwiftUI

/// Bit string with per-bit colouring so a wrong output digit stands out.
struct BitRow: View {
    let bits: [Bool]
    var reference: [Bool]? = nil
    var size: CGFloat = 11
    var onColor: Color = Bench.high
    var offColor: Color = Bench.textDim

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<bits.count, id: \.self) { i in
                let ok = reference == nil || (i < reference!.count && reference![i] == bits[i])
                Text(bits[i] ? "1" : "0")
                    .font(Bench.mono(size, .bold))
                    .foregroundColor(ok ? (bits[i] ? onColor : offColor) : Bench.bad)
                    .frame(width: size * 0.78)
            }
        }
    }
}

struct TruthTablePanel: View {
    @ObservedObject var vm: BenchViewModel
    let onClose: () -> Void

    private let displayLimit = 128

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.level.isSequential ? "Test Script" : "Truth Table")
                        .font(Bench.label(15, .bold))
                        .foregroundColor(Bench.text)
                    Text(subtitle)
                        .font(Bench.label(11, .regular))
                        .foregroundColor(Bench.textDim)
                }
                Spacer()
                Button(action: onClose) {
                    GlyphView(glyph: .close, color: Bench.textDim)
                        .frame(width: 18, height: 18)
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("IN  " + vm.level.inputNames.joined(separator: " "))
                        .font(Bench.mono(9, .medium))
                        .foregroundColor(Bench.textFaint)
                    Text("OUT " + vm.level.outputNames.joined(separator: " "))
                        .font(Bench.mono(9, .medium))
                        .foregroundColor(Bench.textFaint)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 6)

            Rectangle().fill(Bench.stroke).frame(height: 1)

            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 0) {
                    ForEach(0..<visibleCount, id: \.self) { i in
                        rowView(i)
                    }
                    if totalRows > visibleCount {
                        Text("Showing the first \(visibleCount) of \(totalRows) rows. Verification always checks every one.")
                            .font(Bench.label(10, .regular))
                            .foregroundColor(Bench.textFaint)
                            .multilineTextAlignment(.center)
                            .padding(14)
                    }
                }
            }
        }
        .background(Bench.surface)
    }

    private var totalRows: Int {
        if case .sequential(let steps) = vm.level.goal { return steps.count }
        return vm.level.vectors.count
    }

    private var visibleCount: Int { min(totalRows, displayLimit) }

    private var subtitle: String {
        if case .sequential(let steps) = vm.level.goal {
            return "\(steps.count) ordered steps. Tap a step to replay up to it."
        }
        return "\(vm.level.vectors.count) input combinations. Tap a row to apply it to the board."
    }

    @ViewBuilder
    private func rowView(_ i: Int) -> some View {
        let verdict = i < vm.verdicts.count ? vm.verdicts[i] : VerdictRow.untested
        let isActive = vm.activeRow == i
        Button(action: { vm.applyRow(i) }) {
            HStack(spacing: 8) {
                Text(String(format: "%3d", i + 1))
                    .font(Bench.mono(10, .regular))
                    .foregroundColor(Bench.textFaint)
                if case .sequential(let steps) = vm.level.goal {
                    let s = steps[i]
                    BitRow(bits: s.inputs)
                    Text("\u{2192}").font(Bench.mono(10)).foregroundColor(Bench.textFaint)
                    BitRow(bits: s.expected, onColor: Bench.good, offColor: Bench.textFaint)
                    Text(s.note)
                        .font(Bench.label(9, .regular))
                        .foregroundColor(Bench.textFaint)
                        .lineLimit(1)
                } else {
                    let v = vm.level.vectors[i]
                    BitRow(bits: v)
                    Text("\u{2192}").font(Bench.mono(10)).foregroundColor(Bench.textFaint)
                    BitRow(bits: vm.level.expectedOutputs(for: v),
                           onColor: Bench.good, offColor: Bench.textFaint)
                }
                Spacer(minLength: 4)
                verdictPip(verdict)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isActive ? Bench.surfaceHigh : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private func verdictPip(_ v: VerdictRow) -> some View {
        Circle()
            .fill(v == .pass ? Bench.good : (v == .fail ? Bench.bad : Bench.textFaint.opacity(0.4)))
            .frame(width: 8, height: 8)
    }
}
