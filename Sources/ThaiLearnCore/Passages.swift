import Foundation

public struct PassageGloss: Codable, Equatable, Sendable {
    public var thai: String
    public var romanization: String
    public var meaning: String

    public init(thai: String, romanization: String, meaning: String) {
        self.thai = thai
        self.romanization = romanization
        self.meaning = meaning
    }
}

public struct PassageQuestion: Codable, Equatable, Sendable {
    public var prompt: String
    public var choices: [String]
    public var answer: Int

    public init(prompt: String, choices: [String], answer: Int) {
        self.prompt = prompt
        self.choices = choices
        self.answer = answer
    }
}

public struct ReadingPassage: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var level: Int
    public var topic: String
    public var title: String
    public var thai: String
    public var chinese: String
    public var glosses: [PassageGloss]
    public var questions: [PassageQuestion]

    public init(
        id: String,
        level: Int,
        topic: String,
        title: String,
        thai: String,
        chinese: String,
        glosses: [PassageGloss],
        questions: [PassageQuestion]
    ) {
        self.id = id
        self.level = level
        self.topic = topic
        self.title = title
        self.thai = thai
        self.chinese = chinese
        self.glosses = glosses
        self.questions = questions
    }

    public var sentences: [String] { ThaiSentences.split(thai) }

    /// Sentences in one paragraph for the reading view.
    public var paragraph: String { sentences.joined(separator: " ") }
}

public enum ThaiSentences {
    public static func split(_ text: String) -> [String] {
        var chunks: [String] = []
        var current = ""
        for scalar in text.unicodeScalars {
            let piece = String(scalar)
            if piece == "\n" || piece == "\r" || "。！？!?".contains(piece) {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { chunks.append(trimmed) }
                current = ""
            } else {
                current.unicodeScalars.append(scalar)
            }
        }
        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { chunks.append(tail) }
        return chunks
    }
}

public struct PassageLog: Codable, Equatable, Sendable {
    public var read: Bool
    public var readOn: String?
    public var correct: Int
    public var asked: Int
    public var dictated: Int

    public init(
        read: Bool = false,
        readOn: String? = nil,
        correct: Int = 0,
        asked: Int = 0,
        dictated: Int = 0
    ) {
        self.read = read
        self.readOn = readOn
        self.correct = correct
        self.asked = asked
        self.dictated = dictated
    }
}

extension LearningProgress {
    public mutating func recordPassageRead(_ id: String, on day: CivilDay) {
        var log = passageLog[id] ?? PassageLog()
        log.read = true
        log.readOn = day.iso
        passageLog[id] = log
    }

    public mutating func recordPassageQuiz(id: String, correct: Int, asked: Int) {
        var log = passageLog[id] ?? PassageLog()
        log.read = true
        if asked > 0, correct > log.correct || log.asked == 0 {
            log.correct = correct
            log.asked = asked
        }
        passageLog[id] = log
    }

    public mutating func recordPassageDictation(id: String, completed: Int) {
        var log = passageLog[id] ?? PassageLog()
        log.read = true
        log.dictated = max(log.dictated, completed)
        passageLog[id] = log
    }

    public func passagesRead(on day: CivilDay) -> Int {
        passageLog.values.filter { $0.readOn == day.iso }.count
    }
}
