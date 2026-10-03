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
    var importMessage: String?
    var progress: LearningProgress
    var active: ActiveSession?
    var selectedSection: AppSection? = .today

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

    func setUnlockAll(_ value: Bool) {
        progress.unlockAll = value
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
        let ref = session.current
        session.grade(grade, progress: &progress)
        if let ref, let catalog, ref.kind == .word {
            ReaderState.sync(ref, catalog: catalog, progress: &progress)
        }
        active = session
        store.save(progress)
    }

    func importPasted(title: String, body: String) {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        progress.library.append(ReaderDocument(
            id: UUID().uuidString,
            title: name.isEmpty ? "粘贴的文章" : name,
            body: trimmed,
            source: "粘贴"
        ))
        importMessage = nil
        store.save(progress)
    }

    func importFile(_ url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            importMessage = "这个文件不是 UTF-8 文本。"
            return
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            importMessage = "文件是空的。"
            return
        }
        progress.library.append(ReaderDocument(
            id: UUID().uuidString,
            title: url.deletingPathExtension().lastPathComponent,
            body: trimmed,
            source: "文件"
        ))
        importMessage = nil
        store.save(progress)
    }

    func importRemote(_ raw: String) async {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme, scheme == "https" || scheme == "http" else {
            importMessage = "网址看起来不对。"
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let html = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
            let body = HTMLText.plainText(from: html)
            guard !body.isEmpty else {
                importMessage = "这个页面里没有能取出的文字。"
                return
            }
            let title = HTMLText.title(from: html) ?? url.host ?? "网页"
            progress.library.append(ReaderDocument(
                id: UUID().uuidString,
                title: title,
                body: body,
                source: url.absoluteString
            ))
            importMessage = nil
            store.save(progress)
        } catch {
            importMessage = "抓取失败。"
        }
    }

    func setWordMark(_ thai: String, status: WordMark, level: Int) {
        ReaderState.setMark(status, level: level, thai: thai, progress: &progress)
        store.save(progress)
    }

    func addWordToReview(thai: String, sentence: String) {
        guard let catalog else { return }
        ReaderState.addToReview(thai: thai, sentence: sentence, catalog: catalog, progress: &progress, on: today)
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

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case today
    case tones
    case decks
    case script
    case culture
    case vocab
    case reader
    case stats

    var id: Self { self }

    var title: String {
        switch self {
        case .today: return "今天"
        case .tones: return "声调"
        case .decks: return "句子"
        case .script: return "文字"
        case .culture: return "文化"
        case .vocab: return "词汇"
        case .reader: return "阅读"
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
        case .reader: return "book"
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
