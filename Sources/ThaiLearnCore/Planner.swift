import Foundation

public enum StudyPlan {
    /// Benjamin 从这一天开始学泰语。
    public static let defaultStart = CivilDay(year: 2026, month: 10, day: 2)

    public static let pronunciationDays = 14
    public static let scriptDays = 31

    public static func phase(on day: CivilDay, start: CivilDay) -> Phase {
        let index = max(0, day.daysSince(start))
        if index < pronunciationDays { return .pronunciation }
        if index < pronunciationDays + scriptDays { return .script }
        return .grammar
    }

    public static func dayNumber(on day: CivilDay, start: CivilDay) -> Int {
        max(1, day.daysSince(start) + 1)
    }

    /// 新卡片名额。复习另外算，但会给新卡片留位置。
    public static func newBudget(for phase: Phase) -> (phrases: Int, script: Int) {
        switch phase {
        case .pronunciation: return (8, 0)
        case .script: return (4, 4)
        case .grammar: return (6, 2)
        }
    }

    public static let maxItems = 22
}

public struct StudyRef: Codable, Equatable, Hashable, Sendable, Identifiable {
    public var id: String
    public var kind: StudyKind
}

public struct PlannedSession: Equatable, Sendable {
    public var day: CivilDay
    public var phase: Phase
    public var dayNumber: Int
    public var items: [StudyRef]
    public var newCount: Int
    public var reviewCount: Int
    public var estimatedMinutes: Int
}

public struct CurriculumEntry: Equatable, Sendable {
    public var ref: StudyRef
    public var phase: Phase
    public var sortKey: Int
}

public struct CardState: Codable, Equatable, Sendable {
    public var easeFactor: Double
    public var intervalDays: Int
    public var repetitions: Int
    public var due: CivilDay
    public var lapses: Int
    public var introducedOn: CivilDay
    public var lastReviewed: CivilDay?

    public static func fresh(on day: CivilDay) -> CardState {
        CardState(
            easeFactor: 2.5,
            intervalDays: 0,
            repetitions: 0,
            due: day,
            lapses: 0,
            introducedOn: day,
            lastReviewed: nil
        )
    }

    public var isMastered: Bool { intervalDays >= 21 }
}

public struct DayLog: Codable, Equatable, Sendable {
    public var day: CivilDay
    public var reviews: Int
    public var newItems: Int
}

public struct SessionSnapshot: Codable, Equatable, Sendable {
    public var day: CivilDay
    public var items: [StudyRef]
    public var index: Int
    public var requeues: [String: Int]
}

public struct LearningProgress: Codable, Equatable, Sendable {
    public var schema: Int
    public var startDate: CivilDay
    public var cards: [String: CardState]
    public var streak: Int
    public var lastStudiedDay: CivilDay?
    public var dayLogs: [DayLog]
    public var resume: SessionSnapshot?

    public static func fresh(start: CivilDay = StudyPlan.defaultStart) -> LearningProgress {
        LearningProgress(
            schema: 1,
            startDate: start,
            cards: [:],
            streak: 0,
            lastStudiedDay: nil,
            dayLogs: [],
            resume: nil
        )
    }

    public mutating func recordReview(on day: CivilDay, isNew: Bool) {
        if let index = dayLogs.firstIndex(where: { $0.day == day }) {
            dayLogs[index].reviews += 1
            if isNew { dayLogs[index].newItems += 1 }
        } else {
            dayLogs.append(DayLog(day: day, reviews: 1, newItems: isNew ? 1 : 0))
        }
    }

    public mutating func completeSession(on day: CivilDay) {
        if lastStudiedDay == day { return }
        if let last = lastStudiedDay, last.adding(days: 1) == day {
            streak += 1
        } else {
            streak = 1
        }
        lastStudiedDay = day
    }
}

public struct ActiveSession: Equatable, Sendable {
    public var day: CivilDay
    public var items: [StudyRef]
    public var index: Int
    public var requeues: [String: Int]
    public private(set) var reviewed: Int

    public var current: StudyRef? {
        guard index >= 0, index < items.count else { return nil }
        return items[index]
    }

    public var isFinished: Bool { index >= items.count }
    public var remaining: Int { max(0, items.count - index) }
    public var positionLabel: String {
        let shown = min(index + 1, max(items.count, 1))
        return "\(shown) / \(items.count)"
    }

    public mutating func grade(_ grade: Grade, progress: inout LearningProgress) {
        guard let item = current else { return }
        let isNew = progress.cards[item.id]?.lastReviewed == nil
        var card = progress.cards[item.id] ?? CardState.fresh(on: day)
        let reviewedState = SM2.review(
            quality: grade.quality,
            state: SM2.State(
                repetitions: card.repetitions,
                easeFactor: card.easeFactor,
                intervalDays: card.intervalDays
            )
        )
        card.repetitions = reviewedState.repetitions
        card.easeFactor = reviewedState.easeFactor
        card.intervalDays = reviewedState.intervalDays
        card.due = day.adding(days: reviewedState.intervalDays)
        card.lastReviewed = day
        if grade.quality < 3 { card.lapses += 1 }
        progress.cards[item.id] = card
        progress.recordReview(on: day, isNew: isNew)
        reviewed += 1

        if grade == .again {
            let times = requeues[item.id, default: 0]
            if times < 2 {
                requeues[item.id] = times + 1
                let insertAt = min(index + 1 + 3, items.count)
                items.insert(item, at: insertAt)
            }
        }

        index += 1
        if isFinished {
            progress.completeSession(on: day)
            progress.resume = nil
        } else {
            progress.resume = snapshot
        }
    }

    public var snapshot: SessionSnapshot {
        SessionSnapshot(day: day, items: items, index: index, requeues: requeues)
    }

    public static func restore(_ snapshot: SessionSnapshot, reviewed: Int = 0) -> ActiveSession {
        ActiveSession(
            day: snapshot.day,
            items: snapshot.items,
            index: snapshot.index,
            requeues: snapshot.requeues,
            reviewed: reviewed
        )
    }
}

public enum StudySession {
    public static func planToday(catalog: Catalog, progress: LearningProgress, today: CivilDay) -> PlannedSession {
        let phase = StudyPlan.phase(on: today, start: progress.startDate)
        let budget = StudyPlan.newBudget(for: phase)
        let entries = curriculum(catalog)
        let phraseEntries = entries.filter { $0.ref.kind == .phrase && $0.phase <= phase }
        let scriptEntries = entries.filter { $0.ref.kind != .phrase && $0.phase <= phase }
        let phrases = pickNew(phraseEntries, limit: budget.phrases, progress: progress)
        let script = pickNew(scriptEntries, limit: budget.script, progress: progress)
        let leftover = max(0, budget.script - script.count)
        let extraPhrases = pickNew(
            phraseEntries.filter { !phrases.contains($0.ref) },
            limit: leftover,
            progress: progress
        )
        return assemble(
            reviewsOf: dueRefs(progress: progress, today: today, allowed: Set(entries.map(\.ref))),
            newItems: phrases + script + extraPhrases,
            phase: phase,
            day: today,
            start: progress.startDate
        )
    }

    public static func planDeck(deckID: String, catalog: Catalog, progress: LearningProgress, today: CivilDay) -> PlannedSession {
        let entries = curriculum(catalog).filter { entry in
            guard entry.ref.kind == .phrase, let phrase = catalog.phrase(entry.ref.id) else { return false }
            return phrase.deck == deckID
        }
        let newItems = pickNew(entries, limit: 8, progress: progress)
        let allowed = Set(entries.map(\.ref))
        return assemble(
            reviewsOf: dueRefs(progress: progress, today: today, allowed: allowed),
            newItems: newItems,
            phase: StudyPlan.phase(on: today, start: progress.startDate),
            day: today,
            start: progress.startDate
        )
    }

    public static func start(_ plan: PlannedSession) -> ActiveSession {
        ActiveSession(day: plan.day, items: plan.items, index: 0, requeues: [:], reviewed: 0)
    }

    public static func curriculum(_ catalog: Catalog) -> [CurriculumEntry] {
        var entries: [CurriculumEntry] = []
        let deckOrder = Dictionary(uniqueKeysWithValues: catalog.decks.map { ($0.id, $0.order) })
        for phrase in catalog.phrases {
            let key = (deckOrder[phrase.deck] ?? 99) * 1000 + phrase.order
            entries.append(CurriculumEntry(ref: StudyRef(id: phrase.id, kind: .phrase), phase: phrase.phase, sortKey: key))
        }
        for consonant in catalog.consonants {
            entries.append(CurriculumEntry(
                ref: StudyRef(id: consonant.id, kind: .consonant),
                phase: .script,
                sortKey: 100_000 + consonant.order
            ))
        }
        for vowel in catalog.vowels {
            entries.append(CurriculumEntry(
                ref: StudyRef(id: vowel.id, kind: .vowel),
                phase: .script,
                sortKey: 200_000 + vowel.order
            ))
        }
        return entries.sorted { lhs, rhs in
            if lhs.sortKey != rhs.sortKey { return lhs.sortKey < rhs.sortKey }
            return lhs.ref.id < rhs.ref.id
        }
    }

    private static func pickNew(_ entries: [CurriculumEntry], limit: Int, progress: LearningProgress) -> [StudyRef] {
        guard limit > 0 else { return [] }
        return entries.filter { progress.cards[$0.ref.id] == nil }.prefix(limit).map(\.ref)
    }

    private static func dueRefs(progress: LearningProgress, today: CivilDay, allowed: Set<StudyRef>) -> [StudyRef] {
        allowed
            .compactMap { ref -> (StudyRef, CivilDay)? in
                guard let card = progress.cards[ref.id], card.due <= today else { return nil }
                return (ref, card.due)
            }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
                return lhs.0.id < rhs.0.id
            }
            .map(\.0)
    }

    private static func assemble(
        reviewsOf due: [StudyRef],
        newItems: [StudyRef],
        phase: Phase,
        day: CivilDay,
        start: CivilDay
    ) -> PlannedSession {
        let room = max(0, StudyPlan.maxItems - newItems.count)
        let reviews = Array(due.prefix(room))
        let items = reviews + newItems
        let minutes = max(1, Int((Double(max(items.count, 1)) * 0.9).rounded(.toNearestOrAwayFromZero)))
        return PlannedSession(
            day: day,
            phase: phase,
            dayNumber: StudyPlan.dayNumber(on: day, start: start),
            items: items,
            newCount: newItems.count,
            reviewCount: reviews.count,
            estimatedMinutes: items.isEmpty ? 0 : minutes
        )
    }
}

public struct DeckStat: Equatable, Sendable {
    public var deckID: String
    public var title: String
    public var total: Int
    public var introduced: Int
    public var mastered: Int
}

public struct ProgressReport: Equatable, Sendable {
    public var streak: Int
    public var introduced: Int
    public var mastered: Int
    public var due: Int
    public var decks: [DeckStat]

    public static func make(catalog: Catalog, progress: LearningProgress, today: CivilDay) -> ProgressReport {
        let phraseIDs = Set(catalog.phrases.map(\.id))
        let introducedCards = progress.cards.filter { phraseIDs.contains($0.key) || catalog.consonant($0.key) != nil || catalog.vowel($0.key) != nil }
        let mastered = introducedCards.values.filter(\.isMastered).count
        let due = introducedCards.values.filter { $0.due <= today }.count
        let decks = catalog.decks.sorted { $0.order < $1.order }.map { deck in
            let phrases = catalog.phrases.filter { $0.deck == deck.id }
            let states = phrases.compactMap { progress.cards[$0.id] }
            return DeckStat(
                deckID: deck.id,
                title: deck.title,
                total: phrases.count,
                introduced: states.count,
                mastered: states.filter(\.isMastered).count
            )
        }
        return ProgressReport(
            streak: progress.streak,
            introduced: introducedCards.count,
            mastered: mastered,
            due: due,
            decks: decks
        )
    }
}

extension Phase: Comparable {
    public static func < (lhs: Phase, rhs: Phase) -> Bool {
        lhs.rank < rhs.rank
    }

    private var rank: Int {
        switch self {
        case .pronunciation: return 0
        case .script: return 1
        case .grammar: return 2
        }
    }
}
