import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: LogicGateStore
    @State private var tab = 0
    @State private var currentLevelId = 1
    @State private var started = false

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch tab {
                case 0: benchTab
                case 1: ChaptersTab(openLevel: openLevel)
                case 2: ChipLibraryTab()
                case 3: ReferenceTab()
                default: MoreTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            tabBar
        }
        .background(Bench.background.ignoresSafeArea())
        .onAppear {
            if !started {
                currentLevelId = store.nextLevel.id
                started = true
            }
        }
    }

    private func openLevel(_ id: Int) {
        guard store.isUnlocked(id) else { return }
        currentLevelId = id
        tab = 0
    }

    @ViewBuilder
    private var benchTab: some View {
        if let level = store.content.level(currentLevelId) {
            WorkbenchView(level: level,
                          board: store.board(for: level),
                          chips: store.chips,
                          settings: store.progress.settings,
                          onExit: { tab = 1 },
                          onGoTo: { id in
                              if store.isUnlocked(id) { currentLevelId = id } else { tab = 1 }
                          })
                .id(currentLevelId)
        } else {
            Color.clear
        }
    }

    private var tabBar: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Bench.stroke).frame(height: 1)
            HStack(spacing: 0) {
                tabButton(0, "Bench", .bench)
                tabButton(1, "Chapters", .chapters)
                tabButton(2, "Chips", .chip)
                tabButton(3, "Reference", .book)
                tabButton(4, "More", .gear)
            }
            .padding(.top, 7)
            .padding(.bottom, 3)
            .background(Bench.surface.edgesIgnoringSafeArea(.bottom))
        }
    }

    private func tabButton(_ index: Int, _ title: String, _ glyph: BenchGlyph) -> some View {
        Button(action: {
            if tab != index { BenchFeedback.tap(store.progress.settings) }
            tab = index
        }) {
            VStack(spacing: 3) {
                GlyphView(glyph: glyph, color: tab == index ? Bench.copper : Bench.textFaint)
                    .frame(width: 21, height: 21)
                Text(title)
                    .font(Bench.label(9, .semibold))
                    .foregroundColor(tab == index ? Bench.copper : Bench.textFaint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
