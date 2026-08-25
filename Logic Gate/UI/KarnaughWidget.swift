import Foundation
import SwiftUI

// MARK: - Quine-McCluskey for up to four variables

struct Implicant: Hashable {
    var bits: Int   // value bits, only meaningful where mask is 0
    var mask: Int   // 1 = this variable is eliminated
}

enum Minimizer {

    static func covers(_ imp: Implicant, _ m: Int) -> Bool {
        (m & ~imp.mask) == (imp.bits & ~imp.mask)
    }

    static func primeImplicants(_ minterms: [Int], vars: Int) -> [Implicant] {
        guard !minterms.isEmpty else { return [] }
        var current = Set(minterms.map { Implicant(bits: $0, mask: 0) })
        var primes: [Implicant] = []
        while !current.isEmpty {
            var combined = Set<Implicant>()
            var used = Set<Implicant>()
            let list = Array(current)
            for i in 0..<list.count {
                for j in (i + 1)..<list.count {
                    let a = list[i], b = list[j]
                    guard a.mask == b.mask else { continue }
                    let diff = (a.bits & ~a.mask) ^ (b.bits & ~b.mask)
                    if diff != 0 && (diff & (diff - 1)) == 0 {
                        used.insert(a); used.insert(b)
                        combined.insert(Implicant(bits: a.bits & ~diff, mask: a.mask | diff))
                    }
                }
            }
            for imp in list where !used.contains(imp) {
                if !primes.contains(imp) { primes.append(imp) }
            }
            current = combined
        }
        return primes
    }

    static func cover(_ minterms: [Int], vars: Int) -> [Implicant] {
        let primes = primeImplicants(minterms, vars: vars)
        guard !primes.isEmpty else { return [] }
        var remaining = Set(minterms)
        var chosen: [Implicant] = []

        // Essential prime implicants first.
        for m in minterms {
            let owners = primes.filter { covers($0, m) }
            if owners.count == 1, let only = owners.first, !chosen.contains(only) {
                chosen.append(only)
            }
        }
        for c in chosen {
            remaining = remaining.filter { !covers(c, $0) }
        }
        // Greedy for the rest.
        while !remaining.isEmpty {
            var best: Implicant? = nil
            var bestCount = 0
            for p in primes where !chosen.contains(p) {
                let n = remaining.filter { covers(p, $0) }.count
                if n > bestCount { bestCount = n; best = p }
            }
            guard let pick = best, bestCount > 0 else { break }
            chosen.append(pick)
            remaining = remaining.filter { !covers(pick, $0) }
        }
        return chosen
    }

    /// Human-readable sum of products. Variable 0 is the most significant bit.
    static func expression(_ imps: [Implicant], names: [String]) -> String {
        let vars = names.count
        if imps.isEmpty { return "0" }
        var terms: [String] = []
        for imp in imps {
            var s = ""
            for v in 0..<vars {
                let bit = vars - 1 - v
                if (imp.mask >> bit) & 1 == 1 { continue }
                s += names[v]
                if (imp.bits >> bit) & 1 == 0 { s += "'" }
            }
            terms.append(s.isEmpty ? "1" : s)
        }
        if terms.contains("1") { return "1" }
        return terms.joined(separator: " + ")
    }
}

// MARK: - Live four-variable Karnaugh map

struct KarnaughWidget: View {
    @State private var selected: Set<Int> = [3, 7, 11, 15, 12]
    private let gray = [0, 1, 3, 2]
    private let names = ["A", "B", "C", "D"]

    private var minterms: [Int] { selected.sorted() }

    /// Sized from the real screen width so iPad compatibility mode cannot over-report.
    private var cellSide: CGFloat {
        let avail = min(UIScreen.main.bounds.width, 620) - 32 - 34 - 14
        return max(28, min(avail / 4, 54))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tap cells to mark where the function is 1. Adjacent groups of one, two, four or eight cells collapse into a single product term.")
                .font(Bench.label(11, .regular))
                .foregroundColor(Bench.textDim)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 3) {
                HStack(spacing: 3) {
                    Text("AB\\CD")
                        .font(Bench.mono(8, .bold))
                        .foregroundColor(Bench.textFaint)
                        .frame(width: 34, height: 18)
                    ForEach(0..<4, id: \.self) { c in
                        Text(pairLabel(gray[c]))
                            .font(Bench.mono(9, .bold))
                            .foregroundColor(Bench.textFaint)
                            .frame(width: cellSide, height: 18)
                    }
                }
                ForEach(0..<4, id: \.self) { r in
                    HStack(spacing: 3) {
                        Text(pairLabel(gray[r]))
                            .font(Bench.mono(9, .bold))
                            .foregroundColor(Bench.textFaint)
                            .frame(width: 34, height: cellSide)
                        ForEach(0..<4, id: \.self) { c in
                            cellView(row: r, col: c, side: cellSide)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            BenchCard(padding: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("MINIMISED SUM OF PRODUCTS")
                        .font(Bench.mono(9, .bold))
                        .foregroundColor(Bench.textFaint)
                    Text(Minimizer.expression(Minimizer.cover(minterms, vars: 4), names: names))
                        .font(Bench.mono(14, .bold))
                        .foregroundColor(Bench.high)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(minterms.count) minterms \u{2192} \(Minimizer.cover(minterms, vars: 4).count) product terms")
                        .font(Bench.label(10, .regular))
                        .foregroundColor(Bench.textDim)
                }
            }

            HStack(spacing: 8) {
                BenchButton(title: "Clear", tint: Bench.textDim, compact: true) {
                    selected.removeAll()
                }
                BenchButton(title: "Fill", tint: Bench.textDim, compact: true) {
                    selected = Set(0..<16)
                }
                BenchButton(title: "Majority", tint: Bench.copper, compact: true) {
                    selected = Set((0..<16).filter { m in
                        var n = 0
                        for b in 0..<4 where (m >> b) & 1 == 1 { n += 1 }
                        return n >= 3
                    })
                }
            }
        }
    }

    private func pairLabel(_ v: Int) -> String {
        String(format: "%d%d", (v >> 1) & 1, v & 1)
    }

    private func index(row: Int, col: Int) -> Int {
        (gray[row] << 2) | gray[col]
    }

    private func cellView(row: Int, col: Int, side: CGFloat) -> some View {
        let m = index(row: row, col: col)
        let on = selected.contains(m)
        return Button(action: {
            if on { selected.remove(m) } else { selected.insert(m) }
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(on ? Bench.copper.opacity(0.32) : Bench.surface)
                    .overlay(RoundedRectangle(cornerRadius: 6)
                        .stroke(on ? Bench.high : Bench.stroke, lineWidth: 1))
                VStack(spacing: 1) {
                    Text(on ? "1" : "0")
                        .font(Bench.mono(13, .bold))
                        .foregroundColor(on ? Bench.high : Bench.textFaint)
                    Text("m\(m)")
                        .font(Bench.mono(7, .regular))
                        .foregroundColor(Bench.textFaint)
                }
            }
            .frame(width: side, height: side)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
