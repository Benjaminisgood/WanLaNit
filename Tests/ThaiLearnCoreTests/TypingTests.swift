import XCTest
import ThaiLearnCore

final class TypingTests: XCTestCase {
    func testEveryPrintableKeyHasBothLayers() {
        let expected: [(String, String, String)] = [
            ("`", "_", "%"),
            ("1", "ๅ", "+"),
            ("2", "/", "๑"),
            ("3", "-", "๒"),
            ("4", "ภ", "๓"),
            ("5", "ถ", "๔"),
            ("6", "ุ", "ู"),
            ("7", "ึ", "฿"),
            ("8", "ค", "๕"),
            ("9", "ต", "๖"),
            ("0", "จ", "๗"),
            ("-", "ข", "๘"),
            ("=", "ช", "๙"),
            ("q", "ๆ", "๐"),
            ("w", "ไ", "\""),
            ("e", "ำ", "ฎ"),
            ("r", "พ", "ฑ"),
            ("t", "ะ", "ธ"),
            ("y", "ั", "ํ"),
            ("u", "ี", "๊"),
            ("i", "ร", "ณ"),
            ("o", "น", "ฯ"),
            ("p", "ย", "ญ"),
            ("[", "บ", "ฐ"),
            ("]", "ล", ","),
            ("\\", "ฃ", "ฅ"),
            ("a", "ฟ", "ฤ"),
            ("s", "ห", "ฆ"),
            ("d", "ก", "ฏ"),
            ("f", "ด", "โ"),
            ("g", "เ", "ฌ"),
            ("h", "้", "็"),
            ("j", "่", "๋"),
            ("k", "า", "ษ"),
            ("l", "ส", "ศ"),
            (";", "ว", "ซ"),
            ("'", "ง", "."),
            ("z", "ผ", "("),
            ("x", "ป", ")"),
            ("c", "แ", "ฉ"),
            ("v", "อ", "ฮ"),
            ("b", "ิ", "ฺ"),
            ("n", "ื", "์"),
            ("m", "ท", "?"),
            (",", "ม", "ฒ"),
            (".", "ใ", "ฬ"),
            ("/", "ฝ", "ฦ")
        ]
        XCTAssertEqual(KedmaneeKeyboard.keys.count, expected.count)
        for item in expected {
            let key = KedmaneeKeyboard.key(item.0)
            XCTAssertEqual(key?.plain, item.1, item.0)
            XCTAssertEqual(key?.shifted, item.2, item.0)
            XCTAssertEqual(TypingCompare.scalars(in: item.1).count, 1, item.0)
            XCTAssertEqual(TypingCompare.scalars(in: item.2).count, 1, item.0)
        }
        XCTAssertEqual(KedmaneeKeyboard.key("f")?.homeBump, true)
        XCTAssertEqual(KedmaneeKeyboard.key("j")?.homeBump, true)
        XCTAssertEqual(KedmaneeKeyboard.key("a")?.finger, .leftPinky)
        XCTAssertEqual(KedmaneeKeyboard.key("j")?.finger, .rightIndex)
        XCTAssertEqual(KedmaneeKeyboard.producer(of: "่")?.key.usPlain, "j")
        XCTAssertEqual(KedmaneeKeyboard.producer(of: "โ")?.shifted, true)
    }

    func testQWERTYFallbackMapsPhysicalKeys() {
        XCTAssertEqual(TypingInput.thai(fromQWERTY: "asdf"), "ฟหกด")
        XCTAssertEqual(TypingInput.thai(fromQWERTY: "jkl;"), "่าสว")
        XCTAssertEqual(TypingInput.thai(fromQWERTY: "ASDF"), "ฤฆฏโ")
        XCTAssertEqual(TypingInput.thai(fromQWERTY: "4$"), "ภ๓")
        XCTAssertEqual(TypingInput.thai(fromQWERTY: "ไป"), "ไป")
        XCTAssertEqual(TypingInput.thai(fromQWERTY: "M"), "?")
        XCTAssertEqual(TypingInput.thai(fromQWERTY: "?"), "ฦ")
        let plains = Set(KedmaneeKeyboard.keys.map(\.usPlain))
        let shifts = Set(KedmaneeKeyboard.keys.map(\.usShift))
        XCTAssertEqual(plains.count, KedmaneeKeyboard.keys.count)
        XCTAssertEqual(shifts.count, KedmaneeKeyboard.keys.count)
        for item in KedmaneeKeyboard.keys {
            XCTAssertEqual(TypingInput.thai(fromQWERTY: item.usPlain), item.plain)
            XCTAssertEqual(TypingInput.thai(fromQWERTY: item.usShift), item.shifted, item.usPlain)
        }
    }

    func testComparisonKeepsToneMarksSeparate() {
        let partial = TypingCompare.diff(expected: "ก่", typed: "ก")
        XCTAssertEqual(partial.marks.map(\.status), [.correct, .pending])
        let wrong = TypingCompare.diff(expected: "ก่", typed: "กา")
        XCTAssertEqual(wrong.marks.map(\.status), [.correct, .wrong])
        XCTAssertFalse(wrong.finished)
        let done = TypingCompare.diff(expected: "ก่า", typed: "ก่า")
        XCTAssertTrue(done.finished)
        XCTAssertEqual(done.accuracy, 1)
        let score = TypingMetrics.score(correct: 10, wrong: 0, seconds: 60)
        XCTAssertEqual(score.cpm, 10, accuracy: 0.001)
        XCTAssertEqual(score.wpm, 2, accuracy: 0.001)
    }

    func testLessonsFollowTheKedmaneeOrder() throws {
        let catalog = try ContentLoader.load(from: typingContentRoot())
        let lessons = TypingCourse.lessons(in: catalog)
        XCTAssertEqual(lessons.map(\.id), [
            "home-left", "home-right", "home-rest", "upper", "lower",
            "shift", "marks", "syllables", "words", "phrases"
        ])
        let left = try XCTUnwrap(lessons.first { $0.id == "home-left" })
        let allowed = Set(TypingCourse.homeLeft + [" "])
        XCTAssertTrue(TypingCompare.scalars(in: left.text).allSatisfy { allowed.contains($0) })
        let right = try XCTUnwrap(lessons.first { $0.id == "home-right" })
        XCTAssertTrue(right.text.contains("่"))
        XCTAssertTrue(right.text.contains("า"))
        let words = try XCTUnwrap(lessons.first { $0.id == "words" })
        XCTAssertTrue(words.text.contains("กิน"))
        let phrases = try XCTUnwrap(lessons.first { $0.id == "phrases" })
        XCTAssertFalse(phrases.text.isEmpty)

        var progress = TypingProgress()
        progress.misses["ห"] = 4
        progress.misses["ก"] = 2
        let drill = TypingCourse.weakDrill(from: progress)
        XCTAssertTrue(drill.text.contains("ห"))
        XCTAssertEqual(drill.id, "weak")

        let day = CivilDay(year: 2026, month: 10, day: 3)
        var learning = LearningProgress.fresh(start: day)
        let score = TypingMetrics.score(correct: 4, wrong: 0, seconds: 30)
        learning.recordTyping(lesson: "home-left", score: score, expected: "ฟหกด", typed: "ฟหกด", on: day)
        XCTAssertEqual(learning.typing.best["home-left"]?.cpm ?? 0, score.cpm, accuracy: 0.01)
        XCTAssertGreaterThan(learning.typing.seconds(on: day), 0)
        XCTAssertEqual(learning.typing.hits["ฟ"], 1)
    }
}

final class PassageTests: XCTestCase {
    func testGradedPassagesAndScores() throws {
        let catalog = try ContentLoader.load(from: typingContentRoot())
        XCTAssertGreaterThanOrEqual(catalog.passages.count, 30)
        for level in 1...4 {
            XCTAssertGreaterThanOrEqual(catalog.passages.filter { $0.level == level }.count, 6)
        }
        let topics = Set(catalog.passages.map(\.topic))
        XCTAssertEqual(topics, Set(["日常生活", "食物", "旅行", "交朋友", "泰国文化"]))
        let first = try XCTUnwrap(catalog.passages.first { $0.level == 1 })
        XCTAssertTrue((2...3).contains(first.sentences.count))
        XCTAssertFalse(first.chinese.isEmpty)
        XCTAssertFalse(first.glosses.isEmpty)
        XCTAssertTrue((3...4).contains(first.questions.count))
        let longest = catalog.passages.filter { $0.level == 4 }.map { $0.thai.unicodeScalars.count }.max() ?? 0
        XCTAssertGreaterThanOrEqual(longest, 80)

        let day = CivilDay(year: 2026, month: 10, day: 3)
        var progress = LearningProgress.fresh(start: day)
        progress.recordPassageRead(first.id, on: day)
        progress.recordPassageQuiz(id: first.id, correct: 2, asked: 3)
        progress.recordPassageQuiz(id: first.id, correct: 1, asked: 3)
        progress.recordPassageDictation(id: first.id, completed: 1)
        XCTAssertEqual(progress.passagesRead(on: day), 1)
        XCTAssertEqual(progress.passageLog[first.id]?.correct, 2)
        XCTAssertEqual(progress.passageLog[first.id]?.dictated, 1)
        let again = try JSONDecoder().decode(LearningProgress.self, from: JSONEncoder().encode(progress))
        XCTAssertEqual(again.passageLog[first.id]?.readOn, day.iso)
    }
}

private func typingContentRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Content")
}
