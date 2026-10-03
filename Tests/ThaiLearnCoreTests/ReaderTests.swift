import XCTest
import ThaiLearnCore

final class ReaderTests: XCTestCase {
    func testHTMLBecomesPlainText() {
        let html = """
        <html><head><title>ตลาด &amp; บ้าน</title>
        <style>p { color: red }</style></head>
        <body><script>var secret = 1</script>
        <p>กินข้าว<br>ที่บ้าน</p></body></html>
        """
        let plain = HTMLText.plainText(from: html)
        XCTAssertFalse(plain.contains("secret"))
        XCTAssertFalse(plain.contains("color"))
        XCTAssertFalse(plain.contains("<"))
        XCTAssertTrue(plain.contains("กินข้าว"))
        XCTAssertTrue(plain.contains("ที่บ้าน"))
        XCTAssertEqual(HTMLText.title(from: html), "ตลาด & บ้าน")
        XCTAssertNil(HTMLText.title(from: "<p>ไม่มี</p>"))
    }

    func testStartersSegmentIntoDictionaryWords() throws {
        let catalog = try ContentLoader.load(from: readerContentRoot())
        XCTAssertGreaterThanOrEqual(catalog.starters.count, 3)
        XCTAssertEqual(Set(catalog.starters.map(\.level)), Set([1, 2, 3]))
        let dictionary = catalog.words.map(\.thai)
        let morning = try XCTUnwrap(catalog.starters.first { $0.id == "starter-morning" })
        let tokens = ThaiSegmenter.dictionaryTokens(in: morning.body, dictionary: dictionary)
        XCTAssertEqual(
            tokens.map(\.text),
            ["วันนี้", "ฉัน", "ตื่น", "เช้า", "กินข้าว", "และ", "ดื่ม", "น้ำ", "ที่", "บ้าน", "แล้ว", "ไป", "โรงเรียน"]
        )
        XCTAssertTrue(tokens.allSatisfy(\.isWord))

        let rain = try XCTUnwrap(catalog.starters.first { $0.id == "starter-rain" })
        let rainTokens = ThaiSegmenter.dictionaryTokens(in: rain.body, dictionary: dictionary)
        XCTAssertTrue(rainTokens.contains { $0.text == "ลม" })
        XCTAssertTrue(rainTokens.contains { $0.text == "แรง" })
        XCTAssertTrue(rainTokens.contains { $0.text == "ข้าง" })
        XCTAssertTrue(rainTokens.contains { $0.text == "นอก" })
        let known = Set(dictionary)
        XCTAssertTrue(rainTokens.allSatisfy { known.contains($0.text) })
    }

    func testKnownAndIgnoredStickAndCoverageCountsThem() throws {
        let catalog = try ContentLoader.load(from: readerContentRoot())
        let day = CivilDay(year: 2026, month: 10, day: 3)
        var progress = LearningProgress.fresh(start: day)
        let text = "กินข้าวที่บ้าน"
        ReaderState.setMark(.known, level: 5, thai: "กินข้าว", progress: &progress)
        ReaderState.setMark(.ignored, level: 0, thai: "ที่", progress: &progress)
        var card = CardState.fresh(on: day)
        card.stage = .learning
        card.step = 0
        progress.cards[catalog.word(thai: "กินข้าว")!.id] = card

        XCTAssertEqual(ReaderState.display(thai: "กินข้าว", catalog: catalog, progress: progress).status, .known)
        XCTAssertEqual(ReaderState.display(thai: "ที่", catalog: catalog, progress: progress).status, .ignored)
        XCTAssertEqual(ReaderState.display(thai: "บ้าน", catalog: catalog, progress: progress).status, .new)

        let coverage = ReaderState.coverage(in: text, catalog: catalog, progress: progress)
        XCTAssertEqual(coverage.uniqueWords, 2)
        XCTAssertEqual(coverage.known, 1)
        XCTAssertEqual(coverage.fraction, 0.5)
    }

    func testAddToReviewCreatesADueCardAndKeepsTheSentence() throws {
        let catalog = try ContentLoader.load(from: readerContentRoot())
        let day = CivilDay(year: 2026, month: 10, day: 2)
        var progress = LearningProgress.fresh(start: day)
        let sentence = "วันนี้ฉันกินข้าว"
        ReaderState.addToReview(thai: "กิน", sentence: sentence, catalog: catalog, progress: &progress, on: day)
        let wordID = try XCTUnwrap(catalog.word(thai: "กิน")).id
        XCTAssertEqual(ReaderState.cardKey(for: "กิน", catalog: catalog), wordID)
        XCTAssertEqual(progress.cards[wordID]?.due, day)
        XCTAssertEqual(progress.readerNotes.first?.context, sentence)
        XCTAssertEqual(ReaderState.display(thai: "กิน", catalog: catalog, progress: progress).status, .learning)

        let madeUp = "ทดสอบอ่าน"
        ReaderState.addToReview(thai: madeUp, sentence: sentence, catalog: catalog, progress: &progress, on: day)
        XCTAssertEqual(ReaderState.cardKey(for: madeUp, catalog: catalog), "reader:\(madeUp)")
        XCTAssertNotNil(progress.cards["reader:\(madeUp)"])

        let plan = StudySession.planToday(catalog: catalog, progress: progress, today: day)
        XCTAssertTrue(plan.items.contains { $0.cardKey == wordID && $0.kind == .word })
        XCTAssertTrue(plan.items.contains { $0.cardKey == "reader:\(madeUp)" })
        XCTAssertGreaterThanOrEqual(plan.reviewCount, 2)
    }

    func testIgnoredStatusSurvivesAReviewSync() throws {
        let catalog = try ContentLoader.load(from: readerContentRoot())
        let day = CivilDay(year: 2026, month: 10, day: 3)
        var progress = LearningProgress.fresh(start: day)
        let word = try XCTUnwrap(catalog.word(thai: "น้ำ"))
        var card = CardState.fresh(on: day)
        card.stage = .review
        card.intervalDays = 21
        card.stability = 21
        progress.cards[word.id] = card
        let ref = StudyRef(id: word.id, kind: .word, template: .recognition)
        ReaderState.sync(ref, catalog: catalog, progress: &progress)
        XCTAssertEqual(progress.wordMemory[word.thai]?.status, .known)

        ReaderState.setMark(.ignored, level: 0, thai: word.thai, progress: &progress)
        ReaderState.sync(ref, catalog: catalog, progress: &progress)
        XCTAssertEqual(ReaderState.display(thai: word.thai, catalog: catalog, progress: progress).status, .ignored)
    }

    func testSentenceUsesTheSurroundingClause() {
        let tokens = ThaiSegmenter.dictionaryTokens(
            in: "กินข้าว。ไปบ้าน",
            dictionary: ["กินข้าว", "ไป", "บ้าน"]
        )
        let eat = try! XCTUnwrap(tokens.first { $0.text == "กินข้าว" })
        XCTAssertEqual(ReaderState.sentence(around: eat, in: tokens), "กินข้าว。")
        let go = try! XCTUnwrap(tokens.first { $0.text == "ไป" })
        XCTAssertEqual(ReaderState.sentence(around: go, in: tokens), "ไปบ้าน")
    }

    func testOldProgressGainsEmptyReaderFields() throws {
        let json = """
        {"cards":{"greet-hello":{"due":"2026-10-08","easeFactor":2.5,"intervalDays":6,"introducedOn":"2026-10-02","lapses":1,"lastReviewed":"2026-10-02","repetitions":2}},"dayLogs":[],"schema":1,"startDate":"2026-10-02","streak":3}
        """
        let progress = try JSONDecoder().decode(LearningProgress.self, from: Data(json.utf8))
        XCTAssertTrue(progress.wordMemory.isEmpty)
        XCTAssertTrue(progress.library.isEmpty)
        XCTAssertTrue(progress.readerNotes.isEmpty)
        XCTAssertEqual(progress.cards["greet-hello"]?.due.iso, "2026-10-08")
        XCTAssertEqual(progress.streak, 3)

        var roundTrip = progress
        roundTrip.library.append(ReaderDocument(id: "a", title: "标题", body: "ไป", source: "粘贴"))
        roundTrip.wordMemory["ไป"] = WordMemory(status: .learning, level: 2)
        let again = try JSONDecoder().decode(LearningProgress.self, from: JSONEncoder().encode(roundTrip))
        XCTAssertEqual(again.library, roundTrip.library)
        XCTAssertEqual(again.wordMemory["ไป"]?.level, 2)
    }
}

private func readerContentRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Content")
}
