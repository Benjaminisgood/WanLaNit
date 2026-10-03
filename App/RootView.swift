import AppKit
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(SpeechService.self) private var speech

    var body: some View {
        Group {
            if let message = model.loadError {
                MissingContentView(message: message)
            } else {
                NavigationSplitView {
                    List(AppSection.allCases, selection: Binding<AppSection?>(
                        get: { model.section },
                        set: { model.section = $0 ?? model.section }
                    )) { section in
                        Label(section.title, systemImage: section.symbol)
                            .tag(Optional(section))
                    }
                    .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
                    .navigationTitle("วันละนิด")
                } detail: {
                    Group {
                        if model.active != nil {
                            SessionView()
                        } else {
                            switch model.section {
                            case .today: TodayView()
                            case .tones: ToneTrainerView()
                            case .decks: DecksView()
                            case .script: ScriptView()
                            case .culture: CultureView()
                            case .vocab: VocabView()
                            case .stats: StatsView()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .paper()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            speech.refresh()
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
