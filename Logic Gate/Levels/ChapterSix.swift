import Foundation

extension LevelMaker {

    // MARK: - Chapter 6: Memory

    func chapterMemory() -> [LogicGateLevel] {
        var out: [LogicGateLevel] = []

        out.append(seq(59, 6, "SR Latch From NOR",
            "Two NOR gates, each feeding the other. The circuit remembers which input was pulsed last, and that is the whole of digital memory in two parts.",
            hint: "Cross-couple them: Q is NOR of R and Q-bar, Q-bar is NOR of S and Q. Wire the outputs back into the opposite gate.",
            ins: ["S", "R"], outs: ["Q", "Q'"],
            palette: Palettes.norOnly,
            steps: [
                SequentialStep([false, true], pulse: false, expect: [false, true], note: "reset"),
                SequentialStep([false, false], pulse: false, expect: [false, true], note: "hold"),
                SequentialStep([true, false], pulse: false, expect: [true, false], note: "set"),
                SequentialStep([false, false], pulse: false, expect: [true, false], note: "hold"),
                SequentialStep([true, false], pulse: false, expect: [true, false], note: "set again"),
                SequentialStep([false, true], pulse: false, expect: [false, true], note: "reset"),
                SequentialStep([false, false], pulse: false, expect: [false, true], note: "hold")
            ],
            build: { b in
                let s = b.inp(0), r = b.inp(1)
                let q = b.open(.nor)
                let qn = b.open(.nor)
                b.wire(r, into: q, pin: 0)
                b.wire(b.tap(qn), into: q, pin: 1)
                b.wire(s, into: qn, pin: 0)
                b.wire(b.tap(q), into: qn, pin: 1)
                b.out(0, b.tap(q))
                b.out(1, b.tap(qn))
            }))

        out.append(seq(60, 6, "Gated SR Latch",
            "The same latch, but deaf unless the enable line is high. Gating is how a machine keeps its memory from reacting to every glitch on the bus.",
            hint: "Put an AND gate in front of each latch input, both with EN as the second input.",
            ins: ["S", "R", "EN"], outs: ["Q", "Q'"],
            palette: [.and, .or, .not, .nor, .nand, .junction],
            steps: [
                SequentialStep([false, true, true], pulse: false, expect: [false, true], note: "reset"),
                SequentialStep([true, false, false], pulse: false, expect: [false, true], note: "gate closed"),
                SequentialStep([true, false, true], pulse: false, expect: [true, false], note: "set"),
                SequentialStep([false, true, false], pulse: false, expect: [true, false], note: "gate closed"),
                SequentialStep([false, false, true], pulse: false, expect: [true, false], note: "hold"),
                SequentialStep([false, true, true], pulse: false, expect: [false, true], note: "reset"),
                SequentialStep([true, true, false], pulse: false, expect: [false, true], note: "gate closed")
            ],
            build: { b in
                let s = b.inp(0), r = b.inp(1), en = b.inp(2)
                let gs = b.g(.and, s, en)
                let gr = b.g(.and, r, en)
                let q = b.open(.nor)
                let qn = b.open(.nor)
                b.wire(gr, into: q, pin: 0)
                b.wire(b.tap(qn), into: q, pin: 1)
                b.wire(gs, into: qn, pin: 0)
                b.wire(b.tap(q), into: qn, pin: 1)
                b.out(0, b.tap(q))
                b.out(1, b.tap(qn))
            }))

        out.append(seq(61, 6, "D Latch From Gates",
            "One data line instead of two. While EN is high the output copies D; when EN drops the last value is trapped.",
            hint: "Drive the set side with D AND EN and the reset side with NOT D AND EN. The forbidden state can no longer happen.",
            ins: ["D", "EN"], outs: ["Q", "Q'"],
            palette: [.and, .or, .not, .nor, .nand, .junction],
            steps: [
                SequentialStep([false, true], pulse: false, expect: [false, true], note: "load 0"),
                SequentialStep([true, false], pulse: false, expect: [false, true], note: "closed"),
                SequentialStep([true, true], pulse: false, expect: [true, false], note: "load 1"),
                SequentialStep([false, false], pulse: false, expect: [true, false], note: "closed"),
                SequentialStep([false, true], pulse: false, expect: [false, true], note: "load 0"),
                SequentialStep([true, false], pulse: false, expect: [false, true], note: "closed")
            ],
            build: { b in
                let d = b.inp(0), en = b.inp(1)
                let gs = b.g(.and, d, en)
                let gr = b.g(.and, b.g(.not, d), en)
                let q = b.open(.nor)
                let qn = b.open(.nor)
                b.wire(gr, into: q, pin: 0)
                b.wire(b.tap(qn), into: q, pin: 1)
                b.wire(gs, into: qn, pin: 0)
                b.wire(b.tap(q), into: qn, pin: 1)
                b.out(0, b.tap(q))
                b.out(1, b.tap(qn))
            }))

        out.append(seq(62, 6, "Transparent Window",
            "The same behaviour from the packaged D latch part. Level sensitive: it is a window, not a shutter, and it stays open the whole time EN is high.",
            hint: "Drop one D Latch, wire D and EN, and take Q and Q-bar to the lamps.",
            ins: ["D", "EN"], outs: ["Q", "Q'"],
            palette: Palettes.memory,
            steps: [
                SequentialStep([false, true], pulse: false, expect: [false, true], note: "load 0"),
                SequentialStep([true, false], pulse: false, expect: [false, true], note: "closed"),
                SequentialStep([true, true], pulse: false, expect: [true, false], note: "load 1"),
                SequentialStep([false, false], pulse: false, expect: [true, false], note: "closed"),
                SequentialStep([false, true], pulse: false, expect: [false, true], note: "load 0"),
                SequentialStep([true, false], pulse: false, expect: [false, true], note: "closed")
            ],
            build: { b in
                let d = b.inp(0), en = b.inp(1)
                let m = b.mem(.dLatch, [d, en])
                b.out(0, m.q)
                b.out(1, m.qbar)
            }))

        out.append(seq(63, 6, "Edge Triggered D",
            "A flip-flop samples D at the instant the clock rises and ignores it for the rest of the cycle. Watch step three: D changes while the clock is high and nothing happens.",
            hint: "One D Flip-Flop. D on the data pin, CLK on the pin with the triangle.",
            ins: ["D", "CLK"], outs: ["Q"],
            palette: Palettes.memory,
            unlocks: ChipUnlock(id: "dff", name: "D Flip-Flop",
                                blurb: "Captures D on the rising clock edge and holds it."),
            steps: [
                SequentialStep([true, false], pulse: false, expect: [false], note: "idle low"),
                SequentialStep([true, true], pulse: false, expect: [true], note: "rising edge captures 1"),
                SequentialStep([false, true], pulse: false, expect: [true], note: "D ignored while high"),
                SequentialStep([false, false], pulse: false, expect: [true], note: "falling edge does nothing"),
                SequentialStep([false, true], pulse: false, expect: [false], note: "rising edge captures 0"),
                SequentialStep([true, false], pulse: false, expect: [false], note: "idle low"),
                SequentialStep([true, true], pulse: false, expect: [true], note: "rising edge captures 1"),
                SequentialStep([true, false], pulse: false, expect: [true], note: "hold")
            ],
            build: { b in
                let d = b.inp(0), clk = b.inp(1)
                let m = b.mem(.dFlipFlop, [d, clk])
                b.out(0, m.q)
            }))

        out.append(seq(64, 6, "Toggle Flip-Flop",
            "When T is high the output flips on every rising clock edge. When T is low it sits still. This is the building block of every binary counter.",
            hint: "One T Flip-Flop, T to the data pin, CLK to the clock pin.",
            ins: ["T", "CLK"], outs: ["Q"],
            palette: Palettes.memory,
            steps: [
                SequentialStep([true, false], pulse: false, expect: [false], note: "idle"),
                SequentialStep([true, true], pulse: false, expect: [true], note: "toggle"),
                SequentialStep([true, false], pulse: false, expect: [true], note: "hold"),
                SequentialStep([true, true], pulse: false, expect: [false], note: "toggle"),
                SequentialStep([false, false], pulse: false, expect: [false], note: "T low"),
                SequentialStep([false, true], pulse: false, expect: [false], note: "no toggle"),
                SequentialStep([true, false], pulse: false, expect: [false], note: "T high again"),
                SequentialStep([true, true], pulse: false, expect: [true], note: "toggle")
            ],
            build: { b in
                let t = b.inp(0), clk = b.inp(1)
                let m = b.mem(.tFlipFlop, [t, clk])
                b.out(0, m.q)
            }))

        out.append(seq(65, 6, "JK Behaviour",
            "The most flexible flip-flop: J alone sets, K alone resets, both together toggle, neither holds. Four behaviours from two pins.",
            hint: "One JK Flip-Flop. J, K and CLK straight from the switches.",
            ins: ["J", "K", "CLK"], outs: ["Q", "Q'"],
            palette: Palettes.memory,
            steps: [
                SequentialStep([false, true, false], pulse: false, expect: [false, true], note: "idle"),
                SequentialStep([false, true, true], pulse: false, expect: [false, true], note: "reset"),
                SequentialStep([true, false, false], pulse: false, expect: [false, true], note: "arm set"),
                SequentialStep([true, false, true], pulse: false, expect: [true, false], note: "set"),
                SequentialStep([true, true, false], pulse: false, expect: [true, false], note: "arm toggle"),
                SequentialStep([true, true, true], pulse: false, expect: [false, true], note: "toggle"),
                SequentialStep([true, true, false], pulse: false, expect: [false, true], note: "clock low"),
                SequentialStep([true, true, true], pulse: false, expect: [true, false], note: "toggle"),
                SequentialStep([false, false, false], pulse: false, expect: [true, false], note: "hold"),
                SequentialStep([false, false, true], pulse: false, expect: [true, false], note: "hold on edge")
            ],
            build: { b in
                let j = b.inp(0), k = b.inp(1), clk = b.inp(2)
                let m = b.mem(.jkFlipFlop, [j, k, clk])
                b.out(0, m.q)
                b.out(1, m.qbar)
            }))

        out.append(seq(66, 6, "Divide By Two",
            "Tie T high and the flip-flop halves the clock frequency. Every counter, every timer and every clock divider in a real machine starts here.",
            hint: "A T Flip-Flop with its T pin wired to a constant 1.",
            ins: ["CLK"], outs: ["Q"],
            palette: Palettes.memory,
            steps: [
                SequentialStep([false], pulse: false, expect: [false], note: "idle"),
                SequentialStep([true], pulse: false, expect: [true], note: "edge 1"),
                SequentialStep([false], pulse: false, expect: [true], note: "hold"),
                SequentialStep([true], pulse: false, expect: [false], note: "edge 2"),
                SequentialStep([false], pulse: false, expect: [false], note: "hold"),
                SequentialStep([true], pulse: false, expect: [true], note: "edge 3"),
                SequentialStep([false], pulse: false, expect: [true], note: "hold"),
                SequentialStep([true], pulse: false, expect: [false], note: "edge 4")
            ],
            build: { b in
                let clk = b.inp(0)
                let m = b.mem(.tFlipFlop, [b.lit(true), clk])
                b.out(0, m.q)
            }))

        out.append(seq(67, 6, "Two-Bit Ripple Counter",
            "Chain two toggle flip-flops and you can count to three. The second stage is clocked by the first stage's Q-bar, so it advances once for every two input edges.",
            hint: "Both T pins tied high. Stage one takes CLK; stage two takes stage one's Q-bar as its clock.",
            ins: ["CLK"], outs: ["Q1", "Q0"],
            palette: Palettes.memory,
            unlocks: ChipUnlock(id: "counter2", name: "2-Bit Counter",
                                blurb: "Counts rising clock edges from zero to three and wraps."),
            steps: {
                var s: [SequentialStep] = [SequentialStep([false], pulse: false,
                                                          expect: [false, false], note: "reset")]
                for n in 1...5 {
                    let bits = lgwBits(n % 4, 2)
                    s.append(SequentialStep([true], pulse: false, expect: bits, note: "count \(n % 4)"))
                    s.append(SequentialStep([false], pulse: false, expect: bits, note: "clock low"))
                }
                return s
            }(),
            build: { b in
                let clk = b.inp(0)
                let one = b.lit(true)
                let f0 = b.mem(.tFlipFlop, [one, clk])
                let f1 = b.mem(.tFlipFlop, [one, f0.qbar])
                b.out(0, f1.q)
                b.out(1, f0.q)
            }))

        out.append(seq(68, 6, "Four-Bit Counter",
            "Four stages, sixteen states, and it wraps around to zero on its own. The ripple takes a moment to settle, which is exactly why fast machines use carry-lookahead counters instead.",
            hint: "Four toggle flip-flops, every T tied high, each stage clocked by the Q-bar of the one below it.",
            ins: ["CLK"], outs: ["Q3", "Q2", "Q1", "Q0"],
            palette: Palettes.memory,
            unlocks: ChipUnlock(id: "counter4", name: "4-Bit Counter",
                                blurb: "Counts zero to fifteen on rising edges, then wraps."),
            steps: {
                var s: [SequentialStep] = [SequentialStep([false], pulse: false,
                                                          expect: [false, false, false, false],
                                                          note: "reset")]
                for n in 1...17 {
                    let bits = lgwBits(n % 16, 4)
                    s.append(SequentialStep([true], pulse: false, expect: bits, note: "count \(n % 16)"))
                    s.append(SequentialStep([false], pulse: false, expect: bits, note: "clock low"))
                }
                return s
            }(),
            build: { b in
                let clk = b.inp(0)
                let one = b.lit(true)
                let f0 = b.mem(.tFlipFlop, [one, clk])
                let f1 = b.mem(.tFlipFlop, [one, f0.qbar])
                let f2 = b.mem(.tFlipFlop, [one, f1.qbar])
                let f3 = b.mem(.tFlipFlop, [one, f2.qbar])
                b.out(0, f3.q); b.out(1, f2.q); b.out(2, f1.q); b.out(3, f0.q)
            }))

        out.append(seq(69, 6, "Shift Register",
            "Four D flip-flops in a row, all clocked together. Data walks one stage further along on every edge.",
            hint: "D into the first flip-flop, each flip-flop's Q into the next one's D, and one shared clock line to all four.",
            ins: ["D", "CLK"], outs: ["Q0", "Q1", "Q2", "Q3"],
            palette: Palettes.memory,
            steps: [
                SequentialStep([true, false], pulse: false, expect: [false, false, false, false], note: "idle"),
                SequentialStep([true, true], pulse: false, expect: [true, false, false, false], note: "shift in 1"),
                SequentialStep([false, false], pulse: false, expect: [true, false, false, false], note: "clock low"),
                SequentialStep([false, true], pulse: false, expect: [false, true, false, false], note: "shift in 0"),
                SequentialStep([true, false], pulse: false, expect: [false, true, false, false], note: "clock low"),
                SequentialStep([true, true], pulse: false, expect: [true, false, true, false], note: "shift in 1"),
                SequentialStep([true, false], pulse: false, expect: [true, false, true, false], note: "clock low"),
                SequentialStep([true, true], pulse: false, expect: [true, true, false, true], note: "shift in 1"),
                SequentialStep([false, false], pulse: false, expect: [true, true, false, true], note: "clock low"),
                SequentialStep([false, true], pulse: false, expect: [false, true, true, false], note: "shift in 0")
            ],
            build: { b in
                let d = b.inp(0), clk = b.inp(1)
                let f0 = b.mem(.dFlipFlop, [d, clk])
                let f1 = b.mem(.dFlipFlop, [f0.q, clk])
                let f2 = b.mem(.dFlipFlop, [f1.q, clk])
                let f3 = b.mem(.dFlipFlop, [f2.q, clk])
                b.out(0, f0.q); b.out(1, f1.q); b.out(2, f2.q); b.out(3, f3.q)
            }))

        out.append(seq(70, 6, "Ring Counter",
            "A shift register whose last stage feeds back inverted. Eight distinct states from four flip-flops, and it starts cleanly from all zeros, which a plain ring counter cannot do.",
            hint: "Wire Q3 through a NOT gate and back into the first flip-flop's D input. Everything else is a shift register.",
            ins: ["CLK"], outs: ["Q0", "Q1", "Q2", "Q3"],
            palette: Palettes.memory,
            steps: {
                let pattern: [[Bool]] = [
                    [true, false, false, false],
                    [true, true, false, false],
                    [true, true, true, false],
                    [true, true, true, true],
                    [false, true, true, true],
                    [false, false, true, true],
                    [false, false, false, true],
                    [false, false, false, false]
                ]
                var s: [SequentialStep] = [SequentialStep([false], pulse: false,
                                                          expect: [false, false, false, false],
                                                          note: "reset")]
                for (i, p) in pattern.enumerated() {
                    s.append(SequentialStep([true], pulse: false, expect: p, note: "edge \(i + 1)"))
                    s.append(SequentialStep([false], pulse: false, expect: p, note: "clock low"))
                }
                return s
            }(),
            build: { b in
                let clk = b.inp(0)
                let ff = (0..<4).map { _ in b.open(.dFlipFlop) }
                b.wire(b.g(.not, b.tap(ff[3])), into: ff[0], pin: 0)
                b.wire(clk, into: ff[0], pin: 1)
                for i in 1..<4 {
                    b.wire(b.tap(ff[i - 1]), into: ff[i], pin: 0)
                    b.wire(clk, into: ff[i], pin: 1)
                }
                for i in 0..<4 { b.out(i, b.tap(ff[i])) }
            }))

        return out
    }
}
