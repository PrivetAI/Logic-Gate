import Foundation

extension LevelMaker {

    // MARK: - Chapter 5: Comparison

    func chapterComparison() -> [LogicGateLevel] {
        var out: [LogicGateLevel] = []

        out.append(comb(49, 5, "Equal Bits",
            "Light the lamp when the two switches carry the same value. Equality on one bit is a single gate.",
            hint: "XNOR is the equality gate. It is XOR with the answer flipped.",
            ins: ["A", "B"], outs: ["EQ"],
            palette: Palettes.allGates,
            fn: { v in [v[0] == v[1]] },
            build: { b in
                b.out(0, b.g(.xnor, b.inp(0), b.inp(1)))
            }))

        out.append(comb(50, 5, "One-Bit Comparator",
            "Three answers about two bits: is A bigger, are they equal, is A smaller. This little block cascades into comparators of any width.",
            hint: "GT is A AND NOT B. LT is NOT A AND B. EQ is the XNOR you just built.",
            ins: ["A", "B"], outs: ["GT", "EQ", "LT"],
            palette: Palettes.allGates,
            unlocks: ChipUnlock(id: "cmp1", name: "1-Bit Comparator",
                                blurb: "Greater, equal and less for a single bit position."),
            fn: { v in [v[0] && !v[1], v[0] == v[1], !v[0] && v[1]] },
            build: { b in
                let a = b.inp(0), bb = b.inp(1)
                b.out(0, b.g(.and, a, b.g(.not, bb)))
                b.out(1, b.g(.xnor, a, bb))
                b.out(2, b.g(.and, b.g(.not, a), bb))
            }))

        out.append(comb(51, 5, "Two-Bit Equality",
            "Two whole two-bit words are equal only when every bit position agrees.",
            hint: "One XNOR per bit position, then AND the two results.",
            ins: ["A1", "A0", "B1", "B0"], outs: ["EQ"],
            palette: Palettes.allGates,
            fn: { v in [lgwValue(v, 0, 2) == lgwValue(v, 2, 2)] },
            build: { b in
                let a1 = b.inp(0), a0 = b.inp(1), b1 = b.inp(2), b0 = b.inp(3)
                b.out(0, b.g(.and, b.g(.xnor, a1, b1), b.g(.xnor, a0, b0)))
            }))

        out.append(comb(52, 5, "Four-Bit Equality",
            "The same idea at four bits wide. The three-input AND gate earns its place here.",
            hint: "Four XNORs, then a 3-input AND and a plain AND to bring all four together.",
            ins: ["A3", "A2", "A1", "A0", "B3", "B2", "B1", "B0"], outs: ["EQ"],
            palette: Palettes.allGates,
            fn: { v in [lgwValue(v, 0, 4) == lgwValue(v, 4, 4)] },
            build: { b in
                let a = (0..<4).map { b.inp($0) }
                let bs = (0..<4).map { b.inp(4 + $0) }
                let e = (0..<4).map { b.g(.xnor, a[$0], bs[$0]) }
                b.out(0, b.g(.and, b.g(.and3, e[0], e[1], e[2]), e[3]))
            }))

        out.append(comb(53, 5, "Greater Than",
            "Is the two-bit number A larger than B? Compare the high bits first; only if they tie does the low bit get a say.",
            hint: "GT equals GT of the high bits, OR (high bits equal AND GT of the low bits).",
            ins: ["A1", "A0", "B1", "B0"], outs: ["GT"],
            palette: [.and, .or, .not, .xnor, .junction],
            chipIds: ["cmp1"],
            fn: { v in [lgwValue(v, 0, 2) > lgwValue(v, 2, 2)] },
            build: { b in
                let a1 = b.inp(0), a0 = b.inp(1), b1 = b.inp(2), b0 = b.inp(3)
                let hi = b.chip("cmp1", [a1, b1])
                let lo = b.chip("cmp1", [a0, b0])
                b.out(0, b.g(.or, hi[0], b.g(.and, hi[1], lo[0])))
            }))

        out.append(comb(54, 5, "Four-Bit Magnitude",
            "The full comparator: greater, equal, less, on four-bit words. A cascade of single-bit comparators with a priority chain on top.",
            hint: "GT is G3, or E3 and G2, or E3 E2 and G1, or E3 E2 E1 and G0. EQ is all four E terms. LT is neither of those two.",
            ins: ["A3", "A2", "A1", "A0", "B3", "B2", "B1", "B0"], outs: ["GT", "EQ", "LT"],
            palette: [.and, .or, .not, .nor, .and3, .xnor, .junction],
            chipIds: ["cmp1"],
            unlocks: ChipUnlock(id: "cmp4", name: "4-Bit Comparator",
                                blurb: "Full magnitude comparison of two four-bit words."),
            fn: { v in
                let a = lgwValue(v, 0, 4), bb = lgwValue(v, 4, 4)
                return [a > bb, a == bb, a < bb]
            },
            build: { b in
                let a = (0..<4).map { b.inp($0) }
                let bs = (0..<4).map { b.inp(4 + $0) }
                let c = (0..<4).map { b.chip("cmp1", [a[$0], bs[$0]]) }
                let e32 = b.g(.and, c[0][1], c[1][1])
                let e321 = b.g(.and, e32, c[2][1])
                let eq = b.g(.and, e321, c[3][1])
                let t1 = b.g(.and, c[0][1], c[1][0])
                let t2 = b.g(.and, e32, c[2][0])
                let t3 = b.g(.and, e321, c[3][0])
                let gt = b.g(.or, b.g(.or, c[0][0], t1), b.g(.or, t2, t3))
                b.out(0, gt)
                b.out(1, eq)
                b.out(2, b.g(.nor, gt, eq))
            }))

        out.append(comb(55, 5, "Minimum Selector",
            "Two two-bit numbers arrive. Send the smaller of them to the output.",
            hint: "Work out whether A is greater, then use that as the select line of a pair of multiplexers.",
            ins: ["A1", "A0", "B1", "B0"], outs: ["M1", "M0"],
            palette: [.and, .or, .not, .xnor, .junction],
            chipIds: ["cmp1", "mux21"],
            fn: { v in
                let a = lgwValue(v, 0, 2), bb = lgwValue(v, 2, 2)
                return lgwBits(min(a, bb), 2)
            },
            build: { b in
                let a1 = b.inp(0), a0 = b.inp(1), b1 = b.inp(2), b0 = b.inp(3)
                let hi = b.chip("cmp1", [a1, b1])
                let lo = b.chip("cmp1", [a0, b0])
                let gt = b.g(.or, hi[0], b.g(.and, hi[1], lo[0]))
                b.out(0, b.chip("mux21", [a1, b1, gt])[0])
                b.out(1, b.chip("mux21", [a0, b0, gt])[0])
            }))

        out.append(comb(56, 5, "Maximum Selector",
            "Same pair of numbers, opposite answer. Send the larger one through.",
            hint: "It is the minimum circuit with the two multiplexer data inputs swapped over.",
            ins: ["A1", "A0", "B1", "B0"], outs: ["M1", "M0"],
            palette: [.and, .or, .not, .xnor, .junction],
            chipIds: ["cmp1", "mux21"],
            fn: { v in
                let a = lgwValue(v, 0, 2), bb = lgwValue(v, 2, 2)
                return lgwBits(max(a, bb), 2)
            },
            build: { b in
                let a1 = b.inp(0), a0 = b.inp(1), b1 = b.inp(2), b0 = b.inp(3)
                let hi = b.chip("cmp1", [a1, b1])
                let lo = b.chip("cmp1", [a0, b0])
                let gt = b.g(.or, hi[0], b.g(.and, hi[1], lo[0]))
                b.out(0, b.chip("mux21", [b1, a1, gt])[0])
                b.out(1, b.chip("mux21", [b0, a0, gt])[0])
            }))

        out.append(comb(57, 5, "Window Compare",
            "Light the lamp when the four-bit value sits between four and eleven inclusive. The obvious answer is two comparators. The real answer is one gate.",
            hint: "A is at least 4 exactly when A3 or A2 is set. A is at most 11 exactly when A3 and A2 are not both set. Put those together.",
            ins: ["A3", "A2", "A1", "A0"], outs: ["Y"],
            palette: Palettes.allGates,
            fn: { v in
                let a = lgwValue(v, 0, 4)
                return [a >= 4 && a <= 11]
            },
            build: { b in
                let a3 = b.inp(0), a2 = b.inp(1)
                _ = b.inp(2); _ = b.inp(3)
                b.out(0, b.g(.xor, a3, a2))
            }))

        out.append(comb(58, 5, "Zero And All Ones",
            "Two flags off one word: ZERO when every bit is low, FULL when every bit is high. Detectors like these sit on the output of every arithmetic unit.",
            hint: "ZERO is a NOR tree. FULL is an AND tree. Neither needs more than three gates.",
            ins: ["A3", "A2", "A1", "A0"], outs: ["ZERO", "FULL"],
            palette: Palettes.allGates,
            fn: { v in
                let a = lgwValue(v, 0, 4)
                return [a == 0, a == 15]
            },
            build: { b in
                let a = (0..<4).map { b.inp($0) }
                b.out(0, b.g(.nor, b.g(.or, a[0], a[1]), b.g(.or, a[2], a[3])))
                b.out(1, b.g(.and, b.g(.and3, a[0], a[1], a[2]), a[3]))
            }))

        return out
    }
}
