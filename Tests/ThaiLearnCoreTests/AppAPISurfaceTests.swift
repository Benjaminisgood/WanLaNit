import XCTest
import ThaiLearnCore

/// Compiles as a real client of ThaiLearnCore. No `@testable import`, so this
/// fails if the macOS app target would be unable to see a symbol it uses.
final class AppAPISurfaceTests: XCTestCase {
    func testSymbolsTheAppUsesArePublic() throws {
        let missing = ContentError(issues: ["应用里没有课程文件。"])
        XCTAssertEqual(missing.issues, ["应用里没有课程文件。"])
        XCTAssertEqual(missing, ContentError(issues: ["应用里没有课程文件。"]))
        XCTAssertFalse(missing.localizedDescription.isEmpty)
        XCTAssertEqual(missing.description, missing.issues.joined(separator: "\n"))

        let catalog = try ContentLoader.load(from: contentRoot())
        XCTAssertGreaterThanOrEqual(catalog.words.count, 1000)
        if let word = catalog.word(thai: "กิน") {
            _ = word.id
            _ = word.thai
            _ = word.spoken
            _ = word.romanization
            _ = word.meaning
            _ = word.band
            _ = word.topic
            _ = word.order
        }
        let today = CivilDay(year: 2026, month: 10, day: 3)
        XCTAssertEqual(today.iso, "2026-10-03")
        XCTAssertEqual(today, today)
        XCTAssertTrue(today > today.adding(days: -1))

        var progress = LearningProgress.fresh(start: today)
        let encoded = try JSONEncoder().encode(progress)
        progress = try JSONDecoder().decode(LearningProgress.self, from: encoded)
        XCTAssertEqual(progress.startDate, today)
        XCTAssertEqual(progress.streak, 0)
        XCTAssertNil(progress.resume)

        let phase = StudyPlan.phase(on: today, start: progress.startDate)
        let dayNumber = StudyPlan.dayNumber(on: today, start: progress.startDate)
        XCTAssertFalse(phase.title.isEmpty)
        XCTAssertFalse(phase.daySpan.isEmpty)
        XCTAssertFalse(phase.summary.isEmpty)
        XCTAssertGreaterThan(dayNumber, 0)

        let report = ProgressReport.make(catalog: catalog, progress: progress, today: today)
        XCTAssertEqual(report.streak, progress.streak)
        _ = report.introduced
        _ = report.due
        _ = report.mastered
        for deck in report.decks {
            _ = deck.deckID
            _ = deck.title
            _ = deck.introduced
            _ = deck.total
        }

        let planned = StudySession.planToday(catalog: catalog, progress: progress, today: today)
        _ = planned.reviewCount
        _ = planned.newCount
        _ = planned.estimatedMinutes
        XCTAssertFalse(planned.items.isEmpty)

        var session = StudySession.start(planned)
        XCTAssertFalse(session.isFinished)
        XCTAssertEqual(session.index, 0)
        XCTAssertFalse(session.positionLabel.isEmpty)
        if let ref = session.current {
            _ = ref.id
            _ = ref.kind.chinese
            switch ref.kind {
            case .phrase:
                if let phrase = catalog.phrase(ref.id) {
                    touch(phrase)
                }
            case .consonant:
                if let consonant = catalog.consonant(ref.id) {
                    touch(consonant)
                }
            case .vowel:
                if let vowel = catalog.vowel(ref.id) {
                    touch(vowel)
                }
            case .tone:
                if let drill = ToneDrills.drill(id: ref.id, catalog: catalog) {
                    _ = drill.consonantClass.chinese
                    _ = drill.toneMark.chinese
                    _ = drill.ending.chinese
                    _ = drill.length.chinese
                    _ = drill.tone.chinese
                    _ = drill.exampleThai
                    _ = drill.spoken
                }
            case .word:
                if let word = catalog.word(ref.id) {
                    _ = word.thai
                    _ = word.spoken
                    _ = word.romanization
                    _ = word.meaning
                    _ = word.band
                    _ = word.topic
                    _ = word.order
                }
            }
            _ = ref.template
            _ = ref.cardKey
        }
        _ = progress.desiredRetention
        _ = progress.newCardLimit
        XCTAssertFalse(progress.unlockAll)
        progress.unlockAll = true
        XCTAssertTrue(progress.unlockAll)
        _ = StudySession.intervalLabel(for: .good, card: nil, on: today, retention: progress.desiredRetention)
        let stats = StudyStats.make(catalog: catalog, progress: progress, today: today)
        _ = stats.retention
        _ = stats.learning
        _ = stats.reviewing
        for day in stats.forecast {
            _ = day.day.iso
            _ = day.dueCount
        }
        for sample in stats.days {
            _ = sample.reviews
            _ = sample.remembered
        }
        for template in CardTemplate.allCases {
            _ = template.chinese
        }
        session.grade(.again, progress: &progress)
        session.grade(.hard, progress: &progress)
        session.grade(.good, progress: &progress)
        session.grade(.easy, progress: &progress)
        for grade in Grade.allCases {
            _ = grade.title
            _ = grade.hint
            XCTAssertEqual(grade, grade)
        }
        progress.resume = session.snapshot
        if let resume = progress.resume {
            XCTAssertEqual(resume.day, today)
            _ = resume.items.count - resume.index
            _ = resume.items.isEmpty
        }
        let restored = ActiveSession.restore(session.snapshot)
        _ = restored.current

        if let deck = catalog.decks.sorted(by: { $0.order < $1.order }).first {
            _ = deck.id
            _ = deck.title
            _ = deck.blurb
            _ = deck.phase.title
            _ = deck.phase.daySpan
            let deckPlan = StudySession.planDeck(deckID: deck.id, catalog: catalog, progress: progress, today: today)
            _ = deckPlan.items.count
            for phrase in catalog.phrases.filter({ $0.deck == deck.id }).sorted(by: { $0.order < $1.order }) {
                touch(phrase)
            }
        }

        for lesson in catalog.tones {
            _ = lesson.id
            _ = lesson.tone.chinese
            _ = lesson.tone.markSample
            _ = lesson.exampleThai
            _ = lesson.pitch
            _ = lesson.mandarin
            _ = lesson.exampleRoman
            _ = lesson.exampleMeaning
        }
        for set in catalog.minimalSets {
            _ = set.id
            _ = set.title
            _ = set.hint
            for item in set.items {
                _ = item.id
                _ = item.thai
                _ = item.roman
                _ = item.tone.chinese
                _ = item.meaning
            }
        }
        for lesson in catalog.sounds {
            _ = lesson.id
            _ = lesson.title
            _ = lesson.problem
            _ = lesson.howTo
            for pair in lesson.pairs {
                _ = pair.id
                _ = pair.thai
                _ = pair.roman
                _ = pair.meaning
            }
        }
        XCTAssertFalse(RomanizationLegend.summary.isEmpty)

        var rng = SplitMix64(seed: UInt64(Date().timeIntervalSince1970))
        if let question = ToneQuiz.question(in: catalog.minimalSets, rng: &rng) {
            _ = question.setTitle
            _ = question.thai
            _ = question.roman
            _ = question.meaning
            _ = question.answer.chinese
            for tone in question.choices {
                _ = tone.chinese
                _ = (tone == question.answer)
            }
        }

        for klass in ConsonantClass.allCases {
            _ = klass.chinese
            _ = klass.hashValue
        }
        for consonant in catalog.consonants.sorted(by: { $0.order < $1.order }) {
            touch(consonant)
        }
        for vowel in catalog.vowels.sorted(by: { $0.order < $1.order }) {
            touch(vowel)
        }
        for note in catalog.culture.sorted(by: { $0.order < $1.order }) {
            _ = note.id
            _ = note.title
            _ = note.thai
            _ = note.roman
            _ = note.body
        }

        let ruling = ToneEngine.ruling(
            consonantClass: .mid,
            toneMark: .none,
            ending: .live,
            length: .long
        )
        _ = ruling.headline
        _ = ruling.tone.markSample
        _ = ruling.tone.mandarinHint
        _ = ruling.detail
        for mark in ToneMark.allCases {
            _ = mark.chinese
        }
        for ending in SyllableEnding.allCases {
            _ = ending.chinese
        }
        for length in SyllableLength.allCases {
            _ = length.chinese
        }
        _ = catalog.toneExamples(
            consonantClass: .mid,
            toneMark: ToneMark.none,
            ending: SyllableEnding.live,
            length: SyllableLength.long
        ).map { example in
            (example.syllableThai, example.roman, example.phraseThai, example.meaning)
        }

        XCTAssertGreaterThanOrEqual(catalog.starters.count, 3)
        for text in catalog.starters {
            _ = text.id
            _ = text.title
            _ = text.body
            _ = text.level
        }
        let stripped = HTMLText.plainText(from: "<p>กินข้าว<br>ที่บ้าน</p>")
        XCTAssertTrue(stripped.contains("กินข้าว"))
        _ = HTMLText.title(from: "<title>早上</title>")
        let tokens = ThaiSegmenter.dictionaryTokens(in: "กินข้าว", dictionary: catalog.words.map(\.thai))
        XCTAssertEqual(tokens.map(\.text), ["กินข้าว"])
        _ = ThaiSegmenter.tokens(in: "กินข้าว", dictionary: catalog.words.map(\.thai))
        for mark in [WordMark.new, .learning, .known, .ignored] {
            _ = mark.rawValue
        }
        let memory = WordMemory(status: .learning, level: 1)
        XCTAssertEqual(memory.status, .learning)
        progress.wordMemory["กิน"] = memory
        progress.library.append(ReaderDocument(id: "doc", title: "标题", body: "กินข้าว", source: "粘贴"))
        ReaderState.setMark(.known, level: 5, thai: "กิน", progress: &progress)
        let shown = ReaderState.display(thai: "กิน", catalog: catalog, progress: progress)
        XCTAssertEqual(shown.status, .known)
        ReaderState.addToReview(thai: "กิน", sentence: "กินข้าว", catalog: catalog, progress: &progress, on: today)
        XCTAssertFalse(progress.readerNotes.isEmpty)
        _ = ReaderState.cardKey(for: "กิน", catalog: catalog)
        let coverage = ReaderState.coverage(in: "กินข้าว", catalog: catalog, progress: progress)
        _ = coverage.uniqueWords
        _ = coverage.known
        _ = coverage.fraction
        if let token = tokens.first {
            _ = ReaderState.sentence(around: token, in: tokens)
        }
        _ = progress.library.first?.source
        _ = progress.readerNotes.first?.context

        let steps = LearningPath.steps(catalog: catalog, progress: progress)
        XCTAssertEqual(steps.map(\.kind), [.letters, .tones, .vocabulary, .reading])
        for step in steps {
            _ = step.id
            _ = step.title
            _ = step.detail
            XCTAssertEqual(step.unlocked, LearningPath.isUnlocked(step.kind, catalog: catalog, progress: progress))
        }
        XCTAssertEqual(LearningPath.consonantsBeforeTones, 8)
        XCTAssertEqual(LearningPath.toneCardsBeforeVocabulary, 4)
        XCTAssertEqual(LearningPath.wordCardsBeforeReading, 10)
    }

    private func touch(_ phrase: Phrase) {
        _ = phrase.id
        _ = phrase.kind.chinese
        _ = phrase.thai
        _ = phrase.spoken
        _ = phrase.romanization
        _ = phrase.meaning
        _ = phrase.note
        for syllable in phrase.syllables {
            _ = syllable.thai
            _ = syllable.roman
            _ = syllable.note
        }
    }

    private func touch(_ consonant: Consonant) {
        _ = consonant.id
        _ = consonant.symbol
        _ = consonant.order
        _ = consonant.consonantClass.chinese
        _ = consonant.obsolete
        _ = consonant.nameThai
        _ = consonant.nameRoman
        _ = consonant.meaning
        _ = consonant.spoken
        _ = consonant.initial
        _ = consonant.final
        _ = consonant.finalNote
        _ = consonant.note
        XCTAssertTrue(ConsonantClass.allCases.contains(consonant.consonantClass))
    }

    private func touch(_ vowel: Vowel) {
        _ = vowel.id
        _ = vowel.symbols
        _ = vowel.roman
        _ = vowel.lengthLabel
        _ = vowel.soundHint
        _ = vowel.exampleThai
        _ = vowel.exampleRoman
        _ = vowel.exampleMeaning
        _ = vowel.note
        _ = vowel.order
    }
}

private func contentRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Content")
}
