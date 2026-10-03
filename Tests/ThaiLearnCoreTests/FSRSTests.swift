import XCTest
import ThaiLearnCore

final class FSRSTests: XCTestCase {
    func testDefaultsMatchThePublishedFSRS5Vector() {
        XCTAssertEqual(FSRS.defaultParameters.count, 19)
        XCTAssertEqual(FSRS.defaultDesiredRetention, 0.9, accuracy: 0.0001)
        XCTAssertEqual(Grade.again.fsrsRating, 1)
        XCTAssertEqual(Grade.hard.fsrsRating, 2)
        XCTAssertEqual(Grade.good.fsrsRating, 3)
        XCTAssertEqual(Grade.easy.fsrsRating, 4)
    }

    func testInitialStabilityRisesWithTheRating() {
        let again = FSRS.initial(rating: Grade.again.fsrsRating)
        let hard = FSRS.initial(rating: Grade.hard.fsrsRating)
        let good = FSRS.initial(rating: Grade.good.fsrsRating)
        let easy = FSRS.initial(rating: Grade.easy.fsrsRating)
        XCTAssertLessThan(again.stability, hard.stability)
        XCTAssertLessThan(hard.stability, good.stability)
        XCTAssertLessThan(good.stability, easy.stability)
        XCTAssertGreaterThan(again.difficulty, easy.difficulty)
        for memory in [again, hard, good, easy] {
            XCTAssertGreaterThanOrEqual(memory.difficulty, 1)
            XCTAssertLessThanOrEqual(memory.difficulty, 10)
        }
    }

    func testIntervalAtDefaultRetentionMatchesStability() {
        let stability = 6.4
        let days = FSRS.intervalDays(stability: stability, desiredRetention: 0.9)
        XCTAssertEqual(days, 6)
        let higher = FSRS.intervalDays(stability: stability, desiredRetention: 0.97)
        XCTAssertLessThan(higher, days)
    }

    func testSuccessfulReviewLengthensStabilityAndALapseShortensIt() {
        let start = FSRS.Memory(stability: 4, difficulty: 5)
        let remembered = FSRS.next(
            stability: start.stability,
            difficulty: start.difficulty,
            rating: Grade.good.fsrsRating,
            elapsedDays: 4
        )
        XCTAssertGreaterThan(remembered.stability, start.stability)
        let forgotten = FSRS.next(
            stability: start.stability,
            difficulty: start.difficulty,
            rating: Grade.again.fsrsRating,
            elapsedDays: 4
        )
        XCTAssertLessThan(forgotten.stability, start.stability)
        XCTAssertGreaterThanOrEqual(forgotten.difficulty, 1)
        XCTAssertLessThanOrEqual(remembered.difficulty, 10)
    }

    func testSameDayReviewUsesTheShortTermCurve() {
        let start = FSRS.initial(rating: Grade.good.fsrsRating)
        let again = FSRS.next(
            stability: start.stability,
            difficulty: start.difficulty,
            rating: Grade.again.fsrsRating,
            elapsedDays: 0
        )
        XCTAssertLessThan(again.stability, start.stability)
        let easy = FSRS.next(
            stability: start.stability,
            difficulty: start.difficulty,
            rating: Grade.easy.fsrsRating,
            elapsedDays: 0
        )
        XCTAssertGreaterThan(easy.stability, start.stability)
    }

    func testOldProgressJSONKeepsTheSchedule() throws {
        let json = """
        {"cards":{"greet-hello":{"due":"2026-10-08","easeFactor":2.5,"intervalDays":6,"introducedOn":"2026-10-02","lapses":1,"lastReviewed":"2026-10-02","repetitions":2}},"dayLogs":[{"day":"2026-10-02","newItems":8,"reviews":8}],"lastStudiedDay":"2026-10-02","resume":{"day":"2026-10-02","index":1,"items":[{"id":"greet-hello","kind":"phrase"}],"requeues":{}},"schema":1,"startDate":"2026-10-02","streak":3}
        """
        let progress = try JSONDecoder().decode(LearningProgress.self, from: Data(json.utf8))
        XCTAssertEqual(progress.schema, 2)
        XCTAssertEqual(progress.streak, 3)
        XCTAssertEqual(progress.startDate, try CivilDay(iso: "2026-10-02"))
        XCTAssertEqual(progress.desiredRetention, 0.9, accuracy: 0.0001)
        XCTAssertEqual(progress.newCardLimit, 20)
        XCTAssertEqual(progress.dayLogs.first?.remembered, 0)
        XCTAssertEqual(progress.resume?.items.first?.template, .recognition)
        let card = try XCTUnwrap(progress.cards["greet-hello"])
        XCTAssertEqual(card.due, try CivilDay(iso: "2026-10-08"))
        XCTAssertEqual(card.lapses, 1)
        XCTAssertEqual(card.intervalDays, 6)
        XCTAssertEqual(card.repetitions, 2)
        XCTAssertEqual(card.stage, .review)
        XCTAssertEqual(card.stability, 6, accuracy: 0.001)
        XCTAssertEqual(card.easeFactor, 2.5, accuracy: 0.001)

        let encoded = try JSONEncoder().encode(progress)
        let again = try JSONDecoder().decode(LearningProgress.self, from: encoded)
        XCTAssertEqual(again.cards["greet-hello"]?.due, card.due)
        XCTAssertEqual(again.cards["greet-hello"]?.lapses, 1)
        XCTAssertEqual(again.streak, 3)
    }

    func testLapsedSM2CardBecomesRelearning() throws {
        let json = """
        {"cards":{"greet-hello":{"due":"2026-10-03","easeFactor":1.3,"intervalDays":1,"introducedOn":"2026-10-02","lapses":2,"lastReviewed":"2026-10-02","repetitions":0}},"dayLogs":[],"schema":1,"startDate":"2026-10-02","streak":1}
        """
        let progress = try JSONDecoder().decode(LearningProgress.self, from: Data(json.utf8))
        XCTAssertEqual(progress.cards["greet-hello"]?.stage, .relearning)
        XCTAssertEqual(progress.cards["greet-hello"]?.due.iso, "2026-10-03")
        XCTAssertEqual(progress.cards["greet-hello"]?.lapses, 2)
    }

    func testProductionCardsAreSeparateFromRecognition() throws {
        let catalog = try ContentLoader.load(from: contentRoot())
        let today = StudyPlan.defaultStart
        let plan = StudySession.planToday(catalog: catalog, progress: .fresh(start: today), today: today)
        let templates = plan.items.prefix(2).map(\.template)
        XCTAssertEqual(templates, [.recognition, .production])
        XCTAssertEqual(plan.items[0].id, plan.items[1].id)
        XCTAssertNotEqual(plan.items[0].cardKey, plan.items[1].cardKey)
    }
}

private func contentRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Content")
}
