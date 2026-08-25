import Foundation

/// Segment patterns a, b, c, d, e, f, g for the digits zero to three.
let lgwSegmentTable: [[Bool]] = [
    [true, true, true, true, true, true, false],
    [false, true, true, false, false, false, false],
    [true, true, false, true, true, false, true],
    [true, true, true, true, false, false, true]
]

extension LevelMaker {

    // MARK: - Chapter 7: The Machine

    func chapterMachine() -> [LogicGateLevel] {
        var out: [LogicGateLevel] = []

        out.append(comb(71, 7, "Segment Driver",
            "Seven lamps arranged as a digit. Turn a two-bit number into the segment pattern that draws it. Segments d and a light for exactly the same digits, so build that term once and use it twice.",
            hint: "Decode the four minterms with two NOTs and four ANDs, then OR the right minterms into each segment. Segment b is always on.",
            ins: ["A1", "A0"],
            outs: ["a", "b", "c", "d", "e", "f", "g"],
            palette: [.not, .and, .or, .and3, .junction, .const0, .const1, .sevenSegment],
            unlocks: ChipUnlock(id: "seg7drv", name: "7-Seg Driver",
                                blurb: "Two-bit value in, seven segment lines out."),
            fn: { v in lgwSegmentTable[lgwValue(v, 0, 2)] },
            build: { b in
                let a1 = b.inp(0), a0 = b.inp(1)
                let n1 = b.g(.not, a1), n0 = b.g(.not, a0)
                let m0 = b.g(.and, n1, n0)
                let m1 = b.g(.and, n1, a0)
                let m2 = b.g(.and, a1, n0)
                let m3 = b.g(.and, a1, a0)
                let e = b.g(.or, m0, m2)
                let ad = b.g(.or, e, m3)
                b.out(0, ad)
                b.out(1, b.lit(true))
                b.out(2, b.g(.or, b.g(.or, m0, m1), m3))
                b.out(3, ad)
                b.out(4, e)
                b.out(5, m0)
                b.out(6, b.g(.or, m2, m3))
            }))

        out.append(comb(72, 7, "Blank On Command",
            "The same digit driver with a blanking input. When EN goes low every segment must go dark, whatever the value on the address lines.",
            hint: "Take the driver chip and put an AND gate with EN on each of its seven outputs.",
            ins: ["A1", "A0", "EN"],
            outs: ["a", "b", "c", "d", "e", "f", "g"],
            palette: [.not, .and, .or, .and3, .junction, .const0, .const1, .sevenSegment],
            chipIds: ["seg7drv"],
            fn: { v in
                let pattern = lgwSegmentTable[lgwValue(v, 0, 2)]
                return pattern.map { $0 && v[2] }
            },
            build: { b in
                let a1 = b.inp(0), a0 = b.inp(1), en = b.inp(2)
                let seg = b.chip("seg7drv", [a1, a0])
                for i in 0..<7 { b.out(i, b.g(.and, seg[i], en)) }
            }))

        out.append(comb(73, 7, "Parity Generator",
            "Produce the even-parity bit for a four-bit word: P must make the total number of high bits even.",
            hint: "XOR everything together. Three XOR gates in a tree or a chain, whichever you find tidier.",
            ins: ["D3", "D2", "D1", "D0"], outs: ["P"],
            palette: Palettes.allGates,
            fn: { v in
                var p = false
                for i in 0..<4 where v[i] { p.toggle() }
                return [p]
            },
            build: { b in
                let d = (0..<4).map { b.inp($0) }
                b.out(0, b.g(.xor, b.g(.xor, d[0], d[1]), b.g(.xor, d[2], d[3])))
            }))

        out.append(comb(74, 7, "Parity Checker",
            "The word arrives with its parity bit attached. Raise ERR when the five bits together have odd parity, because that means something flipped in transit.",
            hint: "XOR all five lines together. If the sender did its job the result is zero.",
            ins: ["D3", "D2", "D1", "D0", "P"], outs: ["ERR"],
            palette: Palettes.allGates,
            fn: { v in
                var p = false
                for i in 0..<5 where v[i] { p.toggle() }
                return [p]
            },
            build: { b in
                let d = (0..<5).map { b.inp($0) }
                let t = b.g(.xor, b.g(.xor, d[0], d[1]), b.g(.xor, d[2], d[3]))
                b.out(0, b.g(.xor, t, d[4]))
            }))

        out.append(comb(75, 7, "One-Bit ALU",
            "Four operations on one bit, chosen by a two-bit opcode: 00 is AND, 01 is OR, 10 is the sum bit, 11 is NOT A. C carries out of the sum only.",
            hint: "Compute all four results in parallel, then let a 4:1 multiplexer pick one. C is the AND result gated by opcode 10.",
            ins: ["A", "B", "OP1", "OP0"], outs: ["Y", "C"],
            palette: [.and, .or, .not, .xor, .nand, .nor, .and3, .junction],
            chipIds: ["mux21", "mux41"],
            unlocks: ChipUnlock(id: "alu1", name: "1-Bit ALU",
                                blurb: "AND, OR, sum and NOT on one bit, chosen by opcode."),
            fn: { v in
                let a = v[0], bb = v[1]
                let op = lgwValue(v, 2, 2)
                let y: Bool
                switch op {
                case 0: y = a && bb
                case 1: y = a || bb
                case 2: y = a != bb
                default: y = !a
                }
                return [y, op == 2 && a && bb]
            },
            build: { b in
                let a = b.inp(0), bb = b.inp(1), op1 = b.inp(2), op0 = b.inp(3)
                let rAnd = b.g(.and, a, bb)
                let rOr = b.g(.or, a, bb)
                let rXor = b.g(.xor, a, bb)
                let rNot = b.g(.not, a)
                b.out(0, b.chip("mux41", [rAnd, rOr, rXor, rNot, op1, op0])[0])
                b.out(1, b.g(.and3, op1, b.g(.not, op0), rAnd))
            }))

        out.append(comb(76, 7, "Four-Bit Logic Unit",
            "Four of those ALU slices side by side, all sharing one opcode. This is a real arithmetic logic unit's data path, minus the carry chain.",
            hint: "One ALU chip per bit. The opcode lines fan out to all four.",
            ins: ["A3", "A2", "A1", "A0", "B3", "B2", "B1", "B0", "OP1", "OP0"],
            outs: ["Y3", "Y2", "Y1", "Y0"],
            palette: [.and, .or, .not, .xor, .junction],
            chipIds: ["alu1", "mux21", "mux41"],
            fn: { v in
                let op = lgwValue(v, 8, 2)
                return (0..<4).map { i in
                    let a = v[i], bb = v[4 + i]
                    switch op {
                    case 0: return a && bb
                    case 1: return a || bb
                    case 2: return a != bb
                    default: return !a
                    }
                }
            },
            build: { b in
                let a = (0..<4).map { b.inp($0) }
                let bs = (0..<4).map { b.inp(4 + $0) }
                let op1 = b.inp(8), op0 = b.inp(9)
                for i in 0..<4 {
                    b.out(i, b.chip("alu1", [a[i], bs[i], op1, op0])[0])
                }
            }))

        out.append(comb(77, 7, "Adder Or Subtractor",
            "One circuit that does both. When SUB is low it adds; when SUB is high it inverts every bit of B and forces a carry in, which is subtraction.",
            hint: "XOR each B bit with SUB, then feed SUB itself into the adder's carry input.",
            ins: ["A3", "A2", "A1", "A0", "B3", "B2", "B1", "B0", "SUB"],
            outs: ["S3", "S2", "S1", "S0", "Cout"],
            palette: [.and, .or, .not, .xor, .xnor, .junction, .const0, .const1],
            chipIds: ["adder4"],
            fn: { v in
                let a = lgwValue(v, 0, 4)
                let bv = lgwValue(v, 4, 4)
                let sub = v[8]
                let bx = sub ? (15 - bv) : bv
                let s = a + bx + (sub ? 1 : 0)
                let bits = lgwBits(s, 5)
                return [bits[1], bits[2], bits[3], bits[4], bits[0]]
            },
            build: { b in
                let a = (0..<4).map { b.inp($0) }
                let sub = b.inp(8)
                let bx = (0..<4).map { b.g(.xor, b.inp(4 + $0), sub) }
                let r = b.chip("adder4", [a[0], a[1], a[2], a[3],
                                          bx[0], bx[1], bx[2], bx[3], sub])
                for i in 0..<5 { b.out(i, r[i]) }
            }))

        out.append(comb(78, 7, "Status Flags",
            "Every processor exposes flags after an operation. Produce ZERO, CARRY and signed OVERFLOW for the same add-or-subtract unit.",
            hint: "ZERO is a NOR tree over the sum. CARRY is the adder's carry out. OVERFLOW is set when the two operands share a sign and the result does not.",
            ins: ["A3", "A2", "A1", "A0", "B3", "B2", "B1", "B0", "SUB"],
            outs: ["ZERO", "CARRY", "OVER"],
            palette: [.and, .or, .not, .nor, .xor, .xnor, .junction, .const0, .const1],
            chipIds: ["adder4"],
            fn: { v in
                let a = lgwValue(v, 0, 4)
                let bv = lgwValue(v, 4, 4)
                let sub = v[8]
                let bx = sub ? (15 - bv) : bv
                let s = a + bx + (sub ? 1 : 0)
                let res = s & 15
                let a3 = v[0]
                let b3x = sub ? !v[4] : v[4]
                let s3 = (res & 8) != 0
                return [res == 0, s >= 16, (a3 == b3x) && (s3 != a3)]
            },
            build: { b in
                let a = (0..<4).map { b.inp($0) }
                let sub = b.inp(8)
                let bx = (0..<4).map { b.g(.xor, b.inp(4 + $0), sub) }
                let r = b.chip("adder4", [a[0], a[1], a[2], a[3],
                                          bx[0], bx[1], bx[2], bx[3], sub])
                b.out(0, b.g(.nor, b.g(.or, r[0], r[1]), b.g(.or, r[2], r[3])))
                b.out(1, r[4])
                b.out(2, b.g(.and, b.g(.xnor, a[0], bx[0]), b.g(.xor, a[0], r[0])))
            }))

        out.append(seq(79, 7, "Register Write Gate",
            "Four flip-flops that only accept new data when LOAD is high. Every clock edge either reloads the register or refreshes it with its own contents.",
            hint: "Put a 2:1 mux in front of each flip-flop: input A is the flip-flop's own Q, input B is the new data, and LOAD is the select line.",
            ins: ["D3", "D2", "D1", "D0", "LOAD", "CLK"],
            outs: ["Q3", "Q2", "Q1", "Q0"],
            palette: [.and, .or, .not, .junction, .dFlipFlop, .dLatch, .const0, .const1],
            chipIds: ["mux21", "dff"],
            steps: [
                SequentialStep([false, true, false, true, true, false],
                               pulse: false, expect: [false, false, false, false], note: "idle"),
                SequentialStep([false, true, false, true, true, true],
                               pulse: false, expect: [false, true, false, true], note: "load 0101"),
                SequentialStep([true, true, true, true, false, false],
                               pulse: false, expect: [false, true, false, true], note: "clock low"),
                SequentialStep([true, true, true, true, false, true],
                               pulse: false, expect: [false, true, false, true], note: "load low, hold"),
                SequentialStep([true, true, true, true, true, false],
                               pulse: false, expect: [false, true, false, true], note: "clock low"),
                SequentialStep([true, true, true, true, true, true],
                               pulse: false, expect: [true, true, true, true], note: "load 1111"),
                SequentialStep([false, false, false, false, false, true],
                               pulse: false, expect: [true, true, true, true], note: "no new edge"),
                SequentialStep([false, false, false, false, true, false],
                               pulse: false, expect: [true, true, true, true], note: "clock low"),
                SequentialStep([false, false, false, false, true, true],
                               pulse: false, expect: [false, false, false, false], note: "load 0000")
            ],
            build: { b in
                let d = (0..<4).map { b.inp($0) }
                let load = b.inp(4), clk = b.inp(5)
                let ff = (0..<4).map { _ in b.open(.dFlipFlop) }
                for i in 0..<4 {
                    let m = b.chip("mux21", [b.tap(ff[i]), d[i], load])
                    b.wire(m[0], into: ff[i], pin: 0)
                    b.wire(clk, into: ff[i], pin: 1)
                    b.out(i, b.tap(ff[i]))
                }
            }))

        out.append(seq(80, 7, "The Accumulator",
            "The last bench. A four-bit register, a four-bit adder wired back into it, and one control line. Raise ADD and each clock edge adds B into the running total, wrapping at sixteen. This is a machine.",
            hint: "Feed the register's own outputs into the adder alongside B, then multiplex between the adder's sum and the current value using ADD.",
            ins: ["B3", "B2", "B1", "B0", "ADD", "CLK"],
            outs: ["Q3", "Q2", "Q1", "Q0"],
            palette: [.and, .or, .not, .xor, .junction, .dFlipFlop, .const0, .const1],
            chipIds: ["adder4", "mux21", "dff", "fulladder"],
            steps: [
                SequentialStep([false, false, true, true, true, false],
                               pulse: false, expect: [false, false, false, false], note: "start at 0"),
                SequentialStep([false, false, true, true, true, true],
                               pulse: false, expect: [false, false, true, true], note: "0 + 3 = 3"),
                SequentialStep([false, true, false, true, true, false],
                               pulse: false, expect: [false, false, true, true], note: "clock low"),
                SequentialStep([false, true, false, true, true, true],
                               pulse: false, expect: [true, false, false, false], note: "3 + 5 = 8"),
                SequentialStep([false, true, false, true, false, false],
                               pulse: false, expect: [true, false, false, false], note: "clock low"),
                SequentialStep([false, true, false, true, false, true],
                               pulse: false, expect: [true, false, false, false], note: "ADD low, hold"),
                SequentialStep([true, false, false, true, true, false],
                               pulse: false, expect: [true, false, false, false], note: "clock low"),
                SequentialStep([true, false, false, true, true, true],
                               pulse: false, expect: [false, false, false, true], note: "8 + 9 wraps to 1"),
                SequentialStep([false, false, false, true, true, false],
                               pulse: false, expect: [false, false, false, true], note: "clock low"),
                SequentialStep([false, false, false, true, true, true],
                               pulse: false, expect: [false, false, true, false], note: "1 + 1 = 2")
            ],
            build: { b in
                let bIn = (0..<4).map { b.inp($0) }
                let add = b.inp(4), clk = b.inp(5)
                let ff = (0..<4).map { _ in b.open(.dFlipFlop) }
                let q = (0..<4).map { b.tap(ff[$0]) }
                let s = b.chip("adder4", [q[0], q[1], q[2], q[3],
                                          bIn[0], bIn[1], bIn[2], bIn[3], b.lit(false)])
                for i in 0..<4 {
                    let m = b.chip("mux21", [q[i], s[i], add])
                    b.wire(m[0], into: ff[i], pin: 0)
                    b.wire(clk, into: ff[i], pin: 1)
                    b.out(i, q[i])
                }
            }))

        return out
    }
}
