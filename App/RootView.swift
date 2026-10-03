import AppKit
import SwiftUI
import ThaiLearnCore

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(SpeechService.self) private var speech

    var body: some View {
        @Bindable var model = model
        Group {
            if let message = model.loadError {
                MissingContentView(message: message)
            } else {
                NavigationSplitView {
                    List(selection: $model.selectedSection) {
                        ForEach(visibleSections) { section in
                            NavigationLink(value: section) {
                                Label(section.title, systemImage: section.symbol)
                            }
                        }
                    }
                    .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
                    .navigationTitle("วันละนิด")
                } detail: {
                    detail(for: model.selectedSection ?? .today)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .paper()
                        .toolbarBackground(Ink.paper, for: .windowToolbar)
                        .toolbarBackground(.visible, for: .windowToolbar)
                }
            }
        }
        .onAppear(perform: normalizeSelection)
        .onChange(of: model.progress.unlockAll) { _, _ in
            normalizeSelection()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            speech.refresh()
        }
    }

    @ViewBuilder
    private func detail(for section: AppSection) -> some View {
        if model.active != nil {
            SessionView()
        } else {
            switch isVisible(section) ? section : .today {
            case .today: TodayView()
            case .tones: ToneTrainerView()
            case .decks: DecksView()
            case .script: ScriptView()
            case .culture: CultureView()
            case .vocab: VocabView()
            case .reader: ReaderView()
            case .typing: TypingView()
            case .passages: PassagePracticeView()
            case .stats: StatsView()
            }
        }
    }

    private var visibleSections: [AppSection] {
        AppSection.allCases.filter(isVisible)
    }

    private func normalizeSelection() {
        let section = model.selectedSection ?? .today
        if !isVisible(section) {
            model.selectedSection = .today
        }
    }

    private func isVisible(_ section: AppSection) -> Bool {
        if model.progress.unlockAll { return true }
        guard let catalog = model.catalog else { return true }
        switch section {
        case .tones:
            return LearningPath.isUnlocked(.tones, catalog: catalog, progress: model.progress)
        case .vocab:
            return LearningPath.isUnlocked(.vocabulary, catalog: catalog, progress: model.progress)
        case .reader:
            return LearningPath.isUnlocked(.reading, catalog: catalog, progress: model.progress)
        case .today, .decks, .script, .culture, .stats, .typing, .passages:
            return true
        }
    }
}

struct MissingContentView: View {
    var message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("课程没有载入")
                .font(.title2.bold())
            Text(message)
                .font(.body)
                .foregroundStyle(Ink.muted)
                .textSelection(.enabled)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .paper()
    }
}
