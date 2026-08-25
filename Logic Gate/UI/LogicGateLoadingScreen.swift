import SwiftUI

/// Splash shown while the launch check runs. Hand-drawn gate art, no system assets.
struct LogicGateLoadingScreen: View {
    @State private var pulse = false

    var body: some View {
        GeometryReader { proxy in
            let w = benchUsableWidth(proxy.size.width)
            let side = min(w * 0.42, 190)
            ZStack {
                Bench.background.ignoresSafeArea()
                VStack(spacing: 26) {
                    Spacer(minLength: 20)
                    Canvas { ctx, size in
                        let r = CGRect(x: size.width * 0.16, y: size.height * 0.24,
                                       width: size.width * 0.56, height: size.height * 0.52)
                        let body = GateArt.andBody(r)
                        ctx.fill(body, with: .color(Bench.surface))
                        ctx.stroke(body, with: .color(Bench.copper), lineWidth: 3)
                        var leads = Path()
                        let y1 = r.minY + r.height * 0.3
                        let y2 = r.minY + r.height * 0.7
                        leads.move(to: CGPoint(x: size.width * 0.03, y: y1))
                        leads.addLine(to: CGPoint(x: r.minX, y: y1))
                        leads.move(to: CGPoint(x: size.width * 0.03, y: y2))
                        leads.addLine(to: CGPoint(x: r.minX, y: y2))
                        leads.move(to: CGPoint(x: r.maxX, y: r.midY))
                        leads.addLine(to: CGPoint(x: size.width * 0.94, y: r.midY))
                        ctx.stroke(leads, with: .color(Bench.high), lineWidth: 2.5)
                        var dot = Path()
                        dot.addEllipse(in: CGRect(x: size.width * 0.9, y: r.midY - 7,
                                                  width: 14, height: 14))
                        ctx.fill(dot, with: .color(Bench.high))
                    }
                    .frame(width: side, height: side * 0.78)
                    .opacity(pulse ? 1.0 : 0.55)

                    VStack(spacing: 8) {
                        Text("LOGIC GATE")
                            .font(Bench.mono(15, .bold))
                            .tracking(2)
                            .foregroundColor(Bench.text)
                        Text("warming up the bench")
                            .font(Bench.label(12, .regular))
                            .foregroundColor(Bench.textDim)
                    }

                    HStack(spacing: 7) {
                        ForEach(0..<4, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Bench.copper.opacity(pulse ? 0.9 : 0.25))
                                .frame(width: 22, height: 4)
                                .animation(Animation.easeInOut(duration: 0.7)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(i) * 0.12), value: pulse)
                        }
                    }
                    Spacer(minLength: 20)
                }
                .frame(width: w)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
