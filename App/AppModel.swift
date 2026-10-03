import Foundation
import Observation
import ThaiLearnCore

@MainActor
@Observable
final class AppModel {
    let speech: SpeechService
    private let store = ProgressStore.live()

    private(set) var catalog: Catalog?
    private(set) var loadError: String?
    var progress: LearningProgress
    var active: ActiveSession?
    var section: AppSection = .today

    init() {
        speech = SpeechService()
        let stored = store.load()
        progress = stored
        switch CatalogLocation.load() {
        case .success(let catalog):
            self.catalog = catalog
            if let resume = stored.resume, resume.day == .today {
                active = ActiveSession.restore(resume)
            }
        case .failure(let error):
            loadError = error.issues.joined(separator: "\n")
        }
    }

    var today: CivilDay { .today }

    func report() -> ProgressReport? {
        guard let catalog else { return nil }
        return ProgressReport.make(catalog: catalog, progress: progress, today: today)
    }

    func stats() -> StudyStats? {
        guard let catalog else { return nil }
        return StudyStats.make(catalog: catalog, progress: progress, today: today)
    }

    func setDesiredRetention(_ value: Double) {
        progress.desiredRetention = min(0.97, max(0.80, value))
        store.save(progress)
    }

    func setNewCardLimit(_ value: Int) {
        progress.newCardLimit = min(60, max(0, value))
        store.save(progress)
    }

    func planToday() -> PlannedSession? {
        guard let catalog else { return nil }
        return StudySession.planToday(catalog: catalog, progress: progress, today: today)
    }

    func beginToday() {
        if let resume = progress.resume, resume.day == today, !resume.items.isEmpty {
            active = ActiveSession.restore(resume)
            return
        }
        guard let plan = planToday(), !plan.items.isEmpty else { return }
        begin(plan)
    }

    func beginDeck(_ deckID: String) {
        guard let catalog else { return }
        let plan = StudySession.planDeck(deckID: deckID, catalog: catalog, progress: progress, today: today)
        guard !plan.items.isEmpty else { return }
        begin(plan)
    }

    func grade(_ grade: Grade) {
        guard var session = active, !session.isFinished else { return }
        session.grade(grade, progress: &progress)
        active = session
        store.save(progress)
    }

    func closeSession() {
        active = nil
    }

    private func begin(_ plan: PlannedSession) {
        let session = StudySession.start(plan)
        progress.resume = session.snapshot
        active = session
        store.save(progress)
    }
}

enum AppSection: String, CaseIterable, Identifiable {
    case today
    case tones
    case decks
    case script
    case culture
    case vocab
    case stats

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "今天"
        case .tones: return "声调"
        case .decks: return "句子"
        case .script: return "文字"
        case .culture: return "文化"
        case .vocab: return "词汇"
        case .stats: return "统计"
        }
    }

    var symbol: String {
        switch self {
        case .today: return "sun.max"
        case .tones: return "waveform"
        case .decks: return "text.bubble"
        case .script: return "character.book.closed"
        case .culture: return "leaf"
        case .vocab: return "text.book.closed"
        case .stats: return "chart.bar"
        }
    }
}

enum CatalogLocation {
    static func load() -> Result<Catalog, ContentError> {
        ContentLoader.loadApplicationContent()
    }
}

extension CivilDay {
    static var today: CivilDay {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return CivilDay(year: parts.year ?? 2026, month: parts.month ?? 10, day: parts.day ?? 2)
    }
}
