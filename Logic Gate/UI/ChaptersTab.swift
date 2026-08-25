import SwiftUI

struct ChaptersTab: View {
    @EnvironmentObject var store: LogicGateStore
    @State private var openChapter: Int? = nil
    let openLevel: (Int) -> Void

    var body: some View {
        Group {
            if let c = openChapter, let info = store.content.chapter(c) {
                levelGrid(info)
            } else {
                chapterList
            }
        }
    }

    // MARK: chapter list

    private var chapterList: some View {
        BenchScaffold(title: "Chapters",
                      subtitle: "\(store.solvedCount) of \(store.content.levels.count) benches cleared \u{00B7} \(store.totalStars)/\(store.maxStars) stars") {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(store.content.chapters) { ch in
                        chapterCard(ch)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
        }
    }

    private func chapterCard(_ ch: ChapterInfo) -> some View {
        let unlocked = store.chapterUnlocked(ch.id)
        let solved = store.solved(inChapter: ch.id)
        let total = store.content.levels(inChapter: ch.id).count
        let stars = store.stars(inChapter: ch.id)
        return Button(action: {
            if unlocked {
                BenchFeedback.tap(store.progress.settings)
                openChapter = ch.id
            }
        }) {
            BenchCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(unlocked ? Bench.copper.opacity(0.18) : Bench.surfaceHigh)
                                .frame(width: 38, height: 38)
                            Text("\(ch.id)")
                                .font(Bench.mono(16, .bold))
                                .foregroundColor(unlocked ? Bench.copper : Bench.textFaint)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ch.name)
                                .font(Bench.label(16, .bold))
                                .foregroundColor(unlocked ? Bench.text : Bench.textFaint)
                            Text(ch.subtitle)
                                .font(Bench.label(11, .regular))
                                .foregroundColor(Bench.textDim)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                        if !unlocked {
                            LockShape()
                                .stroke(Bench.textFaint, lineWidth: 1.5)
                                .frame(width: 16, height: 18)
                        }
                    }
                    HStack(spacing: 10) {
                        progressBar(Double(solved) / Double(max(total, 1)))
                        Text("\(solved)/\(total)")
                            .font(Bench.mono(10, .bold))
                            .foregroundColor(Bench.textDim)
                        HStack(spacing: 3) {
                            StarShape().fill(Bench.high).frame(width: 10, height: 10)
                            Text("\(stars)/\(total * 3)")
                                .font(Bench.mono(10, .bold))
                                .foregroundColor(Bench.textDim)
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .opacity(unlocked ? 1 : 0.55)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func progressBar(_ f: Double) -> some View {
        GeometryReader { p in
            ZStack(alignment: .leading) {
                Capsule().fill(Bench.surfaceHigh)
                Capsule().fill(Bench.copper)
                    .frame(width: max(0, min(1, f)) * p.size.width)
            }
        }
        .frame(height: 5)
        .frame(maxWidth: .infinity)
    }

    // MARK: level grid

    private func levelGrid(_ info: ChapterInfo) -> some View {
        let levels = store.content.levels(inChapter: info.id)
        return BenchScaffold(title: info.name,
                             subtitle: info.subtitle,
                             trailing: AnyView(
                                Button(action: { openChapter = nil }) {
                                    HStack(spacing: 4) {
                                        ChevronShape()
                                            .stroke(Bench.copper,
                                                    style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                            .rotationEffect(.degrees(180))
                                            .frame(width: 11, height: 13)
                                        Text("All chapters")
                                            .font(Bench.label(12, .semibold))
                                            .foregroundColor(Bench.copper)
                                    }
                                    .padding(.vertical, 6)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())
                             )) {
            GeometryReader { proxy in
                let w = benchUsableWidth(proxy.size.width)
                let columns = w > 560 ? 6 : 4
                let tile = (w - 32 - CGFloat(columns - 1) * 10) / CGFloat(columns)
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(rows(levels, per: columns), id: \.self) { row in
                            HStack(spacing: 10) {
                                ForEach(row, id: \.self) { id in
                                    levelTile(id, side: tile)
                                }
                                if row.count < columns {
                                    ForEach(0..<(columns - row.count), id: \.self) { _ in
                                        Color.clear.frame(width: tile, height: tile)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 28)
                    .frame(width: w)
                }
                .frame(width: w)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func rows(_ levels: [LogicGateLevel], per: Int) -> [[Int]] {
        var out: [[Int]] = []
        var current: [Int] = []
        for l in levels {
            current.append(l.id)
            if current.count == per { out.append(current); current = [] }
        }
        if !current.isEmpty { out.append(current) }
        return out
    }

    private func levelTile(_ id: Int, side: CGFloat) -> some View {
        let unlocked = store.isUnlocked(id)
        let rec = store.record(id)
        let level = store.content.level(id)
        return Button(action: {
            if unlocked {
                BenchFeedback.tap(store.progress.settings)
                openLevel(id)
            }
        }) {
            VStack(spacing: 4) {
                if unlocked {
                    Text("\(id)")
                        .font(Bench.mono(min(side * 0.32, 19), .bold))
                        .foregroundColor(rec.solved ? Bench.copper : Bench.text)
                    StarRow(filled: rec.stars, size: min(side * 0.16, 10))
                    Text(level?.title ?? "")
                        .font(Bench.label(7.5, .medium))
                        .foregroundColor(Bench.textFaint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 2)
                } else {
                    LockShape()
                        .stroke(Bench.textFaint, lineWidth: 1.5)
                        .frame(width: side * 0.28, height: side * 0.32)
                }
            }
            .frame(width: side, height: side)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(rec.solved ? Bench.surfaceHigh : Bench.surface)
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(rec.stars >= 3 ? Bench.high.opacity(0.7) : Bench.stroke,
                                lineWidth: 1))
            )
            .opacity(unlocked ? 1 : 0.5)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
