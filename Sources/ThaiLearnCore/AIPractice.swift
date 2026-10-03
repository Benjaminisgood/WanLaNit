import Foundation

public enum SpeakMark: String, Codable, Equatable, Sendable {
    case match
    case tone
    case wrong
    case missing
    case extra
}

public struct SpeakPiece: Equatable, Sendable {
    public var text: String
    public var heard: String?
    public var status: SpeakMark

    public init(text: String, heard: String? = nil, status: SpeakMark) {
        self.text = text
        self.heard = heard
        self.status = status
    }
}

public struct SpeakScore: Equatable, Sendable {
    public var score: Int
    public var pieces: [SpeakPiece]
    /// Always says the score comes from the transcript, not from the audio itself.
    public var note: String

    public init(score: Int, pieces: [SpeakPiece], note: String) {
        self.score = score
        self.pieces = pieces
        self.note = note
    }

    public static let honesty = "分数来自转写和原句的对齐，不是声学分析。声调听起来对不对，这里看不出来。"
}

public enum SpeakAlign {
    public static func score(target: String, heard: String, dictionary: [String]) -> SpeakScore {
        let left = words(in: target, dictionary: dictionary)
        let right = words(in: heard, dictionary: dictionary)
        if left.isEmpty && right.isEmpty {
            return SpeakScore(score: 0, pieces: [], note: SpeakScore.honesty)
        }
        let (cost, pieces) = align(left, right)
        let scale = Double(max(left.count, right.count, 1))
        let score = Int((100 * (1 - min(cost, scale) / scale)).rounded())
        return SpeakScore(score: max(0, min(100, score)), pieces: pieces, note: SpeakScore.honesty)
    }

    /// Dictionary hits win, so Linux and macOS tests agree. Otherwise NLTokenizer (on Apple) or graphemes.
    public static func words(in text: String, dictionary: [String]) -> [String] {
        let dict = ThaiSegmenter.dictionaryTokens(in: text, dictionary: dictionary)
            .filter(\.isWord)
            .map(\.text)
        if !dictionary.isEmpty, dict.contains(where: { dictionary.contains($0) }) {
            return dict
        }
        let natural = ThaiSegmenter.tokens(in: text, dictionary: dictionary)
            .filter(\.isWord)
            .map(\.text)
        return natural.isEmpty ? dict : natural
    }

    private static func align(_ target: [String], _ heard: [String]) -> (Double, [SpeakPiece]) {
        let rows = target.count + 1
        let columns = heard.count + 1
        var cost = Array(repeating: Array(repeating: 0.0, count: columns), count: rows)
        var step = Array(repeating: Array(repeating: 0, count: columns), count: rows)
        for index in 1..<rows {
            cost[index][0] = Double(index)
            step[index][0] = 1
        }
        for index in 1..<columns {
            cost[0][index] = Double(index)
            step[0][index] = 2
        }
        for i in 1..<rows {
            for j in 1..<columns {
                let pair = pairCost(target[i - 1], heard[j - 1])
                let sub = cost[i - 1][j - 1] + pair.cost
                let delete = cost[i - 1][j] + 1
                let insert = cost[i][j - 1] + 1
                if sub <= delete && sub <= insert {
                    cost[i][j] = sub
                    step[i][j] = pair.kind
                } else if delete <= insert {
                    cost[i][j] = delete
                    step[i][j] = 1
                } else {
                    cost[i][j] = insert
                    step[i][j] = 2
                }
            }
        }
        var pieces: [SpeakPiece] = []
        var i = target.count
        var j = heard.count
        while i > 0 || j > 0 {
            let kind = step[i][j]
            if i > 0, j > 0, kind != 1 && kind != 2 {
                let status: SpeakMark = kind == 3 ? .tone : (kind == 4 ? .wrong : .match)
                pieces.append(SpeakPiece(text: target[i - 1], heard: heard[j - 1], status: status))
                i -= 1
                j -= 1
            } else if i > 0, kind == 1 || j == 0 {
                pieces.append(SpeakPiece(text: target[i - 1], status: .missing))
                i -= 1
            } else {
                pieces.append(SpeakPiece(text: heard[j - 1], heard: heard[j - 1], status: .extra))
                j -= 1
            }
        }
        return (cost[target.count][heard.count], pieces.reversed())
    }

    /// 0 match, 3 tone, 4 substitution, used only when both sides advance.
    private static func pairCost(_ left: String, _ right: String) -> (cost: Double, kind: Int) {
        if left == right { return (0, 0) }
        if fold(left) == fold(right) { return (0.35, 3) }
        return (1, 4)
    }

    private static func fold(_ text: String) -> String {
        String(text.unicodeScalars.filter { scalar in
            let value = scalar.value
            if (0x0E47...0x0E4E).contains(value) { return false }
            return true
        })
    }
}

public struct AIExercise: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var kind: Kind
    public var prompt: String
    public var thai: String
    public var chinese: String
    public var answer: String
    public var choices: [String]
    public var blank: String

    public enum Kind: String, Codable, CaseIterable, Sendable {
        case fillBlank
        case toThai
        case toChinese
        case listening
        case dialogue
    }

    public init(
        id: String,
        kind: Kind,
        prompt: String,
        thai: String = "",
        chinese: String = "",
        answer: String,
        choices: [String] = [],
        blank: String = ""
    ) {
        self.id = id
        self.kind = kind
        self.prompt = prompt
        self.thai = thai
        self.chinese = chinese
        self.answer = answer
        self.choices = choices
        self.blank = blank
    }
}

public struct AIExerciseBatch: Codable, Equatable, Sendable {
    public var exercises: [AIExercise]

    public init(exercises: [AIExercise]) {
        self.exercises = exercises
    }
}

public struct AICorrection: Codable, Equatable, Sendable {
    public var corrected: String
    public var romanization: String
    public var explanation: String
    public var score: Int

    public init(corrected: String, romanization: String, explanation: String, score: Int) {
        self.corrected = corrected
        self.romanization = romanization
        self.explanation = explanation
        self.score = score
    }
}

public enum AIJSON {
    public static func objectText(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            if let first = text.firstIndex(of: "\n") { text = String(text[text.index(after: first)...]) }
            if let fence = text.range(of: "```", options: .backwards) { text = String(text[..<fence.lowerBound]) }
        }
        if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") {
            text = String(text[start...end])
        } else if let start = text.firstIndex(of: "["), let end = text.lastIndex(of: "]") {
            text = String(text[start...end])
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func decode<T: Decodable>(_ raw: String, as type: T.Type) throws -> T {
        let data = Data(objectText(raw).utf8)
        return try JSONDecoder().decode(type, from: data)
    }
}

public enum AIExerciseService {
    public static func messages(words: [String], topic: String, level: String) -> [AIChatMessage] {
        let list = words.isEmpty ? "（还没有学过的词，用很常见的生活词）" : words.joined(separator: "、")
        let schema = """
        {"exercises":[{"id":"1","kind":"fillBlank|toThai|toChinese|listening|dialogue","prompt":"中文要求","thai":"泰文","chinese":"中文","answer":"标准答案","choices":[],"blank":"挖空的词"}]}
        """
        return [
            .system("""
            你给在学泰语的人出练习。难度：\(level)。话题：\(topic)。优先用这些已经学过的词：\(list)。
            出 4 到 5 题，种类要覆盖：填空 fillBlank、中译泰 toThai、泰译中 toChinese、听写 listening、小对话 dialogue。
            泰文要自然，声调符号要写对。dialogue 的 answer 是一句他可以回复的泰文。
            只输出 JSON，不要 Markdown。格式：\(schema)
            """),
            .user("出一组新题。")
        ]
    }

    public static func retryMessages(previous: String, issues: [String]) -> [AIChatMessage] {
        [
            .system("上次的 JSON 不合格：\(issues.joined(separator: "；"))。只重新输出合格的 JSON。"),
            .user(previous)
        ]
    }

    public static func decode(_ raw: String) throws -> AIExerciseBatch {
        if let batch = try? AIJSON.decode(raw, as: RawBatch.self) {
            return AIExerciseBatch(exercises: batch.exercises.enumerated().map { map($0.offset, $0.element) })
        }
        let rows = try AIJSON.decode(raw, as: [RawExercise].self)
        return AIExerciseBatch(exercises: rows.enumerated().map { map($0.offset, $0.element) })
    }

    public static func issues(_ batch: AIExerciseBatch) -> [String] {
        if batch.exercises.isEmpty { return ["没有题目"] }
        if batch.exercises.count > 8 { return ["题目太多"] }
        var found: [String] = []
        for exercise in batch.exercises {
            if exercise.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { found.append("\(exercise.id) 没有要求") }
            if exercise.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { found.append("\(exercise.id) 没有答案") }
            switch exercise.kind {
            case .fillBlank:
                if exercise.blank.isEmpty && !exercise.thai.contains("____") { found.append("\(exercise.id) 填空没有空") }
            case .toThai, .listening, .dialogue:
                if !containsThai(exercise.answer) && !containsThai(exercise.thai) { found.append("\(exercise.id) 没有泰文") }
            case .toChinese:
                if exercise.thai.isEmpty { found.append("\(exercise.id) 没有泰文") }
            }
        }
        return found
    }

    public static func generate(chat: ChatModel, words: [String], topic: String, level: String) async throws -> AIExerciseBatch {
        let first = try await chat.complete(messages: messages(words: words, topic: topic, level: level), jsonObject: true)
        if let batch = try? decode(first), issues(batch).isEmpty { return batch }
        let problems = (try? decode(first)).map(issues) ?? ["不是 JSON"]
        let second = try await chat.complete(messages: retryMessages(previous: first, issues: problems), jsonObject: true)
        let batch = try decode(second)
        let problems2 = issues(batch)
        if !problems2.isEmpty { throw AIClientError.decode }
        return batch
    }

    private struct RawBatch: Decodable {
        var exercises: [RawExercise]
    }

    private struct RawExercise: Decodable {
        var id: String?
        var kind: String?
        var type: String?
        var prompt: String?
        var thai: String?
        var chinese: String?
        var answer: String?
        var choices: [String]?
        var blank: String?
    }

    private static func map(_ index: Int, _ raw: RawExercise) -> AIExercise {
        let kindName = (raw.kind ?? raw.type ?? "").trimmingCharacters(in: .whitespaces)
        let kind = AIExercise.Kind(rawValue: kindName) ?? AIExercise.Kind(rawValue: normalized(kindName)) ?? .toThai
        return AIExercise(
            id: raw.id ?? "\(index + 1)",
            kind: kind,
            prompt: raw.prompt ?? "",
            thai: raw.thai ?? "",
            chinese: raw.chinese ?? "",
            answer: raw.answer ?? "",
            choices: raw.choices ?? [],
            blank: raw.blank ?? ""
        )
    }

    private static func normalized(_ name: String) -> String {
        switch name.lowercased() {
        case "fill", "fill_blank", "blank": return "fillBlank"
        case "to_thai", "zh-th": return "toThai"
        case "to_chinese", "th-zh": return "toChinese"
        case "listen", "dictation": return "listening"
        case "chat", "roleplay": return "dialogue"
        default: return name
        }
    }

    private static func containsThai(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x0E00...0x0E7F).contains($0.value) }
    }
}

public enum LocalExercises {
    public static func make(catalog: Catalog, progress: LearningProgress, topic: String) -> AIExerciseBatch {
        let words = LearnedWords.list(catalog: catalog, progress: progress, topic: topic, limit: 8)
        let phrases = catalog.phrases.sorted { $0.order < $1.order }
        let word = words.first
        let phrase = phrases.first { item in
            guard let word else { return item.thai.unicodeScalars.count <= 24 }
            return item.thai.contains(word.thai)
        } ?? phrases.first
        var exercises: [AIExercise] = []
        if let phrase, let word, phrase.thai.contains(word.thai) {
            exercises.append(AIExercise(
                id: "local-blank",
                kind: .fillBlank,
                prompt: "把空格填成泰文。",
                thai: phrase.thai.replacingOccurrences(of: word.thai, with: "____"),
                chinese: phrase.meaning,
                answer: word.thai,
                blank: word.thai
            ))
        }
        if let word {
            exercises.append(AIExercise(
                id: "local-th",
                kind: .toThai,
                prompt: "把这句中文写成泰文。",
                chinese: word.meaning,
                answer: word.thai
            ))
            exercises.append(AIExercise(
                id: "local-zh",
                kind: .toChinese,
                prompt: "这句泰文是什么意思？用中文写。",
                thai: word.thai,
                answer: word.meaning
            ))
        }
        if let phrase {
            exercises.append(AIExercise(
                id: "local-listen",
                kind: .listening,
                prompt: "听一遍，把听到的泰文打出来。",
                thai: phrase.thai,
                chinese: phrase.meaning,
                answer: phrase.thai
            ))
            exercises.append(AIExercise(
                id: "local-talk",
                kind: .dialogue,
                prompt: "朋友说：\(phrase.meaning)。用泰文回一句。",
                thai: phrase.thai,
                chinese: phrase.meaning,
                answer: phrase.thai
            ))
        }
        return AIExerciseBatch(exercises: exercises)
    }
}

public enum LearnedWords {
    public static func list(catalog: Catalog, progress: LearningProgress, topic: String, limit: Int) -> [VocabWord] {
        let learned = catalog.words.filter { word in
            let card = progress.cards[word.id] ?? progress.cards["\(word.id)#production"]
            guard let card else { return false }
            return card.repetitions > 0 || card.stage == .review || card.stage == .learning
        }
        let pool = learned.isEmpty ? catalog.words.filter { $0.band == 1 } : learned
        let trimmed = topic.trimmingCharacters(in: .whitespaces)
        let matched = trimmed.isEmpty ? pool : pool.filter { $0.topic.contains(trimmed) || $0.meaning.contains(trimmed) }
        let chosen = (matched.isEmpty ? pool : matched).sorted { $0.order < $1.order }
        return Array(chosen.prefix(limit))
    }
}

public enum AIGrader {
    public static func messages(text: String) -> [AIChatMessage] {
        [
            .system("""
            把学习者的话改成自然的泰文。只输出 JSON：
            {"corrected":"泰文","romanization":"Paiboon 罗马音","explanation":"中文说明","score":80}
            score 是 0 到 100 的整数。这不是声学评分。explanation 用简体中文，点出用词或声调符号。
            """),
            .user(text)
        ]
    }

    public static func decode(_ raw: String) throws -> AICorrection {
        let item = try AIJSON.decode(raw, as: AICorrection.self)
        guard (0...100).contains(item.score), !item.corrected.isEmpty, !item.explanation.isEmpty else {
            throw AIClientError.decode
        }
        return item
    }

    public static func grade(chat: ChatModel, text: String) async throws -> AICorrection {
        let first = try await chat.complete(messages: messages(text: text), jsonObject: true)
        if let item = try? decode(first) { return item }
        let second = try await chat.complete(
            messages: [.system("上次不是合格 JSON。只输出 corrected、romanization、explanation、score。"), .user(first)],
            jsonObject: true
        )
        return try decode(second)
    }

    /// Offline hint: romanize the words that are already in the word list. Not a correction.
    public static func offline(text: String, catalog: Catalog) -> AICorrection {
        let tokens = ThaiSegmenter.dictionaryTokens(in: text, dictionary: catalog.words.map(\.thai)).filter(\.isWord)
        let known = tokens.compactMap { catalog.word(thai: $0.text) }
        let roman = known.map(\.romanization).joined(separator: " ")
        let score = tokens.isEmpty ? 0 : Int((100.0 * Double(known.count) / Double(tokens.count)).rounded())
        return AICorrection(
            corrected: text,
            romanization: roman.isEmpty ? "词表里还对不上" : roman,
            explanation: "没有云端批改。这里只标出词表里已有的词，不会改句子。",
            score: score
        )
    }
}

public enum AIPartner {
    public static func messages(history: [AIChatTurn], difficulty: String, hints: Bool) -> [AIChatMessage] {
        var messages = [
            AIChatMessage.system("""
            你是泰语对话伙伴，帮他练习和泰国人说话。难度：\(difficulty)。回复用短泰语。
            只输出 JSON：{"thai":"你说的泰文","chinese":"简体中文意思"}。
            \(hints ? "chinese 写清楚意思。" : "chinese 可以留空。")
            不要用英文，不要写钥匙或网址。
            """)
        ]
        for turn in history.suffix(12) {
            messages.append(AIChatMessage(role: turn.role == "assistant" ? "assistant" : "user", content: turn.thai))
        }
        if history.last?.role != "user" {
            messages.append(.user("สวัสดี"))
        }
        return messages
    }

    public static func decode(_ raw: String) -> (thai: String, chinese: String) {
        struct Reply: Decodable { var thai: String?; var chinese: String? }
        if let reply = try? AIJSON.decode(raw, as: Reply.self), let thai = reply.thai, !thai.isEmpty {
            return (thai, reply.chinese ?? "")
        }
        return (raw.trimmingCharacters(in: .whitespacesAndNewlines), "")
    }
}

public struct SpeakAttempt: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var target: String
    public var transcript: String
    public var score: Int
    public var on: String

    public init(id: String, target: String, transcript: String, score: Int, on: String) {
        self.id = id
        self.target = target
        self.transcript = transcript
        self.score = score
        self.on = on
    }
}

public struct AIChatTurn: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var role: String
    public var thai: String
    public var chinese: String

    public init(id: String, role: String, thai: String, chinese: String) {
        self.id = id
        self.role = role
        self.thai = thai
        self.chinese = chinese
    }
}

public struct AIUsage: Codable, Equatable, Sendable {
    public var dailyCap: Int
    public var requestsByDay: [String: Int]

    public init(dailyCap: Int = 40, requestsByDay: [String: Int] = [:]) {
        self.dailyCap = dailyCap
        self.requestsByDay = requestsByDay
    }

    public func count(on day: CivilDay) -> Int { requestsByDay[day.iso] ?? 0 }

    public func allows(_ day: CivilDay) -> Bool {
        if dailyCap <= 0 { return false }
        return count(on: day) < dailyCap
    }

    public mutating func record(on day: CivilDay) {
        requestsByDay[day.iso, default: 0] += 1
    }
}

public struct AISettings: Codable, Equatable, Sendable {
    public var useAIVoice: Bool
    public var voice: String
    public var rate: Double
    public var difficulty: String
    public var showHints: Bool
    public var usage: AIUsage
    public var attempts: [SpeakAttempt]
    public var dialogue: [AIChatTurn]

    public init(
        useAIVoice: Bool = false,
        voice: String = "nova",
        rate: Double = 0.82,
        difficulty: String = "入门",
        showHints: Bool = true,
        usage: AIUsage = AIUsage(),
        attempts: [SpeakAttempt] = [],
        dialogue: [AIChatTurn] = []
    ) {
        self.useAIVoice = useAIVoice
        self.voice = voice
        self.rate = rate
        self.difficulty = difficulty
        self.showHints = showHints
        self.usage = usage
        self.attempts = attempts
        self.dialogue = dialogue
    }
}

extension LearningProgress {
    public mutating func recordSpeakAttempt(_ attempt: SpeakAttempt) {
        ai.attempts.append(attempt)
        if ai.attempts.count > 40 { ai.attempts.removeFirst(ai.attempts.count - 40) }
    }

    public mutating func recordDialogue(_ turn: AIChatTurn) {
        ai.dialogue.append(turn)
        if ai.dialogue.count > 40 { ai.dialogue.removeFirst(ai.dialogue.count - 40) }
    }
}
