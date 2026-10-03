import XCTest
@testable import ThaiLearnCore

final class ToneEngineTests: XCTestCase {
    func testUnmarkedSyllables() {
        XCTAssertEqual(ToneEngine.tone(consonantClass: .mid, toneMark: .none, ending: .live, length: .long), .mid)
        XCTAssertEqual(ToneEngine.tone(consonantClass: .mid, toneMark: .none, ending: .dead, length: .short), .low)
        XCTAssertEqual(ToneEngine.tone(consonantClass: .mid, toneMark: .none, ending: .dead, length: .long), .low)
        XCTAssertEqual(ToneEngine.tone(consonantClass: .high, toneMark: .none, ending: .live, length: .long), .rising)
        XCTAssertEqual(ToneEngine.tone(consonantClass: .high, toneMark: .none, ending: .dead, length: .long), .low)
        XCTAssertEqual(ToneEngine.tone(consonantClass: .low, toneMark: .none, ending: .live, length: .short), .mid)
        XCTAssertEqual(ToneEngine.tone(consonantClass: .low, toneMark: .none, ending: .dead, length: .short), .high)
        XCTAssertEqual(ToneEngine.tone(consonantClass: .low, toneMark: .none, ending: .dead, length: .long), .falling)
    }

    func testToneMarksIgnoreLength() {
        XCTAssertEqual(ToneEngine.tone(consonantClass: .mid, toneMark: .maiEk, ending: .live, length: .long), .low)
        XCTAssertEqual(ToneEngine.tone(consonantClass: .high, toneMark: .maiEk, ending: .dead, length: .short), .low)
        XCTAssertEqual(ToneEngine.tone(consonantClass: .low, toneMark: .maiEk, ending: .live, length: .long), .falling)
        XCTAssertEqual(ToneEngine.tone(consonantClass: .mid, toneMark: .maiTho, ending: .live, length: .long), .falling)
        XCTAssertEqual(ToneEngine.tone(consonantClass: .low, toneMark: .maiTho, ending: .dead, length: .short), .high)
        XCTAssertEqual(ToneEngine.tone(consonantClass: .mid, toneMark: .maiTri, ending: .live, length: .short), .high)
        XCTAssertEqual(ToneEngine.tone(consonantClass: .mid, toneMark: .maiChattawa, ending: .live, length: .long), .rising)
        XCTAssertFalse(ToneEngine.isRegular(consonantClass: .low, toneMark: .maiTri))
        XCTAssertTrue(ToneEngine.isRegular(consonantClass: .mid, toneMark: .maiChattawa))
    }

    func testClassicKhaaSet() {
        let mid = ToneEngine.tone(consonantClass: .low, toneMark: .none, ending: .live, length: .long)
        let low = ToneEngine.tone(consonantClass: .high, toneMark: .maiEk, ending: .live, length: .long)
        let falling = ToneEngine.tone(consonantClass: .low, toneMark: .maiEk, ending: .live, length: .long)
        let high = ToneEngine.tone(consonantClass: .low, toneMark: .maiTho, ending: .live, length: .long)
        let rising = ToneEngine.tone(consonantClass: .high, toneMark: .none, ending: .live, length: .long)
        XCTAssertEqual([mid, low, falling, high, rising], [.mid, .low, .falling, .high, .rising])
    }

    func testRomanToneReadsPaiboonMarks() {
        XCTAssertEqual(RomanTone.tone(in: "kaa"), .mid)
        XCTAssertEqual(RomanTone.tone(in: "khàa"), .low)
        XCTAssertEqual(RomanTone.tone(in: "khâa"), .falling)
        XCTAssertEqual(RomanTone.tone(in: "kháa"), .high)
        XCTAssertEqual(RomanTone.tone(in: "khǎa"), .rising)
        XCTAssertEqual(RomanTone.tone(in: "dâai"), .falling)
    }
}

final class SM2Tests: XCTestCase {
    func testSuccessfulSequence() {
        var state = SM2.State.new
        state = SM2.review(quality: 5, state: state)
        XCTAssertEqual(state.repetitions, 1)
        XCTAssertEqual(state.intervalDays, 1)
        XCTAssertEqual(state.easeFactor, 2.6, accuracy: 0.001)

        state = SM2.review(quality: 4, state: state)
        XCTAssertEqual(state.repetitions, 2)
        XCTAssertEqual(state.intervalDays, 6)
        XCTAssertEqual(state.easeFactor, 2.6, accuracy: 0.001)

        state = SM2.review(quality: 4, state: state)
        XCTAssertEqual(state.repetitions, 3)
        XCTAssertEqual(state.intervalDays, 16)
    }

    func testFailureResetsAndEaseDoesNotFallBelowFloor() {
        var state = SM2.State(repetitions: 4, easeFactor: 1.4, intervalDays: 20)
        state = SM2.review(quality: 0, state: state)
        XCTAssertEqual(state.repetitions, 0)
        XCTAssertEqual(state.intervalDays, 1)
        XCTAssertGreaterThanOrEqual(state.easeFactor, 1.3)
    }

    func testGradesUseSM2Qualities() {
        XCTAssertEqual(Grade.again.quality, 1)
        XCTAssertEqual(Grade.hard.quality, 3)
        XCTAssertEqual(Grade.good.quality, 4)
        XCTAssertEqual(Grade.easy.quality, 5)
    }
}

final class CivilDayTests: XCTestCase {
    func testAddingAndDistance() throws {
        let start = try CivilDay(iso: "2026-10-02")
        XCTAssertEqual(start.adding(days: 14).iso, "2026-10-16")
        XCTAssertEqual(start.adding(days: 45).iso, "2026-11-16")
        XCTAssertEqual(start.adding(days: 45).daysSince(start), 45)
        XCTAssertEqual(start.daysSince(start), 0)
    }

    func testRejectsImpossibleDates() {
        XCTAssertThrowsError(try CivilDay(iso: "2026-02-29"))
        XCTAssertThrowsError(try CivilDay(iso: "2026-13-01"))
        XCTAssertThrowsError(try CivilDay(iso: "10-02"))
        XCTAssertNoThrow(try CivilDay(iso: "2024-02-29"))
    }

    func testRoundTrip() throws {
        let day = try CivilDay(iso: "2026-10-02")
        let data = try JSONEncoder().encode(day)
        let decoded = try JSONDecoder().decode(CivilDay.self, from: data)
        XCTAssertEqual(decoded, day)
        XCTAssertEqual(String(data: data, encoding: .utf8), "\"2026-10-02\"")
    }
}

final class StudyPlanTests: XCTestCase {
    func testPhasesFollowTheCalendar() throws {
        let start = StudyPlan.defaultStart
        XCTAssertEqual(start, try CivilDay(iso: "2026-10-02"))
        XCTAssertEqual(StudyPlan.phase(on: start, start: start), .pronunciation)
        XCTAssertEqual(StudyPlan.dayNumber(on: start, start: start), 1)
        XCTAssertEqual(StudyPlan.phase(on: start.adding(days: 13), start: start), .pronunciation)
        XCTAssertEqual(StudyPlan.phase(on: start.adding(days: 14), start: start), .script)
        XCTAssertEqual(StudyPlan.phase(on: start.adding(days: 44), start: start), .script)
        XCTAssertEqual(StudyPlan.phase(on: start.adding(days: 45), start: start), .grammar)
    }
}

final class ContentTests: XCTestCase {
    func testCatalogLoadsAndChecksOut() throws {
        let catalog = try ContentLoader.load(from: contentDirectory())
        XCTAssertGreaterThanOrEqual(catalog.phrases.count, 150)
        XCTAssertEqual(catalog.consonants.count, 44)
        XCTAssertGreaterThanOrEqual(catalog.vowels.count, 24)
        XCTAssertEqual(catalog.tones.map(\.tone).count, 5)

        let hello = try XCTUnwrap(catalog.phrases.first { $0.thai == "สวัสดีครับ" })
        XCTAssertEqual(hello.romanization, "sà-wàt-dii khráp")
        let thanks = try XCTUnwrap(catalog.phrases.first { $0.thai == "ขอบคุณครับ" })
        XCTAssertEqual(thanks.romanization, "khɔ̀ɔp-khun khráp")
        let name = try XCTUnwrap(catalog.phrases.first { $0.thai.contains("ผมชื่อ") })
        XCTAssertTrue(name.thai.hasSuffix("ครับ"))
        let nice = try XCTUnwrap(catalog.phrase("intro-nice"))
        XCTAssertEqual(nice.romanization, "yin-dii thîi dâai rúu-jàk khráp")
        let eaten = try XCTUnwrap(catalog.phrase("food-eaten"))
        XCTAssertEqual(eaten.romanization, "kin khâao rʉ̌ʉ yang khráp")
        let cute = try XCTUnwrap(catalog.phrase("friends-cute"))
        XCTAssertEqual(cute.thai, "คุณน่ารักมาก")
        XCTAssertEqual(cute.romanization, "khun nâa-rák mâak")
        let studying = try XCTUnwrap(catalog.phrase("intro-studying"))
        XCTAssertEqual(studying.thai, "ผมกำลังเรียนภาษาไทยครับ")

        let dai = try XCTUnwrap(catalog.phrase("greet-ok")?.syllables.first { $0.thai == "ได้" })
        XCTAssertEqual(dai.expectedTone, .falling)
        XCTAssertEqual(RomanTone.tone(in: dai.roman), .falling)

        let ko = try XCTUnwrap(catalog.consonant("ko-kai"))
        XCTAssertEqual(ko.nameRoman, "kɔɔ kài")
        XCTAssertEqual(ko.consonantClass, .mid)
        XCTAssertTrue(try XCTUnwrap(catalog.consonant("kho-khuat")).obsolete)
        XCTAssertEqual(catalog.consonant("ngo-nguu")?.initial, "ng")
        XCTAssertEqual(catalog.consonant("do-dek")?.initial, "d")
        XCTAssertEqual(catalog.consonant("bo-baimaai")?.initial, "b")
    }

    func testBrokenContentIsReported() throws {
        let catalog = try ContentLoader.load(from: contentDirectory())
        var broken = catalog
        broken.phrases[0].romanization = "wrong"
        let issues = ContentLoader.validate(broken)
        XCTAssertFalse(issues.isEmpty)
    }
}

final class SessionTests: XCTestCase {
    func testFirstDayIsEightNewPhrases() throws {
        let catalog = try ContentLoader.load(from: contentDirectory())
        let today = StudyPlan.defaultStart
        let plan = StudySession.planToday(catalog: catalog, progress: .fresh(start: today), today: today)
        XCTAssertEqual(plan.phase, .pronunciation)
        XCTAssertEqual(plan.dayNumber, 1)
        XCTAssertEqual(plan.reviewCount, 0)
        XCTAssertEqual(plan.newCount, 8)
        XCTAssertEqual(plan.items.count, 8)
        XCTAssertLessThanOrEqual(plan.estimatedMinutes, 20)
        let first = try XCTUnwrap(catalog.phrase(plan.items[0].id))
        XCTAssertEqual(first.thai, "สวัสดีครับ")
    }

    func testScriptPhaseIntroducesLetters() throws {
        let catalog = try ContentLoader.load(from: contentDirectory())
        let start = StudyPlan.defaultStart
        let today = start.adding(days: 14)
        let plan = StudySession.planToday(catalog: catalog, progress: .fresh(start: start), today: today)
        XCTAssertEqual(plan.phase, .script)
        XCTAssertEqual(plan.items.filter { $0.kind == .phrase }.count, 4)
        XCTAssertEqual(plan.items.filter { $0.kind == .consonant }.count, 4)
        XCTAssertEqual(catalog.consonant(plan.items.first { $0.kind == .consonant }?.id ?? "")?.symbol, "ก")
    }

    func testReviewComesBackAndStreakGrows() throws {
        let catalog = try ContentLoader.load(from: contentDirectory())
        let start = StudyPlan.defaultStart
        var progress = LearningProgress.fresh(start: start)
        let plan = StudySession.planToday(catalog: catalog, progress: progress, today: start)
        var session = StudySession.start(plan)
        let firstID = try XCTUnwrap(session.current?.id)
        session.grade(.good, progress: &progress)
        XCTAssertEqual(progress.cards[firstID]?.due, start.adding(days: 1))
        XCTAssertEqual(progress.streak, 0, "中途退出不记连续天数")

        while !session.isFinished {
            session.grade(.good, progress: &progress)
        }
        XCTAssertEqual(progress.streak, 1)
        XCTAssertNil(progress.resume)

        let tomorrow = start.adding(days: 1)
        let next = StudySession.planToday(catalog: catalog, progress: progress, today: tomorrow)
        XCTAssertTrue(next.items.contains { $0.id == firstID })
        XCTAssertGreaterThan(next.reviewCount, 0)

        var again = StudySession.start(next)
        let before = again.items.count
        let reviewedID = try XCTUnwrap(again.current?.id)
        again.grade(.again, progress: &progress)
        XCTAssertGreaterThan(again.items.count, before)
        XCTAssertEqual(progress.cards[reviewedID]?.due, tomorrow.adding(days: 1))
    }

    func testMissedDayResetsStreak() {
        var progress = LearningProgress.fresh()
        let start = progress.startDate
        progress.completeSession(on: start)
        progress.completeSession(on: start.adding(days: 2))
        XCTAssertEqual(progress.streak, 1)
        progress.completeSession(on: start.adding(days: 3))
        XCTAssertEqual(progress.streak, 2)
        progress.completeSession(on: start.adding(days: 3))
        XCTAssertEqual(progress.streak, 2)
    }
}

final class ToneQuizTests: XCTestCase {
    func testQuestionUsesTheItemTone() throws {
        let catalog = try ContentLoader.load(from: contentDirectory())
        var rng = SplitMix64(seed: 42)
        let question = try XCTUnwrap(ToneQuiz.question(in: catalog.minimalSets, rng: &rng))
        XCTAssertEqual(question.choices, Tone.allCases)
        let match = catalog.minimalSets
            .flatMap(\.items)
            .first { $0.thai == question.thai }
        XCTAssertEqual(match?.tone, question.answer)
        XCTAssertEqual(RomanTone.tone(in: question.roman), question.answer)
    }

    func testSameSeedSameQuestion() throws {
        let catalog = try ContentLoader.load(from: contentDirectory())
        var first = SplitMix64(seed: 7)
        var second = SplitMix64(seed: 7)
        let a = ToneQuiz.question(in: catalog.minimalSets, rng: &first)
        let b = ToneQuiz.question(in: catalog.minimalSets, rng: &second)
        XCTAssertEqual(a, b)
    }
}

private func contentDirectory() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Content")
}
