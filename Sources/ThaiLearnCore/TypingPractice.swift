import Foundation

public enum TypingMark: String, Codable, Sendable {
    case pending
    case correct
    case wrong
}

public struct ScalarMark: Equatable, Sendable {
    public var expected: String
    public var typed: String?
    public var status: TypingMark

    public init(expected: String, typed: String?, status: TypingMark) {
        self.expected = expected
        self.typed = typed
        self.status = status
    }
}

public struct TypingDiff: Equatable, Sendable {
    public var marks: [ScalarMark]
    public var correct: Int
    public var wrong: Int
    public var pending: Int
    public var extra: Int
    public var finished: Bool
    public var accuracy: Double

    public init(
        marks: [ScalarMark],
        correct: Int,
        wrong: Int,
        pending: Int,
        extra: Int,
        finished: Bool,
        accuracy: Double
    ) {
        self.marks = marks
        self.correct = correct
        self.wrong = wrong
        self.pending = pending
        self.extra = extra
        self.finished = finished
        self.accuracy = accuracy
    }

    /// The next scalar the learner should type. A wrong cell means backspace first.
    public var focus: ScalarMark? {
        marks.first { $0.status != .correct }
    }
}

public enum TypingCompare {
    public static func scalars(in text: String) -> [String] {
        text.unicodeScalars.map(String.init)
    }

    /// Index-by-index compare. Combining vowels and tone marks are their own scalars,
    /// so each keystroke is graded on its own.
    public static func diff(expected: String, typed: String) -> TypingDiff {
        let want = scalars(in: expected)
        let got = scalars(in: typed)
        var marks: [ScalarMark] = []
        var correct = 0
        var wrong = 0
        var pending = 0
        for index in want.indices {
            if index < got.count {
                let typedScalar = got[index]
                if typedScalar == want[index] {
                    correct += 1
                    marks.append(ScalarMark(expected: want[index], typed: typedScalar, status: .correct))
                } else {
                    wrong += 1
                    marks.append(ScalarMark(expected: want[index], typed: typedScalar, status: .wrong))
                }
            } else {
                pending += 1
                marks.append(ScalarMark(expected: want[index], typed: nil, status: .pending))
            }
        }
        let extra = max(0, got.count - want.count)
        wrong += extra
        let attempts = correct + wrong
        let accuracy = attempts == 0 ? 0 : Double(correct) / Double(attempts)
        let finished = pending == 0 && wrong == 0 && extra == 0 && !want.isEmpty
        return TypingDiff(
            marks: marks,
            correct: correct,
            wrong: wrong,
            pending: pending,
            extra: extra,
            finished: finished,
            accuracy: accuracy
        )
    }
}

public struct TypingScore: Equatable, Sendable {
    public var cpm: Double
    public var wpm: Double
    public var accuracy: Double
    public var seconds: Double
    public var correct: Int
    public var wrong: Int

    public init(cpm: Double, wpm: Double, accuracy: Double, seconds: Double, correct: Int, wrong: Int) {
        self.cpm = cpm
        self.wpm = wpm
        self.accuracy = accuracy
        self.seconds = seconds
        self.correct = correct
        self.wrong = wrong
    }
}

public enum TypingMetrics {
    /// CPM is correct Unicode scalars per minute. WPM counts five scalars as one word.
    public static func score(correct: Int, wrong: Int, seconds: Double) -> TypingScore {
        let minutes = max(seconds, 0.5) / 60
        let cpm = Double(correct) / minutes
        let attempts = correct + wrong
        let accuracy = attempts == 0 ? 0 : Double(correct) / Double(attempts)
        return TypingScore(
            cpm: cpm,
            wpm: cpm / 5,
            accuracy: accuracy,
            seconds: seconds,
            correct: correct,
            wrong: wrong
        )
    }
}

public struct LessonBest: Codable, Equatable, Sendable {
    public var cpm: Double
    public var accuracy: Double

    public init(cpm: Double, accuracy: Double) {
        self.cpm = cpm
        self.accuracy = accuracy
    }
}

public struct TypingProgress: Codable, Equatable, Sendable {
    public var best: [String: LessonBest]
    public var misses: [String: Int]
    public var hits: [String: Int]
    public var qwertyFallback: Bool
    public var practicedSeconds: Double
    public var daySeconds: [String: Double]

    public init(
        best: [String: LessonBest] = [:],
        misses: [String: Int] = [:],
        hits: [String: Int] = [:],
        qwertyFallback: Bool = false,
        practicedSeconds: Double = 0,
        daySeconds: [String: Double] = [:]
    ) {
        self.best = best
        self.misses = misses
        self.hits = hits
        self.qwertyFallback = qwertyFallback
        self.practicedSeconds = practicedSeconds
        self.daySeconds = daySeconds
    }

    public func seconds(on day: CivilDay) -> Double {
        daySeconds[day.iso] ?? 0
    }

    public var weakKeys: [(key: String, misses: Int)] {
        misses
            .filter { $0.key != " " && $0.key != "\n" && $0.value > 0 }
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key < rhs.key
            }
            .map { (key: $0.key, misses: $0.value) }
    }
}

public enum TypingStage: String, Codable, CaseIterable, Sendable {
    case homeLeft
    case homeRight
    case homeRest
    case upper
    case lower
    case shift
    case marks
    case syllables
    case words
    case phrases

    public var title: String {
        switch self {
        case .homeLeft: return "本行左手"
        case .homeRight: return "本行右手"
        case .homeRest: return "本行其余"
        case .upper: return "上行"
        case .lower: return "下行"
        case .shift: return "Shift 档"
        case .marks: return "声调符号和元音"
        case .syllables: return "常见音节"
        case .words: return "词"
        case .phrases: return "句子"
        }
    }
}

public struct TypingLesson: Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var detail: String
    public var stage: TypingStage
    public var text: String

    public init(id: String, title: String, detail: String, stage: TypingStage, text: String) {
        self.id = id
        self.title = title
        self.detail = detail
        self.stage = stage
        self.text = text
    }
}

public enum TypingCourse {
    public static let homeLeft = ["ฟ", "ห", "ก", "ด"]
    public static let homeRight = ["่", "า", "ส", "ว"]
    public static let homeRest = ["เ", "้", "ง"]

    public static func lessons(in catalog: Catalog) -> [TypingLesson] {
        [
            lesson("home-left", .homeLeft, "左手本行：ฟ ห ก ด", line(homeLeft)),
            lesson("home-right", .homeRight, "右手本行：่ า ส ว。่ 和 า 要分开打。", line(homeRight)),
            lesson("home-rest", .homeRest, "本行剩下的 เ ้ ง", line(homeRest + homeLeft)),
            lesson("upper", .upper, "上行：ๆ ไ ำ พ ะ ั ี ร น ย บ ล", line(upperScalars)),
            lesson("lower", .lower, "下行：ผ ป แ อ ิ ื ท ม ใ ฝ", line(lowerScalars)),
            lesson("shift", .shift, "按着 Shift 打这些不常用的字和符号。", shiftLine),
            lesson("marks", .marks, "先打辅音，再打头上或脚下的元音和声调。", marksLine),
            lesson("syllables", .syllables, "把辅音和元音连成音节。", syllablesLine),
            lesson("words", .words, "词表里的短词。", wordLine(in: catalog)),
            lesson("phrases", .phrases, "课里的短句。", phraseLine(in: catalog))
        ]
    }

    public static func weakDrill(from progress: TypingProgress) -> TypingLesson {
        let keys = progress.weakKeys.prefix(4).map(\.key)
        let source = keys.count >= 2 ? Array(keys) : homeLeft
        return TypingLesson(
            id: "weak",
            title: "薄弱键",
            detail: "多错的键：\(source.joined(separator: " "))",
            stage: .homeLeft,
            text: line(source)
        )
    }

    private static var upperScalars: [String] {
        KedmaneeKeyboard.keys(in: .upper).map(\.plain).filter { $0 != "ฃ" }
    }

    private static var lowerScalars: [String] {
        KedmaneeKeyboard.keys(in: .lower).map(\.plain)
    }

    private static let shiftLine = "ฤ ฆ ฏ โ ็ ๋ ษ ศ ซ ๐ ฎ ฑ ธ"
    // Tone mark before sara aa, same order as the word list (ข้าว is ข + ้ + า + ว).
    private static let marksLine = "\u{0E01}\u{0E32} \u{0E01}\u{0E48}\u{0E32} \u{0E01}\u{0E49}\u{0E32} \u{0E01}\u{0E4A}\u{0E32} \u{0E01}\u{0E4B}\u{0E32} \u{0E01}\u{0E34} \u{0E01}\u{0E35} \u{0E01}\u{0E38} \u{0E01}\u{0E39} \u{0E01}\u{0E47} \u{0E40}\u{0E01} \u{0E41}\u{0E01}"
    private static let syllablesLine = "กา นา มา ดี ไป ได้ ไม่ กิน น้ำ ข้าว บ้าน"

    private static func lesson(_ id: String, _ stage: TypingStage, _ detail: String, _ text: String) -> TypingLesson {
        TypingLesson(id: id, title: stage.title, detail: detail, stage: stage, text: text)
    }

    private static func line(_ parts: [String]) -> String {
        let forward = parts.joined()
        let backward = parts.reversed().joined()
        let pairs = stride(from: 0, to: parts.count, by: 2).map { index -> String in
            let end = min(index + 2, parts.count)
            return parts[index..<end].joined()
        }.joined(separator: " ")
        return "\(forward) \(backward) \(pairs) \(forward)"
    }

    private static func wordLine(in catalog: Catalog) -> String {
        let words = catalog.words
            .filter { $0.band == 1 && (2...8).contains($0.thai.unicodeScalars.count) }
            .sorted { $0.order < $1.order }
            .prefix(10)
            .map(\.thai)
        return words.joined(separator: " ")
    }

    private static func phraseLine(in catalog: Catalog) -> String {
        let lines = catalog.phrases
            .sorted { $0.order < $1.order }
            .map(\.thai)
            .filter { (6...36).contains($0.unicodeScalars.count) }
            .prefix(3)
        return lines.joined(separator: " ")
    }
}

extension LearningProgress {
    public mutating func recordTyping(
        lesson id: String,
        score: TypingScore,
        expected: String,
        typed: String,
        on day: CivilDay
    ) {
        let diff = TypingCompare.diff(expected: expected, typed: typed)
        for mark in diff.marks {
            switch mark.status {
            case .correct:
                typing.hits[mark.expected, default: 0] += 1
            case .wrong:
                typing.misses[mark.expected, default: 0] += 1
            case .pending:
                break
            }
        }
        typing.practicedSeconds += max(0, score.seconds)
        typing.daySeconds[day.iso, default: 0] += max(0, score.seconds)
        if diff.finished, score.accuracy >= 0.9 {
            let previous = typing.best[id]
            if previous == nil || score.cpm > previous?.cpm ?? 0 {
                typing.best[id] = LessonBest(cpm: score.cpm, accuracy: score.accuracy)
            }
        }
    }

    public mutating func setTypingFallback(_ enabled: Bool) {
        typing.qwertyFallback = enabled
    }
}
