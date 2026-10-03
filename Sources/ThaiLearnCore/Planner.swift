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
    /// 一轮里最多带多少张到期卡。新卡片另外算。
    public static let maxReviews = 40
}

public struct StudyRef: Equatable, Hashable, Sendable, Identifiable {
    public var id: String
    public var kind: StudyKind
    public var template: CardTemplate

    public init(id: String, kind: StudyKind, template: CardTemplate? = nil) {
        self.id = id
        self.kind = kind
        self.template = template ?? CardTemplate.legacyDefault(for: kind)
    }

    /// 进度字典里的键。主模板沿用原来的内容 id，这样旧的 progress.json 对得上。
    public var cardKey: String {
        switch template {
        case .recognition, .consonantClass, .vowelForm, .toneRule:
            return id
        case .production:
            return "\(id)#production"
        }
    }
}

extension StudyRef: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, kind, template
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let kind = try container.decode(StudyKind.self, forKey: .kind)
        let template = try container.decodeIfPresent(CardTemplate.self, forKey: .template)
        self.init(id: id, kind: kind, template: template)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(template, forKey: .template)
    }
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

public enum CardStage: String, Codable, Sendable {
    case new
    case learning
    case review
    case relearning
}

public struct CardState: Equatable, Sendable {
    public var easeFactor: Double
    public var intervalDays: Int
    public var repetitions: Int
    public var due: CivilDay
    public var lapses: Int
    public var introducedOn: CivilDay
    public var lastReviewed: CivilDay?
    public var stability: Double
    public var difficulty: Double
    public var stage: CardStage
    public var step: Int

    public init(
        easeFactor: Double,
        intervalDays: Int,
        repetitions: Int,
        due: CivilDay,
        lapses: Int,
        introducedOn: CivilDay,
        lastReviewed: CivilDay?,
        stability: Double = 0,
        difficulty: Double = 0,
        stage: CardStage = .new,
        step: Int = 0
    ) {
        self.easeFactor = easeFactor
        self.intervalDays = intervalDays
        self.repetitions = repetitions
        self.due = due
        self.lapses = lapses
        self.introducedOn = introducedOn
        self.lastReviewed = lastReviewed
        self.stability = stability
        self.difficulty = difficulty
        self.stage = stage
        self.step = step
    }

    public static func fresh(on day: CivilDay) -> CardState {
        CardState(
            easeFactor: 2.5,
            intervalDays: 0,
            repetitions: 0,
            due: day,
            lapses: 0,
            introducedOn: day,
            lastReviewed: nil,
            stability: 0,
            difficulty: 0,
            stage: .new,
            step: 0
        )
    }

    public var isMastered: Bool { stage == .review && intervalDays >= 21 }

    static func difficulty(fromEase ease: Double) -> Double {
        let value = 10 - (ease - 1.3) / 2.2 * 9
        return min(10, max(1, value))
    }

    static func ease(fromDifficulty difficulty: Double) -> Double {
        let clamped = min(10, max(1, difficulty))
        return 1.3 + (10 - clamped) / 9 * 2.2
    }
}

extension CardState: Codable {
    private enum CodingKeys: String, CodingKey {
        case easeFactor, intervalDays, repetitions, due, lapses, introducedOn, lastReviewed
        case stability, difficulty, stage, step
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        easeFactor = try container.decode(Double.self, forKey: .easeFactor)
        intervalDays = try container.decode(Int.self, forKey: .intervalDays)
        repetitions = try container.decode(Int.self, forKey: .repetitions)
        due = try container.decode(CivilDay.self, forKey: .due)
        lapses = try container.decode(Int.self, forKey: .lapses)
        introducedOn = try container.decode(CivilDay.self, forKey: .introducedOn)
        lastReviewed = try container.decodeIfPresent(CivilDay.self, forKey: .lastReviewed)
        if let stability = try container.decodeIfPresent(Double.self, forKey: .stability),
           let stage = try container.decodeIfPresent(CardStage.self, forKey: .stage) {
            self.stability = stability
            difficulty = try container.decodeIfPresent(Double.self, forKey: .difficulty)
                ?? CardState.difficulty(fromEase: easeFactor)
            self.stage = stage
            step = try container.decodeIfPresent(Int.self, forKey: .step) ?? 0
        } else if lastReviewed == nil {
            stability = 0
            difficulty = 0
            stage = .new
            step = 0
        } else if repetitions == 0 {
            stability = max(Double(intervalDays), 0.1)
            difficulty = CardState.difficulty(fromEase: easeFactor)
            stage = .relearning
            step = 0
        } else {
            stability = max(Double(intervalDays), 0.1)
            difficulty = CardState.difficulty(fromEase: easeFactor)
            stage = .review
            step = 0
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(easeFactor, forKey: .easeFactor)
        try container.encode(intervalDays, forKey: .intervalDays)
        try container.encode(repetitions, forKey: .repetitions)
        try container.encode(due, forKey: .due)
        try container.encode(lapses, forKey: .lapses)
        try container.encode(introducedOn, forKey: .introducedOn)
        try container.encodeIfPresent(lastReviewed, forKey: .lastReviewed)
        try container.encode(stability, forKey: .stability)
        try container.encode(difficulty, forKey: .difficulty)
        try container.encode(stage, forKey: .stage)
        try container.encode(step, forKey: .step)
    }
}

public struct DayLog: Equatable, Sendable {
    public var day: CivilDay
    public var reviews: Int
    public var newItems: Int
    public var remembered: Int

    public init(day: CivilDay, reviews: Int, newItems: Int, remembered: Int = 0) {
        self.day = day
        self.reviews = reviews
        self.newItems = newItems
        self.remembered = remembered
    }
}

extension DayLog: Codable {
    private enum CodingKeys: String, CodingKey {
        case day, reviews, newItems, remembered
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        day = try container.decode(CivilDay.self, forKey: .day)
        reviews = try container.decode(Int.self, forKey: .reviews)
        newItems = try container.decode(Int.self, forKey: .newItems)
        remembered = try container.decodeIfPresent(Int.self, forKey: .remembered) ?? 0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(day, forKey: .day)
        try container.encode(reviews, forKey: .reviews)
        try container.encode(newItems, forKey: .newItems)
        try container.encode(remembered, forKey: .remembered)
    }
}

public struct SessionSnapshot: Codable, Equatable, Sendable {
    public var day: CivilDay
    public var items: [StudyRef]
    public var index: Int
    public var requeues: [String: Int]
}

public struct LearningProgress: Equatable, Sendable {
    public static let currentSchema = 2

    public var schema: Int
    public var startDate: CivilDay
    public var cards: [String: CardState]
    public var streak: Int
    public var lastStudiedDay: CivilDay?
    public var dayLogs: [DayLog]
    public var resume: SessionSnapshot?
    /// FSRS 期望记住率，默认 0.9。
    public var desiredRetention: Double
    /// 每天最多引入多少张新卡片。课程节奏还会再收一档。
    public var newCardLimit: Int

    public init(
        schema: Int,
        startDate: CivilDay,
        cards: [String: CardState],
        streak: Int,
        lastStudiedDay: CivilDay?,
        dayLogs: [DayLog],
        resume: SessionSnapshot?,
        desiredRetention: Double = FSRS.defaultDesiredRetention,
        newCardLimit: Int = 20
    ) {
        self.schema = schema
        self.startDate = startDate
        self.cards = cards
        self.streak = streak
        self.lastStudiedDay = lastStudiedDay
        self.dayLogs = dayLogs
        self.resume = resume
        self.desiredRetention = desiredRetention
        self.newCardLimit = newCardLimit
    }

    public static func fresh(start: CivilDay = StudyPlan.defaultStart) -> LearningProgress {
        LearningProgress(
            schema: currentSchema,
            startDate: start,
            cards: [:],
            streak: 0,
            lastStudiedDay: nil,
            dayLogs: [],
            resume: nil,
            desiredRetention: FSRS.defaultDesiredRetention,
            newCardLimit: 20
        )
    }

    public mutating func recordReview(on day: CivilDay, isNew: Bool, remembered: Bool) {
        if let index = dayLogs.firstIndex(where: { $0.day == day }) {
            dayLogs[index].reviews += 1
            if isNew { dayLogs[index].newItems += 1 }
            if remembered { dayLogs[index].remembered += 1 }
        } else {
            dayLogs.append(DayLog(
                day: day,
                reviews: 1,
                newItems: isNew ? 1 : 0,
                remembered: remembered ? 1 : 0
            ))
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

extension LearningProgress: Codable {
    private enum CodingKeys: String, CodingKey {
        case schema, startDate, cards, streak, lastStudiedDay, dayLogs, resume
        case desiredRetention, newCardLimit
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let storedSchema = try container.decodeIfPresent(Int.self, forKey: .schema) ?? 1
        schema = max(storedSchema, LearningProgress.currentSchema)
        startDate = try container.decode(CivilDay.self, forKey: .startDate)
        cards = try container.decode([String: CardState].self, forKey: .cards)
        streak = try container.decode(Int.self, forKey: .streak)
        lastStudiedDay = try container.decodeIfPresent(CivilDay.self, forKey: .lastStudiedDay)
        dayLogs = try container.decode([DayLog].self, forKey: .dayLogs)
        resume = try container.decodeIfPresent(SessionSnapshot.self, forKey: .resume)
        desiredRetention = try container.decodeIfPresent(Double.self, forKey: .desiredRetention) ?? FSRS.defaultDesiredRetention
        newCardLimit = try container.decodeIfPresent(Int.self, forKey: .newCardLimit) ?? 20
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schema, forKey: .schema)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(cards, forKey: .cards)
        try container.encode(streak, forKey: .streak)
        try container.encodeIfPresent(lastStudiedDay, forKey: .lastStudiedDay)
        try container.encode(dayLogs, forKey: .dayLogs)
        try container.encodeIfPresent(resume, forKey: .resume)
        try container.encode(desiredRetention, forKey: .desiredRetention)
        try container.encode(newCardLimit, forKey: .newCardLimit)
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
        let key = item.cardKey
        let isNew = progress.cards[key]?.lastReviewed == nil
        var card = progress.cards[key] ?? CardState.fresh(on: day)
        let outcome = CardScheduler.apply(grade, to: &card, on: day, retention: progress.desiredRetention)
        if outcome == .requeue {
            let times = requeues[key, default: 0]
            if times < 2 {
                requeues[key] = times + 1
                let insertAt = min(index + 1 + 3, items.count)
                items.insert(item, at: insertAt)
            } else if card.stage != .review {
                card.due = day.adding(days: 1)
                card.intervalDays = max(card.intervalDays, 1)
            }
        }
        progress.cards[key] = card
        progress.recordReview(on: day, isNew: isNew, remembered: grade != .again)
        reviewed += 1

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
    public static func intervalLabel(
        for grade: Grade,
        card: CardState?,
        on day: CivilDay,
        retention: Double
    ) -> String {
        var copy = card ?? CardState.fresh(on: day)
        let outcome = CardScheduler.apply(grade, to: &copy, on: day, retention: retention)
        if outcome == .requeue { return "这一轮再看" }
        if copy.intervalDays <= 1 { return "明天" }
        return "\(copy.intervalDays) 天后"
    }

    public static func planToday(catalog: Catalog, progress: LearningProgress, today: CivilDay) -> PlannedSession {
        let phase = StudyPlan.phase(on: today, start: progress.startDate)
        let budget = StudyPlan.newBudget(for: phase)
        let cap = max(0, progress.newCardLimit)
        let entries = curriculum(catalog)
        let phraseEntries = entries.filter { $0.ref.kind == .phrase && $0.phase <= phase }
        let scriptEntries = entries.filter { $0.ref.kind == .consonant || $0.ref.kind == .vowel }
            .filter { $0.phase <= phase }
        let phrases = pickNew(phraseEntries, limit: min(budget.phrases, cap), progress: progress)
        let scriptRoom = max(0, cap - phrases.count)
        let script = pickNew(scriptEntries, limit: min(budget.script, scriptRoom), progress: progress)
        let leftover = max(0, min(budget.script, scriptRoom) - script.count)
        let extraPhrases = pickNew(
            phraseEntries.filter { !phrases.contains($0.ref) },
            limit: min(leftover, max(0, cap - phrases.count - script.count)),
            progress: progress
        )
        let toneBudget = phase == .pronunciation ? 0 : 2
        let used = phrases.count + script.count + extraPhrases.count
        let toneEntries = entries.filter { $0.ref.kind == .tone && $0.phase <= phase }
        let tones = pickNew(toneEntries, limit: min(toneBudget, max(0, cap - used)), progress: progress)
        return assemble(
            reviewsOf: dueRefs(catalog: catalog, progress: progress, today: today, allowed: nil),
            newItems: phrases + script + extraPhrases + tones,
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
        let newItems = pickNew(entries, limit: min(8, max(0, progress.newCardLimit)), progress: progress)
        let allowed = Set(entries.map(\.ref))
        return assemble(
            reviewsOf: dueRefs(catalog: catalog, progress: progress, today: today, allowed: allowed),
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
            entries.append(CurriculumEntry(
                ref: StudyRef(id: phrase.id, kind: .phrase, template: .recognition),
                phase: phrase.phase,
                sortKey: key * 2
            ))
            entries.append(CurriculumEntry(
                ref: StudyRef(id: phrase.id, kind: .phrase, template: .production),
                phase: phrase.phase,
                sortKey: key * 2 + 1
            ))
        }
        for consonant in catalog.consonants {
            entries.append(CurriculumEntry(
                ref: StudyRef(id: consonant.id, kind: .consonant, template: .consonantClass),
                phase: .script,
                sortKey: 100_000 + consonant.order
            ))
        }
        for vowel in catalog.vowels {
            entries.append(CurriculumEntry(
                ref: StudyRef(id: vowel.id, kind: .vowel, template: .vowelForm),
                phase: .script,
                sortKey: 200_000 + vowel.order
            ))
        }
        for (offset, drill) in ToneDrills.all(in: catalog).enumerated() {
            entries.append(CurriculumEntry(
                ref: StudyRef(id: drill.id, kind: .tone, template: .toneRule),
                phase: .script,
                sortKey: 300_000 + offset
            ))
        }
        return entries.sorted { lhs, rhs in
            if lhs.sortKey != rhs.sortKey { return lhs.sortKey < rhs.sortKey }
            return lhs.ref.id < rhs.ref.id
        }
    }

    private static func pickNew(_ entries: [CurriculumEntry], limit: Int, progress: LearningProgress) -> [StudyRef] {
        guard limit > 0 else { return [] }
        return entries.filter { progress.cards[$0.ref.cardKey] == nil }.prefix(limit).map(\.ref)
    }

    static func ref(forCardKey key: String, catalog: Catalog) -> StudyRef? {
        if key.hasPrefix("tone-") {
            return StudyRef(id: key, kind: .tone, template: .toneRule)
        }
        if let hash = key.firstIndex(of: "#") {
            let noteID = String(key[..<hash])
            let suffix = String(key[key.index(after: hash)...])
            let template = CardTemplate(rawValue: suffix) ?? .recognition
            if catalog.phrase(noteID) != nil {
                return StudyRef(id: noteID, kind: .phrase, template: template)
            }
            return StudyRef(id: noteID, kind: .word, template: template)
        }
        if catalog.phrase(key) != nil {
            return StudyRef(id: key, kind: .phrase, template: .recognition)
        }
        if catalog.consonant(key) != nil {
            return StudyRef(id: key, kind: .consonant, template: .consonantClass)
        }
        if catalog.vowel(key) != nil {
            return StudyRef(id: key, kind: .vowel, template: .vowelForm)
        }
        return nil
    }

    private static func dueRefs(
        catalog: Catalog,
        progress: LearningProgress,
        today: CivilDay,
        allowed: Set<StudyRef>?
    ) -> [StudyRef] {
        progress.cards.compactMap { key, card -> (StudyRef, CivilDay)? in
            guard card.due <= today, let ref = ref(forCardKey: key, catalog: catalog) else { return nil }
            if let allowed, !allowed.contains(ref) { return nil }
            return (ref, card.due)
        }
        .sorted { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
            if lhs.0.id != rhs.0.id { return lhs.0.id < rhs.0.id }
            return lhs.0.template.rawValue < rhs.0.template.rawValue
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
        let reviews = Array(due.prefix(StudyPlan.maxReviews))
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

enum CardScheduler {
    static let learningSteps = 2
    static let relearningSteps = 1

    enum Outcome {
        case requeue
        case done
    }

    static func apply(
        _ grade: Grade,
        to card: inout CardState,
        on day: CivilDay,
        retention: Double
    ) -> Outcome {
        switch card.stage {
        case .new:
            let initial = FSRS.initial(rating: grade.fsrsRating)
            card.stability = initial.stability
            card.difficulty = initial.difficulty
            card.lastReviewed = day
            card.easeFactor = CardState.ease(fromDifficulty: card.difficulty)
            switch grade {
            case .easy:
                card.repetitions += 1
                return graduate(&card, on: day, retention: retention)
            case .good:
                card.stage = .learning
                card.step = 1
                card.repetitions += 1
                card.due = day
                card.intervalDays = 0
                return .requeue
            case .hard, .again:
                card.stage = .learning
                card.step = 0
                card.due = day
                card.intervalDays = 0
                return .requeue
            }
        case .learning:
            let elapsed = elapsedDays(of: card, on: day)
            return step(&card, grade: grade, steps: learningSteps, on: day, retention: retention, sameDay: elapsed < 1)
        case .relearning:
            let elapsed = elapsedDays(of: card, on: day)
            return step(&card, grade: grade, steps: relearningSteps, on: day, retention: retention, sameDay: elapsed < 1)
        case .review:
            let elapsed = elapsedDays(of: card, on: day)
            let next = FSRS.next(
                stability: card.stability,
                difficulty: card.difficulty,
                rating: grade.fsrsRating,
                elapsedDays: elapsed,
                desiredRetention: retention
            )
            card.stability = next.stability
            card.difficulty = next.difficulty
            card.lastReviewed = day
            card.easeFactor = CardState.ease(fromDifficulty: card.difficulty)
            if grade == .again {
                card.lapses += 1
                card.stage = .relearning
                card.step = 0
                card.due = day
                card.intervalDays = 0
                return .requeue
            }
            card.repetitions += 1
            return graduate(&card, on: day, retention: retention)
        }
    }

    private static func step(
        _ card: inout CardState,
        grade: Grade,
        steps: Int,
        on day: CivilDay,
        retention: Double,
        sameDay: Bool
    ) -> Outcome {
        let elapsed = sameDay ? 0 : elapsedDays(of: card, on: day)
        let next = FSRS.next(
            stability: card.stability,
            difficulty: card.difficulty,
            rating: grade.fsrsRating,
            elapsedDays: elapsed,
            desiredRetention: retention
        )
        card.stability = next.stability
        card.difficulty = next.difficulty
        card.lastReviewed = day
        card.easeFactor = CardState.ease(fromDifficulty: card.difficulty)
        switch grade {
        case .again:
            card.step = 0
            card.due = day
            card.intervalDays = 0
            return .requeue
        case .hard:
            card.due = day
            card.intervalDays = 0
            return .requeue
        case .easy:
            card.repetitions += 1
            return graduate(&card, on: day, retention: retention)
        case .good:
            card.step += 1
            card.repetitions += 1
            if card.step >= steps {
                return graduate(&card, on: day, retention: retention)
            }
            card.due = day
            card.intervalDays = 0
            return .requeue
        }
    }

    private static func graduate(_ card: inout CardState, on day: CivilDay, retention: Double) -> Outcome {
        card.stage = .review
        card.step = 0
        let days = FSRS.intervalDays(stability: card.stability, desiredRetention: retention)
        card.intervalDays = days
        card.due = day.adding(days: days)
        return .done
    }

    private static func elapsedDays(of card: CardState, on day: CivilDay) -> Double {
        guard let last = card.lastReviewed else { return 0 }
        return Double(max(0, day.daysSince(last)))
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
