import Foundation

extension LevelMaker {

    // MARK: - Chapter 1: Signals

    func chapterSignals() -> [LogicGateLevel] {
        var out: [LogicGateLevel] = []

        out.append(comb(1, 1, "Crossed Lines",
            "Three switches, three lamps, and the bench wiring is scrambled. X must follow C, Y must follow A, Z must follow B. Drag from an output pin to an input pin to lay a wire.",
            hint: "Drag from the small pin on the right of a switch straight across to the pin on the left of the lamp it belongs to. Wires cost nothing at all.",
            ins: ["A", "B", "C"], outs: ["X", "Y", "Z"],
            palette: Palettes.wiringOnly,
            fn: { v in [v[2], v[0], v[1]] },
            build: { b in
                let a = b.inp(0), bb = b.inp(1), c = b.inp(2)
                b.out(0, c); b.out(1, a); b.out(2, bb)
            }))

        out.append(comb(2, 1, "The Inverter",
            "The cheapest useful part in the shop. Each lamp must light when its own switch is OFF. Solve it and the whole circuit becomes a chip you can place in later puzzles.",
            hint: "One NOT gate per line. The bubble on its nose is the whole idea: whatever goes in comes out flipped.",
            ins: ["A", "B"], outs: ["X", "Y"],
            palette: [.not, .buffer, .junction],
            unlocks: ChipUnlock(id: "inverter", name: "Inverter Pair",
                                blurb: "Two independent inverters in one package. The first block on the abstraction ladder."),
            fn: { v in [!v[0], !v[1]] },
            build: { b in
                let a = b.inp(0), bb = b.inp(1)
                b.out(0, b.g(.not, a))
                b.out(1, b.g(.not, bb))
            }))

        out.append(comb(3, 1, "Both Or Nothing",
            "Light the lamp only when BOTH switches are on. This is conjunction, and it is the backbone of every enable line in a machine.",
            hint: "A single AND gate does it. Watch the truth table panel fill in as you wire.",
            ins: ["A", "B"], outs: ["Y"],
            palette: Palettes.allGates,
            fn: { v in [v[0] && v[1]] },
            build: { b in
                let a = b.inp(0), bb = b.inp(1)
                b.out(0, b.g(.and, a, bb))
            }))

        out.append(comb(4, 1, "Either Way",
            "Light the lamp when at least one switch is on. Disjunction: the OR gate.",
            hint: "One OR gate. Note the curved back on its body, that is how you tell it from AND at a glance.",
            ins: ["A", "B"], outs: ["Y"],
            palette: Palettes.allGates,
            fn: { v in [v[0] || v[1]] },
            build: { b in
                let a = b.inp(0), bb = b.inp(1)
                b.out(0, b.g(.or, a, bb))
            }))

        out.append(comb(5, 1, "Not Both",
            "The lamp goes dark only when both switches are on. NAND is the cheapest two-input gate in the catalogue for a reason: in silicon it is genuinely smaller than AND.",
            hint: "A single NAND. Cost 4 against AND's 6.",
            ins: ["A", "B"], outs: ["Y"],
            palette: Palettes.allGates,
            fn: { v in [!(v[0] && v[1])] },
            build: { b in
                let a = b.inp(0), bb = b.inp(1)
                b.out(0, b.g(.nand, a, bb))
            }))

        out.append(comb(6, 1, "Neither",
            "The lamp lights only when both switches are off. NOR: the other cheap universal gate.",
            hint: "One NOR gate, cost 4.",
            ins: ["A", "B"], outs: ["Y"],
            palette: Palettes.allGates,
            fn: { v in [!(v[0] || v[1])] },
            build: { b in
                let a = b.inp(0), bb = b.inp(1)
                b.out(0, b.g(.nor, a, bb))
            }))

        out.append(comb(7, 1, "Fan-Out",
            "One signal, three destinations. X and Y follow the switch, Z is its opposite. A single output pin can drive as many inputs as you like.",
            hint: "Drop a junction node to keep the wiring tidy, then hang a NOT off one of its taps.",
            ins: ["A"], outs: ["X", "Y", "Z"],
            palette: [.not, .buffer, .junction],
            fn: { v in [v[0], v[0], !v[0]] },
            build: { b in
                let a = b.inp(0)
                let j = b.g(.junction, a)
                b.out(0, Tap(j.part, 0))
                b.out(1, Tap(j.part, 1))
                b.out(2, b.g(.not, Tap(j.part, 2)))
            }))

        out.append(comb(8, 1, "Hard Wired",
            "X must always be lit, Y must always be dark, and Z must follow the switch inverted. Two of those three do not need the switch at all.",
            hint: "Constant 1 and constant 0 are free parts. Wire them straight to the lamps and spend nothing.",
            ins: ["A"], outs: ["X", "Y", "Z"],
            palette: [.not, .buffer, .junction, .const0, .const1],
            fn: { v in [true, false, !v[0]] },
            build: { b in
                let a = b.inp(0)
                b.out(0, b.lit(true))
                b.out(1, b.lit(false))
                b.out(2, b.g(.not, a))
            }))

        out.append(comb(9, 1, "Exclusive",
            "Light the lamp when the switches disagree. Exclusive-OR is the difference detector, and it is the single most useful gate in arithmetic.",
            hint: "One XOR. It is expensive at cost 10 because inside it really is several gates.",
            ins: ["A", "B"], outs: ["Y"],
            palette: Palettes.allGates,
            fn: { v in [v[0] != v[1]] },
            build: { b in
                let a = b.inp(0), bb = b.inp(1)
                b.out(0, b.g(.xor, a, bb))
            }))

        out.append(comb(10, 1, "Odd Count",
            "Three switches. Light the lamp when an odd number of them are on. This is parity, and you will meet it again in chapter seven.",
            hint: "XOR chains. Feed A and B into one XOR, then that result and C into another.",
            ins: ["A", "B", "C"], outs: ["Y"],
            palette: Palettes.allGates,
            fn: { v in [(v[0] != v[1]) != v[2]] },
            build: { b in
                let a = b.inp(0), bb = b.inp(1), c = b.inp(2)
                b.out(0, b.g(.xor, b.g(.xor, a, bb), c))
            }))

        return out
    }

    // MARK: - Chapter 2: Boolean Laws

    func chapterBooleanLaws() -> [LogicGateLevel] {
        var out: [LogicGateLevel] = []

        out.append(comb(11, 2, "NAND Is Enough: NOT",
            "The palette has been stripped down to a single gate type. Build an inverter on Y and a clean pass-through on Z, using NAND and nothing else.",
            hint: "Tie both NAND inputs to the same signal: NAND(A, A) is NOT A. Do it twice in a row and you are back where you started, which is your buffer.",
            ins: ["A"], outs: ["Y", "Z"],
            palette: Palettes.nandOnly,
            fn: { v in [!v[0], v[0]] },
            build: { b in
                let a = b.inp(0)
                let n = b.g(.nand, a, a)
                b.out(0, n)
                b.out(1, b.g(.nand, n, n))
            }))

        out.append(comb(12, 2, "NAND Is Enough: AND",
            "Still NAND only. Produce a plain AND.",
            hint: "NAND then invert. The inverter is another NAND with both inputs tied together.",
            ins: ["A", "B"], outs: ["Y"],
            palette: Palettes.nandOnly,
            fn: { v in [v[0] && v[1]] },
            build: { b in
                let a = b.inp(0), bb = b.inp(1)
                let n = b.g(.nand, a, bb)
                b.out(0, b.g(.nand, n, n))
            }))

        out.append(comb(13, 2, "NAND Is Enough: OR",
            "Still NAND only. Produce OR. De Morgan is doing the work here even if you have not met him yet.",
            hint: "Invert both inputs first, then NAND them: NAND(NOT A, NOT B) equals A OR B.",
            ins: ["A", "B"], outs: ["Y"],
            palette: Palettes.nandOnly,
            fn: { v in [v[0] || v[1]] },
            build: { b in
                let a = b.inp(0), bb = b.inp(1)
                b.out(0, b.g(.nand, b.g(.nand, a, a), b.g(.nand, bb, bb)))
            }))

        out.append(comb(14, 2, "NOR Is Enough: NOT",
            "NOR is the other universal gate. Same two jobs as level eleven, different body: an inverter on Y and a pass-through on Z.",
            hint: "NOR(A, A) is NOT A. Two of them back to back give you the buffer.",
            ins: ["A"], outs: ["Y", "Z"],
            palette: Palettes.norOnly,
            fn: { v in [!v[0], v[0]] },
            build: { b in
                let a = b.inp(0)
                let n = b.g(.nor, a, a)
                b.out(0, n)
                b.out(1, b.g(.nor, n, n))
            }))

        out.append(comb(15, 2, "NOR Is Enough: OR",
            "NOR only. Produce OR.",
            hint: "NOR then invert with a second NOR.",
            ins: ["A", "B"], outs: ["Y"],
            palette: Palettes.norOnly,
            fn: { v in [v[0] || v[1]] },
            build: { b in
                let a = b.inp(0), bb = b.inp(1)
                let n = b.g(.nor, a, bb)
                b.out(0, b.g(.nor, n, n))
            }))

        out.append(comb(16, 2, "NOR Is Enough: AND",
            "NOR only. Produce AND. Notice the mirror image of level thirteen.",
            hint: "Invert both inputs, then NOR them.",
            ins: ["A", "B"], outs: ["Y"],
            palette: Palettes.norOnly,
            fn: { v in [v[0] && v[1]] },
            build: { b in
                let a = b.inp(0), bb = b.inp(1)
                b.out(0, b.g(.nor, b.g(.nor, a, a), b.g(.nor, bb, bb)))
            }))

        out.append(comb(17, 2, "De Morgan One",
            "NOT (A AND B) with no AND and no NAND anywhere in the palette. De Morgan's first law says you do not need them.",
            hint: "NOT(A AND B) equals (NOT A) OR (NOT B). Break the bar, flip the operator.",
            ins: ["A", "B"], outs: ["Y"],
            palette: [.not, .or, .buffer, .junction],
            fn: { v in [!(v[0] && v[1])] },
            build: { b in
                let a = b.inp(0), bb = b.inp(1)
                b.out(0, b.g(.or, b.g(.not, a), b.g(.not, bb)))
            }))

        out.append(comb(18, 2, "De Morgan Two",
            "NOT (A OR B) with no OR and no NOR in the palette. The second law, and the mirror of the first.",
            hint: "NOT(A OR B) equals (NOT A) AND (NOT B).",
            ins: ["A", "B"], outs: ["Y"],
            palette: [.not, .and, .buffer, .junction],
            fn: { v in [!(v[0] || v[1])] },
            build: { b in
                let a = b.inp(0), bb = b.inp(1)
                b.out(0, b.g(.and, b.g(.not, a), b.g(.not, bb)))
            }))

        out.append(comb(19, 2, "XOR From NAND",
            "The classic. Four NAND gates, no more, and you have exclusive-OR. Every fan-out you need is already legal.",
            hint: "Let N = NAND(A, B). Then XOR = NAND( NAND(A, N), NAND(B, N) ).",
            ins: ["A", "B"], outs: ["Y"],
            palette: Palettes.nandOnly,
            fn: { v in [v[0] != v[1]] },
            build: { b in
                let a = b.inp(0), bb = b.inp(1)
                let n = b.g(.nand, a, bb)
                b.out(0, b.g(.nand, b.g(.nand, a, n), b.g(.nand, bb, n)))
            }))

        out.append(comb(20, 2, "XNOR From NAND",
            "Equality out of four NANDs plus one more. Light the lamp when the switches agree.",
            hint: "Build the XOR from the previous level, then invert it with a fifth NAND.",
            ins: ["A", "B"], outs: ["Y"],
            palette: Palettes.nandOnly,
            fn: { v in [v[0] == v[1]] },
            build: { b in
                let a = b.inp(0), bb = b.inp(1)
                let n = b.g(.nand, a, bb)
                let x = b.g(.nand, b.g(.nand, a, n), b.g(.nand, bb, n))
                b.out(0, b.g(.nand, x, x))
            }))

        out.append(comb(21, 2, "Absorption",
            "X must equal A AND (A OR B). Y must equal A OR (B AND C). One of those two expressions collapses to a bare wire. Find which.",
            hint: "A AND (A OR B) is just A, whatever B does. Absorption law: spend nothing on X.",
            ins: ["A", "B", "C"], outs: ["X", "Y"],
            palette: Palettes.allGates,
            fn: { v in [v[0], v[0] || (v[1] && v[2])] },
            build: { b in
                let a = b.inp(0), bb = b.inp(1), c = b.inp(2)
                b.out(0, a)
                b.out(1, b.g(.or, a, b.g(.and, bb, c)))
            }))

        out.append(comb(22, 2, "Consensus",
            "Y equals A AND B, OR NOT-A AND C, OR B AND C. That third term is redundant: the first two already cover every case it does. Prove it by leaving it out.",
            hint: "Two AND gates and one OR. The B AND C term is the consensus term and it is free to delete.",
            ins: ["A", "B", "C"], outs: ["Y"],
            palette: Palettes.allGates,
            fn: { v in [(v[0] && v[1]) || (!v[0] && v[2]) || (v[1] && v[2])] },
            build: { b in
                let a = b.inp(0), bb = b.inp(1), c = b.inp(2)
                b.out(0, b.g(.or, b.g(.and, a, bb), b.g(.and, b.g(.not, a), c)))
            }))

        return out
    }
}
