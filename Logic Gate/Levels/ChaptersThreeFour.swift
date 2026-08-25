import Foundation

/// Reads `count` bits starting at `from` as an unsigned integer, most significant bit first.
func lgwValue(_ v: [Bool], _ from: Int, _ count: Int) -> Int {
    var n = 0
    for i in from..<(from + count) {
        n = (n << 1) | ((i >= 0 && i < v.count && v[i]) ? 1 : 0)
    }
    return n
}

/// Splits an integer into `width` bits, most significant bit first.
func lgwBits(_ value: Int, _ width: Int) -> [Bool] {
    (0..<width).map { (value >> (width - 1 - $0)) & 1 == 1 }
}

extension LevelMaker {

    // MARK: - Chapter 3: Arithmetic

    func chapterArithmetic() -> [LogicGateLevel] {
        var out: [LogicGateLevel] = []

        out.append(comb(23, 3, "Half Adder",
            "Add two single bits. S is the sum bit, C is the carry out. Two gates, and you have built the smallest piece of arithmetic hardware there is.",
            hint: "S is A XOR B. C is A AND B. That is the whole half adder.",
            ins: ["A", "B"], outs: ["S", "C"],
            palette: Palettes.allGates,
            unlocks: ChipUnlock(id: "halfadder", name: "Half Adder",
                                blurb: "Sum and carry of two bits. No carry input."),
            fn: { v in [v[0] != v[1], v[0] && v[1]] },
            build: { b in
                let a = b.inp(0), bb = b.inp(1)
                b.out(0, b.g(.xor, a, bb))
                b.out(1, b.g(.and, a, bb))
            }))

        out.append(comb(24, 3, "Full Adder",
            "Now with a carry coming in. Two half adders and one OR gate: the first time a chip you built becomes a part you place.",
            hint: "Half-add A and B, half-add that sum with Cin, then OR the two carries together.",
            ins: ["A", "B", "Cin"], outs: ["S", "Cout"],
            palette: [.and, .or, .xor, .not, .nand, .junction],
            chipIds: ["halfadder"],
            unlocks: ChipUnlock(id: "fulladder", name: "Full Adder",
                                blurb: "Three bits in, sum and carry out. The cell of every ripple adder."),
            fn: { v in
                let n = (v[0] ? 1 : 0) + (v[1] ? 1 : 0) + (v[2] ? 1 : 0)
                return [n & 1 == 1, n >= 2]
            },
            build: { b in
                let a = b.inp(0), bb = b.inp(1), cin = b.inp(2)
                let h1 = b.chip("halfadder", [a, bb])
                let h2 = b.chip("halfadder", [h1[0], cin])
                b.out(0, h2[0])
                b.out(1, b.g(.or, h1[1], h2[1]))
            }))

        out.append(comb(25, 3, "Carry Majority",
            "Light the lamp when at least two of the three switches are on. This is exactly the carry-out half of a full adder, and it is worth knowing on its own.",
            hint: "AB + AC + BC. Three AND gates feeding a pair of ORs.",
            ins: ["A", "B", "C"], outs: ["M"],
            palette: Palettes.allGates,
            fn: { v in
                let n = (v[0] ? 1 : 0) + (v[1] ? 1 : 0) + (v[2] ? 1 : 0)
                return [n >= 2]
            },
            build: { b in
                let a = b.inp(0), bb = b.inp(1), c = b.inp(2)
                b.out(0, b.g(.or, b.g(.or, b.g(.and, a, bb), b.g(.and, a, c)), b.g(.and, bb, c)))
            }))

        out.append(comb(26, 3, "Two-Bit Adder",
            "Add two two-bit numbers. The low bits have nothing coming in, so a half adder is enough there; the high bits need the full one.",
            hint: "Half adder on bit 0, full adder on bit 1, carry chained between them.",
            ins: ["A1", "A0", "B1", "B0"], outs: ["S1", "S0", "C"],
            palette: [.and, .or, .xor, .not, .junction],
            chipIds: ["halfadder", "fulladder"],
            fn: { v in
                let s = lgwValue(v, 0, 2) + lgwValue(v, 2, 2)
                let bits = lgwBits(s, 3)
                return [bits[1], bits[2], bits[0]]
            },
            build: { b in
                let a1 = b.inp(0), a0 = b.inp(1), b1 = b.inp(2), b0 = b.inp(3)
                let h = b.chip("halfadder", [a0, b0])
                let f = b.chip("fulladder", [a1, b1, h[1]])
                b.out(0, f[0]); b.out(1, h[0]); b.out(2, f[1])
            }))

        out.append(comb(27, 3, "Four-Bit Ripple Carry",
            "Four full adders in a chain. The carry ripples from the least significant bit to the most, and the whole word is added in one pass.",
            hint: "Wire Cin into the bit-0 adder, then each adder's Cout into the next adder's Cin.",
            ins: ["A3", "A2", "A1", "A0", "B3", "B2", "B1", "B0", "Cin"],
            outs: ["S3", "S2", "S1", "S0", "Cout"],
            palette: [.and, .or, .xor, .not, .junction],
            chipIds: ["halfadder", "fulladder"],
            unlocks: ChipUnlock(id: "adder4", name: "4-Bit Adder",
                                blurb: "Two four-bit words plus a carry in, five bits out."),
            fn: { v in
                let s = lgwValue(v, 0, 4) + lgwValue(v, 4, 4) + (v[8] ? 1 : 0)
                let bits = lgwBits(s, 5)
                return [bits[1], bits[2], bits[3], bits[4], bits[0]]
            },
            build: { b in
                let a = (0..<4).map { b.inp($0) }
                let bs = (0..<4).map { b.inp(4 + $0) }
                let cin = b.inp(8)
                let f0 = b.chip("fulladder", [a[3], bs[3], cin])
                let f1 = b.chip("fulladder", [a[2], bs[2], f0[1]])
                let f2 = b.chip("fulladder", [a[1], bs[1], f1[1]])
                let f3 = b.chip("fulladder", [a[0], bs[0], f2[1]])
                b.out(0, f3[0]); b.out(1, f2[0]); b.out(2, f1[0]); b.out(3, f0[0])
                b.out(4, f3[1])
            }))

        out.append(comb(28, 3, "Overflow Flag",
            "Signed overflow happens when two numbers of the same sign produce a sum of the opposite sign. Light V when that happens.",
            hint: "V equals (A3 equals B3) AND (S3 differs from A3). One XNOR, one XOR, one AND.",
            ins: ["A3", "B3", "S3"], outs: ["V"],
            palette: Palettes.allGates,
            fn: { v in [(v[0] == v[1]) && (v[2] != v[0])] },
            build: { b in
                let a = b.inp(0), bb = b.inp(1), s = b.inp(2)
                b.out(0, b.g(.and, b.g(.xnor, a, bb), b.g(.xor, a, s)))
            }))

        out.append(comb(29, 3, "Ones Complement",
            "Flip every bit of a four-bit word. Four inverters, nothing clever, and it is the first half of negation.",
            hint: "One NOT per bit.",
            ins: ["A3", "A2", "A1", "A0"], outs: ["Y3", "Y2", "Y1", "Y0"],
            palette: [.not, .buffer, .junction],
            fn: { v in [!v[0], !v[1], !v[2], !v[3]] },
            build: { b in
                for i in 0..<4 { b.out(i, b.g(.not, b.inp(i))) }
            }))

        out.append(comb(30, 3, "Increment By One",
            "Add one to a four-bit word and let it wrap around at sixteen. A chain of half adders is far cheaper here than a full adder.",
            hint: "Half-add bit 0 with a constant 1, then chain each carry into the next half adder.",
            ins: ["A3", "A2", "A1", "A0"], outs: ["Y3", "Y2", "Y1", "Y0"],
            palette: [.and, .or, .xor, .not, .const0, .const1, .junction],
            chipIds: ["halfadder"],
            fn: { v in
                let n = (lgwValue(v, 0, 4) + 1) % 16
                return lgwBits(n, 4)
            },
            build: { b in
                let a = (0..<4).map { b.inp($0) }
                let one = b.lit(true)
                let h0 = b.chip("halfadder", [a[3], one])
                let h1 = b.chip("halfadder", [a[2], h0[1]])
                let h2 = b.chip("halfadder", [a[1], h1[1]])
                let h3 = b.chip("halfadder", [a[0], h2[1]])
                b.out(0, h3[0]); b.out(1, h2[0]); b.out(2, h1[0]); b.out(3, h0[0])
            }))

        out.append(comb(31, 3, "Two's Complement",
            "Negate a four-bit word: invert every bit, then add one. Sixteen minus A, wrapping at sixteen.",
            hint: "Four NOT gates feeding the increment circuit you built last level.",
            ins: ["A3", "A2", "A1", "A0"], outs: ["Y3", "Y2", "Y1", "Y0"],
            palette: [.not, .and, .or, .xor, .const0, .const1, .junction],
            chipIds: ["halfadder"],
            fn: { v in
                let n = (16 - lgwValue(v, 0, 4)) % 16
                return lgwBits(n, 4)
            },
            build: { b in
                let a = (0..<4).map { b.g(.not, b.inp($0)) }
                let one = b.lit(true)
                let h0 = b.chip("halfadder", [a[3], one])
                let h1 = b.chip("halfadder", [a[2], h0[1]])
                let h2 = b.chip("halfadder", [a[1], h1[1]])
                let h3 = b.chip("halfadder", [a[0], h2[1]])
                b.out(0, h3[0]); b.out(1, h2[0]); b.out(2, h1[0]); b.out(3, h0[0])
            }))

        out.append(comb(32, 3, "Four-Bit Subtractor",
            "A minus B, wrapping at sixteen. Do not build a subtractor: invert B, add, and force the carry in high. That is two's complement arithmetic in one move.",
            hint: "Four NOTs on B, then the 4-bit adder with Cin tied to constant 1.",
            ins: ["A3", "A2", "A1", "A0", "B3", "B2", "B1", "B0"],
            outs: ["D3", "D2", "D1", "D0"],
            palette: [.not, .and, .or, .xor, .const0, .const1, .junction],
            chipIds: ["adder4"],
            fn: { v in
                let d = (lgwValue(v, 0, 4) - lgwValue(v, 4, 4) + 16) % 16
                return lgwBits(d, 4)
            },
            build: { b in
                let a = (0..<4).map { b.inp($0) }
                let nb = (0..<4).map { b.g(.not, b.inp(4 + $0)) }
                let r = b.chip("adder4", [a[0], a[1], a[2], a[3],
                                          nb[0], nb[1], nb[2], nb[3], b.lit(true)])
                for i in 0..<4 { b.out(i, r[i]) }
            }))

        out.append(comb(33, 3, "Borrow Detect",
            "Light the lamp when A is smaller than B. The subtractor already knows: its carry out goes low exactly when a borrow was needed.",
            hint: "Build the subtractor, then invert its carry out. Nothing else is required.",
            ins: ["A3", "A2", "A1", "A0", "B3", "B2", "B1", "B0"], outs: ["BORROW"],
            palette: [.not, .and, .or, .xor, .const0, .const1, .junction],
            chipIds: ["adder4"],
            fn: { v in [lgwValue(v, 0, 4) < lgwValue(v, 4, 4)] },
            build: { b in
                let a = (0..<4).map { b.inp($0) }
                let nb = (0..<4).map { b.g(.not, b.inp(4 + $0)) }
                let r = b.chip("adder4", [a[0], a[1], a[2], a[3],
                                          nb[0], nb[1], nb[2], nb[3], b.lit(true)])
                b.out(0, b.g(.not, r[4]))
            }))

        out.append(comb(34, 3, "Bit Sum Counter",
            "Count how many of the three switches are on and show the answer in binary. You have already built this circuit under another name.",
            hint: "A full adder counts its three inputs: the sum bit is the low bit of the count, the carry is the high bit.",
            ins: ["A", "B", "C"], outs: ["N1", "N0"],
            palette: [.and, .or, .xor, .not, .junction],
            chipIds: ["halfadder", "fulladder"],
            fn: { v in
                let n = (v[0] ? 1 : 0) + (v[1] ? 1 : 0) + (v[2] ? 1 : 0)
                let bits = lgwBits(n, 2)
                return [bits[0], bits[1]]
            },
            build: { b in
                let f = b.chip("fulladder", [b.inp(0), b.inp(1), b.inp(2)])
                b.out(0, f[1]); b.out(1, f[0])
            }))

        out.append(comb(35, 3, "Shift Left Is Free",
            "Double a four-bit number. Multiplying by two in binary is not arithmetic at all, it is a renaming of the wires, and it costs nothing.",
            hint: "Y4 is A3, Y3 is A2, and so on down. Y0 is a hard constant 0.",
            ins: ["A3", "A2", "A1", "A0"], outs: ["Y4", "Y3", "Y2", "Y1", "Y0"],
            palette: [.buffer, .junction, .const0, .const1],
            fn: { v in
                let n = lgwValue(v, 0, 4) * 2
                return lgwBits(n, 5)
            },
            build: { b in
                for i in 0..<4 { b.out(i, b.inp(i)) }
                b.out(4, b.lit(false))
            }))

        return out
    }

    // MARK: - Chapter 4: Routing

    func chapterRouting() -> [LogicGateLevel] {
        var out: [LogicGateLevel] = []

        out.append(comb(36, 4, "Two-Way Select",
            "A multiplexer picks one of two inputs. When S is low the lamp follows A, when S is high it follows B.",
            hint: "AND A with NOT S, AND B with S, then OR the two results together.",
            ins: ["A", "B", "S"], outs: ["Y"],
            palette: Palettes.allGates,
            unlocks: ChipUnlock(id: "mux21", name: "2:1 Mux",
                                blurb: "Selects A or B according to S. The traffic valve of digital design."),
            fn: { v in [v[2] ? v[1] : v[0]] },
            build: { b in
                let a = b.inp(0), bb = b.inp(1), s = b.inp(2)
                b.out(0, b.g(.or, b.g(.and, a, b.g(.not, s)), b.g(.and, bb, s)))
            }))

        out.append(comb(37, 4, "Mux From NAND",
            "The same selector, but the palette holds nothing except NAND. It comes out cheaper than the textbook version.",
            hint: "Invert S with a NAND, NAND it with A, NAND S with B, then NAND those two together.",
            ins: ["A", "B", "S"], outs: ["Y"],
            palette: Palettes.nandOnly,
            fn: { v in [v[2] ? v[1] : v[0]] },
            build: { b in
                let a = b.inp(0), bb = b.inp(1), s = b.inp(2)
                let ns = b.g(.nand, s, s)
                b.out(0, b.g(.nand, b.g(.nand, a, ns), b.g(.nand, bb, s)))
            }))

        out.append(comb(38, 4, "One-To-Two Demux",
            "The opposite of a multiplexer: one input, and S decides which of the two outputs receives it. The other stays dark.",
            hint: "Y0 is D AND NOT S. Y1 is D AND S.",
            ins: ["D", "S"], outs: ["Y0", "Y1"],
            palette: Palettes.allGates,
            fn: { v in [v[0] && !v[1], v[0] && v[1]] },
            build: { b in
                let d = b.inp(0), s = b.inp(1)
                b.out(0, b.g(.and, d, b.g(.not, s)))
                b.out(1, b.g(.and, d, s))
            }))

        out.append(comb(39, 4, "Four-Way Select",
            "Three 2:1 multiplexers make a 4:1. The low select bit chooses inside each pair, the high bit chooses between the pairs.",
            hint: "Mux D0 with D1 on S0, mux D2 with D3 on S0, then mux those two on S1.",
            ins: ["D0", "D1", "D2", "D3", "S1", "S0"], outs: ["Y"],
            palette: [.and, .or, .not, .nand, .junction],
            chipIds: ["mux21"],
            unlocks: ChipUnlock(id: "mux41", name: "4:1 Mux",
                                blurb: "Two select bits choose one of four data lines."),
            fn: { v in
                let s = lgwValue(v, 4, 2)
                return [v[s]]
            },
            build: { b in
                let d = (0..<4).map { b.inp($0) }
                let s1 = b.inp(4), s0 = b.inp(5)
                let m0 = b.chip("mux21", [d[0], d[1], s0])
                let m1 = b.chip("mux21", [d[2], d[3], s0])
                b.out(0, b.chip("mux21", [m0[0], m1[0], s1])[0])
            }))

        out.append(comb(40, 4, "Two-To-Four Decoder",
            "Turn a two-bit number into one hot line out of four. The enable input blanks every output when it is low.",
            hint: "Each output is a three-input AND of the right polarity of A1, A0 and EN.",
            ins: ["A1", "A0", "EN"], outs: ["Y0", "Y1", "Y2", "Y3"],
            palette: Palettes.allGates,
            unlocks: ChipUnlock(id: "dec24", name: "2:4 Decoder",
                                blurb: "One hot output per input code, gated by enable."),
            fn: { v in
                let idx = lgwValue(v, 0, 2)
                return (0..<4).map { v[2] && $0 == idx }
            },
            build: { b in
                let a1 = b.inp(0), a0 = b.inp(1), en = b.inp(2)
                let n1 = b.g(.not, a1), n0 = b.g(.not, a0)
                b.out(0, b.g(.and3, n1, n0, en))
                b.out(1, b.g(.and3, n1, a0, en))
                b.out(2, b.g(.and3, a1, n0, en))
                b.out(3, b.g(.and3, a1, a0, en))
            }))

        out.append(comb(41, 4, "Three-To-Eight Decoder",
            "Eight one-hot lines from three address bits. Two of the decoders you just built, split by the top address bit.",
            hint: "Feed A2 into one decoder's enable and NOT A2 into the other's. Both share A1 and A0.",
            ins: ["A2", "A1", "A0"], outs: ["Y0", "Y1", "Y2", "Y3", "Y4", "Y5", "Y6", "Y7"],
            palette: [.not, .and, .or, .and3, .junction, .const1, .const0],
            chipIds: ["dec24"],
            fn: { v in
                let idx = lgwValue(v, 0, 3)
                return (0..<8).map { $0 == idx }
            },
            build: { b in
                let a2 = b.inp(0), a1 = b.inp(1), a0 = b.inp(2)
                let low = b.chip("dec24", [a1, a0, b.g(.not, a2)])
                let high = b.chip("dec24", [a1, a0, a2])
                for i in 0..<4 { b.out(i, low[i]) }
                for i in 0..<4 { b.out(4 + i, high[i]) }
            }))

        out.append(comb(42, 4, "Priority Encoder",
            "Four request lines come in. Report the index of the highest one that is asserted, and raise V whenever any request is present.",
            hint: "A1 is I3 OR I2. A0 is I3 OR (NOT I2 AND I1). V is the OR of everything.",
            ins: ["I3", "I2", "I1", "I0"], outs: ["V", "A1", "A0"],
            palette: Palettes.allGates,
            fn: { v in
                var idx = 0
                var any = false
                for i in 0..<4 where v[i] {
                    idx = 3 - i
                    any = true
                    break
                }
                let bits = lgwBits(idx, 2)
                return [any, bits[0], bits[1]]
            },
            build: { b in
                let i3 = b.inp(0), i2 = b.inp(1), i1 = b.inp(2), i0 = b.inp(3)
                let hi = b.g(.or, i3, i2)
                let lo = b.g(.or, i1, i0)
                b.out(0, b.g(.or, hi, lo))
                b.out(1, hi)
                b.out(2, b.g(.or, i3, b.g(.and, b.g(.not, i2), i1)))
            }))

        out.append(comb(43, 4, "Output Enable",
            "A two-bit bus that goes quiet on command. When EN is low both outputs must read zero regardless of the data.",
            hint: "One AND gate per bit, with EN as the second input on both.",
            ins: ["D1", "D0", "EN"], outs: ["Y1", "Y0"],
            palette: Palettes.allGates,
            fn: { v in [v[0] && v[2], v[1] && v[2]] },
            build: { b in
                let d1 = b.inp(0), d0 = b.inp(1), en = b.inp(2)
                b.out(0, b.g(.and, d1, en))
                b.out(1, b.g(.and, d0, en))
            }))

        out.append(comb(44, 4, "Rotate By One",
            "When ROT is low the word passes straight through. When it is high every bit moves up one place and the top bit wraps around to the bottom.",
            hint: "Four 2:1 multiplexers, all sharing ROT as their select. Watch which neighbour feeds each one.",
            ins: ["D3", "D2", "D1", "D0", "ROT"], outs: ["Y3", "Y2", "Y1", "Y0"],
            palette: [.and, .or, .not, .junction],
            chipIds: ["mux21"],
            fn: { v in
                let d = Array(v[0..<4])
                if !v[4] { return d }
                return [d[1], d[2], d[3], d[0]]
            },
            build: { b in
                let d = (0..<4).map { b.inp($0) }
                let r = b.inp(4)
                b.out(0, b.chip("mux21", [d[0], d[1], r])[0])
                b.out(1, b.chip("mux21", [d[1], d[2], r])[0])
                b.out(2, b.chip("mux21", [d[2], d[3], r])[0])
                b.out(3, b.chip("mux21", [d[3], d[0], r])[0])
            }))

        out.append(comb(45, 4, "Two-Bit Bus Select",
            "Two whole two-bit words arrive; S decides which one reaches the output. Multiplexers scale by simply repeating per bit.",
            hint: "One 2:1 mux per bit position, both driven by the same S.",
            ins: ["A1", "A0", "B1", "B0", "S"], outs: ["Y1", "Y0"],
            palette: [.and, .or, .not, .junction],
            chipIds: ["mux21"],
            fn: { v in v[4] ? [v[2], v[3]] : [v[0], v[1]] },
            build: { b in
                let a1 = b.inp(0), a0 = b.inp(1), b1 = b.inp(2), b0 = b.inp(3), s = b.inp(4)
                b.out(0, b.chip("mux21", [a1, b1, s])[0])
                b.out(1, b.chip("mux21", [a0, b0, s])[0])
            }))

        out.append(comb(46, 4, "Decoder-Built Mux",
            "The same 4:1 selector, but built the other way round: decode the address into one-hot lines, gate each data line with its own, then merge. No mux chips allowed.",
            hint: "Tie the decoder's enable to constant 1, AND each data line with its select line, then OR all four together.",
            ins: ["D0", "D1", "D2", "D3", "S1", "S0"], outs: ["Y"],
            palette: [.and, .or, .not, .and3, .junction, .const0, .const1],
            chipIds: ["dec24"],
            fn: { v in
                let s = lgwValue(v, 4, 2)
                return [v[s]]
            },
            build: { b in
                let d = (0..<4).map { b.inp($0) }
                let s1 = b.inp(4), s0 = b.inp(5)
                let sel = b.chip("dec24", [s1, s0, b.lit(true)])
                let g0 = b.g(.and, d[0], sel[0])
                let g1 = b.g(.and, d[1], sel[1])
                let g2 = b.g(.and, d[2], sel[2])
                let g3 = b.g(.and, d[3], sel[3])
                b.out(0, b.g(.or, b.g(.or, g0, g1), b.g(.or, g2, g3)))
            }))

        out.append(comb(47, 4, "Signal Router",
            "One data line, four destinations, an address that says which. Every unselected output must stay dark.",
            hint: "The decoder's enable input is a data path. Feed D into it and the address does the rest.",
            ins: ["D", "S1", "S0"], outs: ["Y0", "Y1", "Y2", "Y3"],
            palette: [.and, .or, .not, .and3, .junction],
            chipIds: ["dec24"],
            fn: { v in
                let idx = lgwValue(v, 1, 2)
                return (0..<4).map { v[0] && $0 == idx }
            },
            build: { b in
                let d = b.inp(0), s1 = b.inp(1), s0 = b.inp(2)
                let r = b.chip("dec24", [s1, s0, d])
                for i in 0..<4 { b.out(i, r[i]) }
            }))

        out.append(comb(48, 4, "Multiplexer Tree",
            "Eight data lines, three address bits. Two 4:1 multiplexers and one 2:1 on top: selectors compose exactly like the adders did.",
            hint: "S1 and S0 go to both 4:1 muxes. S2 chooses between their outputs.",
            ins: ["D0", "D1", "D2", "D3", "D4", "D5", "D6", "D7", "S2", "S1", "S0"],
            outs: ["Y"],
            palette: [.and, .or, .not, .junction],
            chipIds: ["mux21", "mux41"],
            fn: { v in
                let s = lgwValue(v, 8, 3)
                return [v[s]]
            },
            build: { b in
                let d = (0..<8).map { b.inp($0) }
                let s2 = b.inp(8), s1 = b.inp(9), s0 = b.inp(10)
                let m0 = b.chip("mux41", [d[0], d[1], d[2], d[3], s1, s0])
                let m1 = b.chip("mux41", [d[4], d[5], d[6], d[7], s1, s0])
                b.out(0, b.chip("mux21", [m0[0], m1[0], s2])[0])
            }))

        return out
    }
}
