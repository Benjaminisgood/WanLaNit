import XCTest
import ThaiLearnCore

final class LearningPathTests: XCTestCase {
    func testReadingOpensOnlyAfterLettersTonesAndWords() throws {
        let catalog = try ContentLoader.load(from: pathContentRoot())
        let day = CivilDay(year: 2026, month: 10, day: 2)
        var progress = LearningProgress.fresh(start: day)

        XCTAssertEqual(LearningPath.steps(catalog: catalog, progress: progress).map(\.unlocked), [true, false, false, false])

        for consonant in catalog.consonants.prefix(LearningPath.consonantsBeforeTones) {
            progress.cards[consonant.id] = CardState.fresh(on: day)
        }
        XCTAssertTrue(LearningPath.isUnlocked(.tones, catalog: catalog, progress: progress))
        XCTAssertFalse(LearningPath.isUnlocked(.vocabulary, catalog: catalog, progress: progress))

        for drill in ToneDrills.all(in: catalog).prefix(LearningPath.toneCardsBeforeVocabulary) {
            progress.cards[drill.id] = CardState.fresh(on: day)
        }
        XCTAssertTrue(LearningPath.isUnlocked(.vocabulary, catalog: catalog, progress: progress))
        XCTAssertFalse(LearningPath.isUnlocked(.reading, catalog: catalog, progress: progress))

        for word in catalog.words.prefix(LearningPath.wordCardsBeforeReading) {
            progress.cards[word.id] = CardState.fresh(on: day)
        }
        let steps = LearningPath.steps(catalog: catalog, progress: progress)
        XCTAssertEqual(steps.map(\.kind), [.letters, .tones, .vocabulary, .reading])
        XCTAssertTrue(steps.allSatisfy(\.unlocked))
        XCTAssertTrue(steps.allSatisfy { !$0.title.isEmpty && !$0.detail.isEmpty })
    }

    func testLaterMaterialDoesNotSkipTheEarlierGate() throws {
        let catalog = try ContentLoader.load(from: pathContentRoot())
        let day = CivilDay(year: 2026, month: 10, day: 2)
        var progress = LearningProgress.fresh(start: day)
        for word in catalog.words.prefix(LearningPath.wordCardsBeforeReading) {
            progress.cards[word.id] = CardState.fresh(on: day)
        }
        for drill in ToneDrills.all(in: catalog).prefix(LearningPath.toneCardsBeforeVocabulary) {
            progress.cards[drill.id] = CardState.fresh(on: day)
        }
        XCTAssertFalse(LearningPath.isUnlocked(.tones, catalog: catalog, progress: progress))
        XCTAssertFalse(LearningPath.isUnlocked(.vocabulary, catalog: catalog, progress: progress))
        XCTAssertFalse(LearningPath.isUnlocked(.reading, catalog: catalog, progress: progress))
        XCTAssertTrue(LearningPath.isUnlocked(.letters, catalog: catalog, progress: progress))
    }
}

private func pathContentRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Content")
}
