import SwiftUI

enum ReferenceWidget {
    case none
    case karnaugh
}

struct ReferenceEntry: Identifiable {
    let id: String
    let title: String
    let tag: String
    let summary: String
    let paragraphs: [String]
    /// Renders that level's reference circuit as a live diagram.
    let diagramLevel: Int?
    let diagramCaption: String
    let widget: ReferenceWidget
}

enum ReferenceLibrary {
    static let entries: [ReferenceEntry] = [
        ReferenceEntry(
            id: "boolean", title: "Boolean Algebra", tag: "Foundations",
            summary: "The arithmetic of true and false, and the identities worth memorising.",
            paragraphs: [
                "Boolean algebra works on exactly two values. AND behaves like multiplication, OR behaves like addition, and NOT flips a value. From those three every digital circuit in existence is assembled.",
                "The identities that save the most gates are: A AND 1 = A, A AND 0 = 0, A OR 1 = 1, A OR 0 = A, A AND A = A, A OR A = A, and A AND NOT A = 0. Each of them lets you delete hardware rather than build it.",
                "Two laws matter more than the rest on this bench. Absorption says A AND (A OR B) = A, so an entire branch of a circuit can vanish. The consensus theorem says AB + A'C + BC = AB + A'C, so a term that looks necessary is often already covered by its neighbours.",
                "Cost on this bench is measured in gate cost, not gate count. Simplifying an expression before you wire it is almost always cheaper than simplifying the wiring afterwards."
            ],
            diagramLevel: 22,
            diagramCaption: "Consensus: the BC term is redundant and never built.",
            widget: .none),

        ReferenceEntry(
            id: "truthtables", title: "Truth Tables", tag: "Foundations",
            summary: "The complete specification of any combinational circuit.",
            paragraphs: [
                "A combinational circuit has no memory: its outputs depend only on its inputs right now. That means a table listing every possible input combination and the required output completely defines it. Nothing else needs to be said.",
                "With n inputs the table has 2^n rows. Three inputs give eight rows, eight inputs give 256, and ten inputs give 1024. This bench checks every single row before awarding a star, which is why a circuit that works for the case you were thinking about can still fail verification.",
                "Reading a table into gates is mechanical. Take every row whose output is 1, write the AND of each input in its row polarity, then OR those product terms together. That is the canonical sum of products, and it is always correct and almost always wasteful.",
                "The interesting work is what happens next: collapsing that canonical form into something small. That is what Karnaugh maps and the algebraic identities are for."
            ],
            diagramLevel: 25,
            diagramCaption: "Majority of three, built straight from its three 1-rows.",
            widget: .none),

        ReferenceEntry(
            id: "nand", title: "NAND Universality", tag: "Foundations",
            summary: "Why a chip fab only really needs one kind of gate.",
            paragraphs: [
                "NAND is functionally complete: every Boolean function can be built from NAND gates alone. NOT is NAND with both inputs tied together. AND is a NAND followed by that inverter. OR is a NAND fed by two inverted inputs.",
                "NOR is complete in exactly the same way, with the roles of AND and OR swapped. Real logic families pick one and lean on it, because a single well-characterised cell is cheaper to design, verify and shrink than a zoo of them.",
                "In CMOS a two-input NAND is genuinely smaller and faster than a two-input AND, because AND is built as NAND plus an inverter. That is why NAND costs 4 on this bench and AND costs 6: the price list reflects real silicon, not a whim.",
                "The famous result of this is the four-gate XOR. It looks like a trick until you see it as NAND(NAND(A,N), NAND(B,N)) where N is NAND(A,B), and then it is just algebra."
            ],
            diagramLevel: 19,
            diagramCaption: "Exclusive-OR from four NAND gates and one shared node.",
            widget: .none),

        ReferenceEntry(
            id: "demorgan", title: "De Morgan's Laws", tag: "Foundations",
            summary: "Break the bar, change the sign.",
            paragraphs: [
                "NOT(A AND B) equals (NOT A) OR (NOT B). NOT(A OR B) equals (NOT A) AND (NOT B). Those two sentences are the most useful pair of facts in practical logic design.",
                "The mnemonic is: break the bar, change the operator. Whenever an inversion sits on top of a whole expression you can push it down onto the individual terms, provided you flip every AND into an OR and back again.",
                "In hardware this matters because it lets you move bubbles around a schematic until adjacent inversions cancel. Two inverters back to back cost gates and delay and do nothing else; De Morgan is how you find them.",
                "It is also the reason NAND-only and NOR-only design works at all. An OR built from NAND is literally De Morgan's law wired up."
            ],
            diagramLevel: 17,
            diagramCaption: "NOT(A AND B) built with no AND gate in the palette.",
            widget: .none),

        ReferenceEntry(
            id: "kmap", title: "Karnaugh Maps", tag: "Simplification",
            summary: "A visual method for minimising up to four variables, with a live map.",
            paragraphs: [
                "A Karnaugh map is a truth table folded so that neighbouring cells differ in exactly one variable. Rows and columns are labelled in Gray code order, 00 01 11 10, and never in counting order.",
                "Any rectangular group of one, two, four, eight or sixteen adjacent ones collapses to a single product term, and the variables that change across the group drop out of it. Bigger groups mean fewer literals, so always take the largest legal rectangle.",
                "The map wraps around: the left column is adjacent to the right column and the top row is adjacent to the bottom row. The four corners of a four-variable map form a legal group of four.",
                "Below is a live map. Tap cells to set the function and watch the minimised sum of products update. The expression is computed with the Quine-McCluskey method, which is the same idea done exhaustively rather than by eye."
            ],
            diagramLevel: nil,
            diagramCaption: "",
            widget: .karnaugh),

        ReferenceEntry(
            id: "twos", title: "Two's Complement", tag: "Arithmetic",
            summary: "How one adder handles negative numbers without a subtractor.",
            paragraphs: [
                "To negate a binary number in two's complement, invert every bit and add one. Four bits therefore represent values from -8 to +7, with the top bit acting as the sign.",
                "The reason this encoding won is that addition needs no special case. Adding the representation of -3 to the representation of +5 with an ordinary adder produces the representation of +2, and the carry out of the top bit is simply discarded.",
                "Subtraction is the same trick: A minus B equals A plus NOT B plus one. Feed the SUB line into an XOR on every B bit and into the carry input, and one circuit does both operations.",
                "Signed overflow is not the carry out. Overflow means the two operands had the same sign and the result did not, which is a different test and needs its own gate."
            ],
            diagramLevel: 31,
            diagramCaption: "Invert, then increment: negation of a four-bit word.",
            widget: .none),

        ReferenceEntry(
            id: "adders", title: "Adders", tag: "Arithmetic",
            summary: "Half adder, full adder, and the chain that joins them.",
            paragraphs: [
                "A half adder takes two bits and produces a sum and a carry. Sum is XOR, carry is AND, and that is the entire device.",
                "A full adder takes three bits, because the carry from the previous column has to go somewhere. It is two half adders with their carries ORed together, and it is the cell every wide adder is made of.",
                "The sum output of a full adder is the parity of its three inputs. The carry output is the majority of its three inputs. Recognising those two functions makes a lot of arithmetic circuitry suddenly readable.",
                "Because the full adder counts how many of its inputs are high, it also works as a three-bit population counter with no changes at all."
            ],
            diagramLevel: 24,
            diagramCaption: "Full adder from two half adders and one OR.",
            widget: .none),

        ReferenceEntry(
            id: "ripple", title: "Ripple Versus Lookahead", tag: "Arithmetic",
            summary: "Why wide adders get slow, and what real machines do about it.",
            paragraphs: [
                "In a ripple-carry adder each stage waits for the carry from the stage below. The result is correct but the delay grows linearly with the width: a 32-bit ripple adder is 32 gate delays deep in the worst case.",
                "Carry-lookahead computes, for each bit, whether that bit generates a carry (both inputs high) or propagates one (at least one input high). Those two signals let the carries for the whole word be produced in a fixed number of levels instead of a chain.",
                "The cost is area. Lookahead logic grows quickly with width, so real designs build lookahead in blocks of four or eight bits and ripple between the blocks.",
                "This bench simulates settling rather than timing, so a ripple adder gives the same answer as a lookahead one. The cost budget is the stand-in for the trade-off: elegance is measured in gates."
            ],
            diagramLevel: 27,
            diagramCaption: "Four full adders with the carry rippling upward.",
            widget: .none),

        ReferenceEntry(
            id: "mux", title: "Multiplexers", tag: "Routing",
            summary: "The valve that decides which signal gets through.",
            paragraphs: [
                "A 2:1 multiplexer has two data inputs, one select input and one output. When select is low the output follows A, when it is high it follows B. Written out, Y = A AND NOT S, OR B AND S.",
                "Multiplexers compose. Three 2:1 units make a 4:1, and two 4:1 units plus one 2:1 make an 8:1. In general a 2^n:1 selector needs 2^n minus one 2:1 units arranged as a tree.",
                "They also compose sideways. To select between whole words rather than single bits, repeat the multiplexer once per bit position and share the select line. That is exactly how a register file picks which register to read.",
                "A multiplexer can implement any Boolean function of its select inputs by hard-wiring constants onto its data inputs, which is why lookup tables in programmable logic are built from them."
            ],
            diagramLevel: 39,
            diagramCaption: "A 4:1 selector built from three 2:1 multiplexers.",
            widget: .none),

        ReferenceEntry(
            id: "decoders", title: "Decoders And Encoders", tag: "Routing",
            summary: "Turning a number into a wire, and a wire back into a number.",
            paragraphs: [
                "A decoder takes an n-bit address and raises exactly one of its 2^n outputs. Every output is an AND of the address bits in the right polarity, gated by an enable input.",
                "The enable input is a data path in disguise. Feed a signal into it instead of a constant and the decoder becomes a demultiplexer, routing that signal to whichever output the address selects.",
                "An encoder does the reverse: given one active input, report its index. Plain encoders misbehave when two inputs are active at once, so real designs use a priority encoder that reports the highest active index and raises a valid flag when anything is active at all.",
                "Priority encoders show up wherever a machine has to pick one request from many: interrupt controllers, bus arbiters, and the leading-zero detector inside a floating point unit."
            ],
            diagramLevel: 40,
            diagramCaption: "Two address bits and an enable line producing one hot output.",
            widget: .none),

        ReferenceEntry(
            id: "parity", title: "Parity", tag: "Arithmetic",
            summary: "One extra bit that catches a single flipped bit.",
            paragraphs: [
                "Even parity adds one bit chosen so that the total number of high bits is even. The generator is simply the XOR of every data bit.",
                "The checker XORs the data and the parity bit together. A zero means the count is still even; a one means an odd number of bits changed somewhere along the way.",
                "Parity catches any odd number of errors and misses any even number, so it is a smoke alarm rather than a repair kit. Detecting and correcting errors needs more redundancy, which is what Hamming codes provide.",
                "XOR chains are also the core of cyclic redundancy checks and of the linear feedback shift registers used to generate pseudo-random sequences in hardware."
            ],
            diagramLevel: 73,
            diagramCaption: "Even parity of four bits from three XOR gates.",
            widget: .none),

        ReferenceEntry(
            id: "latchff", title: "Latch Versus Flip-Flop", tag: "Memory",
            summary: "Transparent windows against sharp edges.",
            paragraphs: [
                "A latch is level sensitive. While its enable input is high the output follows the data input continuously, and the value is only trapped when enable falls. It is a window that is either open or shut.",
                "A flip-flop is edge triggered. It samples its data input at the instant the clock rises and ignores everything else for the rest of the cycle. It is a camera shutter, not a window.",
                "The distinction matters because latches make feedback loops dangerous. A shift register built from transparent latches on one clock would let data race straight through every stage in a single cycle.",
                "The cross-coupled pair at the heart of both is the same: two inverting gates each feeding the other, so the pair has two stable states and will sit in either one indefinitely."
            ],
            diagramLevel: 59,
            diagramCaption: "Two NOR gates cross-coupled: the original memory cell.",
            widget: .none),

        ReferenceEntry(
            id: "setuphold", title: "Setup And Hold", tag: "Memory",
            summary: "The two windows around a clock edge that data must respect.",
            paragraphs: [
                "Setup time is how long the data input must already be stable before the clock edge arrives. Hold time is how long it must remain stable afterwards. Violate either and the flip-flop is not guaranteed to capture anything sensible.",
                "Setup violations are fixed by slowing the clock or shortening the logic path between two flip-flops. Hold violations are worse: they do not go away when you slow the clock, because they are caused by a path that is too fast, not too slow.",
                "The usual repair for a hold violation is to insert buffers, which is the rare case where adding gates makes a circuit more correct rather than less efficient.",
                "This bench does not model time, so it cannot show you a setup violation. It does show you the settling behaviour that timing analysis is ultimately about."
            ],
            diagramLevel: 63,
            diagramCaption: "An edge-triggered D flip-flop: data is sampled only on the rise.",
            widget: .none),

        ReferenceEntry(
            id: "metastability", title: "Metastability", tag: "Memory",
            summary: "What happens when a flip-flop cannot make up its mind.",
            paragraphs: [
                "If data changes inside the setup and hold window, a flip-flop can enter a metastable state: an output balanced between high and low, resolving to one or the other after an unpredictable delay.",
                "Metastability cannot be eliminated, only made improbable. The standard mitigation is a synchroniser: two flip-flops in series, giving the first one a whole clock period to settle before the second one samples it.",
                "The failure rate is expressed as mean time between failures and depends exponentially on the settling time allowed. Adding a third flip-flop to a synchroniser buys many orders of magnitude.",
                "The lesson is architectural, not electrical: never let an asynchronous signal fan out to more than one destination before it has been synchronised, or different parts of the machine may resolve it differently."
            ],
            diagramLevel: 69,
            diagramCaption: "Two stages in series is the shape of every synchroniser.",
            widget: .none),

        ReferenceEntry(
            id: "clockdomains", title: "Clock Domains", tag: "Memory",
            summary: "Machines that tick to different drums.",
            paragraphs: [
                "A clock domain is a set of flip-flops driven by the same clock. Inside a domain, timing analysis can prove that data arrives correctly. Between domains it cannot, because the two clocks have no fixed relationship.",
                "Single-bit crossings use a two-flop synchroniser. Multi-bit crossings cannot, because the individual bits may resolve on different cycles and produce a value that never actually existed.",
                "The standard solutions for multi-bit data are a handshake, where a request and acknowledge pair walk the data across, or an asynchronous FIFO built with Gray-coded pointers so that only one bit changes at a time.",
                "Gray code is the same trick a Karnaugh map uses. Neighbouring values differ in exactly one bit, so a pointer sampled mid-change can only ever be off by one, never nonsense."
            ],
            diagramLevel: 70,
            diagramCaption: "A ring counter walks one bit at a time, Gray-code style.",
            widget: .none),

        ReferenceEntry(
            id: "shift", title: "Shift Registers", tag: "Memory",
            summary: "Data walking one stage per clock.",
            paragraphs: [
                "A shift register is a chain of flip-flops with the output of each feeding the input of the next, all driven by one clock. On every edge the whole word moves along one position.",
                "Because every stage samples the pre-edge value of its neighbour, the data does not race through. That property is exactly what makes edge triggering rather than level sensitivity essential here.",
                "Shift registers convert between serial and parallel form, which is how a single wire carries a whole byte. They also implement multiplication and division by powers of two, since shifting left doubles a number and shifting right halves it.",
                "Add a feedback path through an XOR and you get a linear feedback shift register, which cycles through almost every possible state and is the cheapest pseudo-random generator in hardware."
            ],
            diagramLevel: 69,
            diagramCaption: "Four D flip-flops sharing one clock line.",
            widget: .none),

        ReferenceEntry(
            id: "counters", title: "Counters", tag: "Memory",
            summary: "Dividing a clock, and counting what it divides.",
            paragraphs: [
                "A toggle flip-flop with its T input tied high flips on every rising edge, so its output runs at exactly half the clock frequency. That single fact is the whole of binary counting.",
                "Chain the stages so each is clocked by the previous stage's inverted output and you have a ripple counter. It is tiny, it is cheap, and the count settles one stage at a time, so the intermediate values it shows are briefly wrong.",
                "A synchronous counter clocks every stage from the same source and uses combinational logic to decide which stages toggle. It costs more gates and settles all at once, which is what any machine reading the count actually needs.",
                "A Johnson or twisted ring counter feeds the last stage back inverted. Four flip-flops then give eight distinct states, and unlike a plain ring counter it starts correctly from all zeros."
            ],
            diagramLevel: 68,
            diagramCaption: "Four toggle stages: sixteen states from four flip-flops.",
            widget: .none),

        ReferenceEntry(
            id: "alu", title: "ALU Basics", tag: "The Machine",
            summary: "Where the arithmetic and the logic finally meet.",
            paragraphs: [
                "An arithmetic logic unit computes several functions of its operands at once and uses a multiplexer to publish only the one the opcode selected. It is not clever; it is parallel and then selective.",
                "One bit slice typically offers AND, OR, XOR or sum, plus an inverted operand path. Widening it is a matter of repeating the slice and running a carry chain through the arithmetic path.",
                "Around the data path sit the flags: zero from a NOR tree over the result, carry from the top of the adder, negative from the sign bit, and overflow from comparing operand and result signs. Those four bits are what conditional branches actually test.",
                "Attach a register to the output, feed that register back into one operand input, and you have an accumulator. At that point the collection of gates has become a machine that can hold a running total across time, which is the last bench in this workshop."
            ],
            diagramLevel: 75,
            diagramCaption: "Four functions computed in parallel, one selected by opcode.",
            widget: .none)
    ]
}

struct ReferenceTab: View {
    @EnvironmentObject var store: LogicGateStore
    @State private var openEntry: String? = nil

    var body: some View {
        Group {
            if let id = openEntry,
               let entry = ReferenceLibrary.entries.first(where: { $0.id == id }) {
                detail(entry)
            } else {
                list
            }
        }
    }

    private var list: some View {
        BenchScaffold(title: "Reference",
                      subtitle: "\(ReferenceLibrary.entries.count) articles \u{00B7} \(store.progress.readEntries.count) read") {
            ScrollView {
                VStack(spacing: 9) {
                    ForEach(ReferenceLibrary.entries) { e in
                        Button(action: {
                            BenchFeedback.tap(store.progress.settings)
                            store.markRead(e.id)
                            openEntry = e.id
                        }) {
                            BenchCard {
                                HStack(alignment: .top, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 6) {
                                            Text(e.tag.uppercased())
                                                .font(Bench.mono(8, .bold))
                                                .foregroundColor(Bench.copper)
                                            if store.isRead(e.id) {
                                                Text("READ")
                                                    .font(Bench.mono(8, .bold))
                                                    .foregroundColor(Bench.good)
                                            }
                                        }
                                        Text(e.title)
                                            .font(Bench.label(15, .bold))
                                            .foregroundColor(Bench.text)
                                        Text(e.summary)
                                            .font(Bench.label(11, .regular))
                                            .foregroundColor(Bench.textDim)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                    }
                                    Spacer(minLength: 0)
                                    ChevronShape()
                                        .stroke(Bench.textFaint,
                                                style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                        .frame(width: 11, height: 14)
                                        .padding(.top, 12)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
        }
    }

    private func detail(_ e: ReferenceEntry) -> some View {
        let level = e.diagramLevel.flatMap { store.content.level($0) }
        return BenchScaffold(title: e.title, subtitle: e.tag,
                             trailing: AnyView(
                                Button(action: { openEntry = nil }) {
                                    HStack(spacing: 4) {
                                        ChevronShape()
                                            .stroke(Bench.copper,
                                                    style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                            .rotationEffect(.degrees(180))
                                            .frame(width: 11, height: 13)
                                        Text("Index")
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
                    ForEach(0..<e.paragraphs.count, id: \.self) { i in
                        Text(e.paragraphs[i])
                            .font(Bench.label(13, .regular))
                            .foregroundColor(i == 0 ? Bench.text : Bench.textDim)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(3)
                    }

                    if e.widget == .karnaugh {
                        BenchCard {
                            KarnaughWidget()
                        }
                    }

                    if let l = level {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("LIVE DIAGRAM \u{00B7} LEVEL \(l.id)")
                                .font(Bench.mono(9, .bold))
                                .foregroundColor(Bench.textFaint)
                            BoardPreview(netlist: l.referenceSolution, chips: store.chips,
                                         cols: l.cols, rows: l.rows, height: 200,
                                         showPinLabels: false)
                            Text(e.diagramCaption)
                                .font(Bench.label(10.5, .regular))
                                .foregroundColor(Bench.textFaint)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
        }
    }
}
