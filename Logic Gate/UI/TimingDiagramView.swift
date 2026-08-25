import SwiftUI

/// Hand-drawn waveform of the last 32 recorded moments. No charting framework involved.
struct TimingDiagramView: View {
    @ObservedObject var vm: BenchViewModel
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Timing Diagram")
                        .font(Bench.label(15, .bold))
                        .foregroundColor(Bench.text)
                    Text(vm.timing.isEmpty
                         ? "Toggle a switch or step the test to record a trace."
                         : "Last \(vm.timing.count) recorded moments, oldest on the left.")
                        .font(Bench.label(11, .regular))
                        .foregroundColor(Bench.textDim)
                }
                Spacer()
                BenchButton(title: "Clear", tint: Bench.textDim, compact: true) {
                    vm.timing.removeAll()
                }
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

            Rectangle().fill(Bench.stroke).frame(height: 1)

            GeometryReader { proxy in
                let w = benchUsableWidth(proxy.size.width)
                let laneCount = max(1, vm.level.inputNames.count + vm.level.outputNames.count)
                let laneHeight: CGFloat = 26
                let contentHeight = CGFloat(laneCount) * laneHeight + 16
                ScrollView(.vertical, showsIndicators: true) {
                    Canvas { ctx, _ in
                        drawTrace(&ctx, width: w, laneHeight: laneHeight)
                    }
                    .frame(width: w, height: contentHeight)
                }
                .frame(width: w)
            }
        }
        .background(Bench.surface)
    }

    private func drawTrace(_ ctx: inout GraphicsContext, width: CGFloat, laneHeight: CGFloat) {
        let labelWidth: CGFloat = 46
        let plotX = labelWidth + 6
        let plotW = max(40, width - plotX - 10)
        let samples = vm.timing
        let n = max(samples.count, 1)
        let step = plotW / CGFloat(max(n, 2))
        let names = vm.level.inputNames + vm.level.outputNames
        let inCount = vm.level.inputNames.count

        for (lane, name) in names.enumerated() {
            let top = 8 + CGFloat(lane) * laneHeight
            let hi = top + 4
            let lo = top + laneHeight - 10
            ctx.draw(Text(name).font(Bench.mono(9, .bold))
                        .foregroundColor(lane < inCount ? Bench.copper : Bench.good),
                     at: CGPoint(x: labelWidth - 4, y: (hi + lo) / 2), anchor: .trailing)

            var base = Path()
            base.move(to: CGPoint(x: plotX, y: lo))
            base.addLine(to: CGPoint(x: plotX + plotW, y: lo))
            ctx.stroke(base, with: .color(Bench.grid), lineWidth: 1)

            guard !samples.isEmpty else { continue }
            var wave = Path()
            var prev: Bool? = nil
            for (i, s) in samples.enumerated() {
                let v = lane < inCount
                    ? (lane < s.inputs.count ? s.inputs[lane] : false)
                    : ((lane - inCount) < s.outputs.count ? s.outputs[lane - inCount] : false)
                let x0 = plotX + CGFloat(i) * step
                let x1 = x0 + step
                let y = v ? hi : lo
                if let p = prev {
                    if p != v {
                        wave.addLine(to: CGPoint(x: x0, y: y))
                    }
                    wave.addLine(to: CGPoint(x: x1, y: y))
                } else {
                    wave.move(to: CGPoint(x: x0, y: y))
                    wave.addLine(to: CGPoint(x: x1, y: y))
                }
                prev = v
            }
            ctx.stroke(wave, with: .color(lane < inCount ? Bench.copper : Bench.high),
                       style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
        }
    }
}
