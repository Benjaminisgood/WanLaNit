import Foundation

public struct ScenarioGoal: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var chinese: String

    public init(id: String, chinese: String) {
        self.id = id
        self.chinese = chinese
    }
}

public struct ScenarioPhrase: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var thai: String
    public var female: String
    public var romanization: String
    public var meaning: String

    public init(id: String, thai: String, female: String, romanization: String, meaning: String) {
        self.id = id
        self.thai = thai
        self.female = female
        self.romanization = romanization
        self.meaning = meaning
    }
}

public struct ScenarioLine: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var speaker: String
    public var thai: String
    public var romanization: String
    public var meaning: String

    public init(id: String, speaker: String, thai: String, romanization: String, meaning: String) {
        self.id = id
        self.speaker = speaker
        self.thai = thai
        self.romanization = romanization
        self.meaning = meaning
    }
}

public struct ScenarioDialogue: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var lines: [ScenarioLine]

    public init(id: String, title: String, lines: [ScenarioLine]) {
        self.id = id
        self.title = title
        self.lines = lines
    }
}

public struct ScenarioChoice: Codable, Equatable, Sendable {
    public var thai: String
    public var meaning: String
    public var next: String
    public var goals: [String]

    public init(thai: String, meaning: String, next: String, goals: [String]) {
        self.thai = thai
        self.meaning = meaning
        self.next = next
        self.goals = goals
    }
}

public struct ScenarioNode: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var speaker: String
    public var thai: String
    public var romanization: String
    public var meaning: String
    public var choices: [ScenarioChoice]
    public var typed: [String]
    public var typedNext: String
    public var typedGoals: [String]
    public var end: Bool

    public init(
        id: String,
        speaker: String,
        thai: String,
        romanization: String,
        meaning: String,
        choices: [ScenarioChoice],
        typed: [String],
        typedNext: String,
        typedGoals: [String],
        end: Bool
    ) {
        self.id = id
        self.speaker = speaker
        self.thai = thai
        self.romanization = romanization
        self.meaning = meaning
        self.choices = choices
        self.typed = typed
        self.typedNext = typedNext
        self.typedGoals = typedGoals
        self.end = end
    }
}

public struct ScenarioPersona: Codable, Equatable, Sendable {
    public var name: String
    public var role: String
    public var brief: String
    public var turnLimit: Int

    public init(name: String, role: String, brief: String, turnLimit: Int) {
        self.name = name
        self.role = role
        self.brief = brief
        self.turnLimit = turnLimit
    }
}

public struct Scenario: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var setting: String
    public var order: Int
    public var goals: [ScenarioGoal]
    public var phrases: [ScenarioPhrase]
    public var dialogues: [ScenarioDialogue]
    public var questions: [PassageQuestion]
    public var script: [ScenarioNode]
    public var persona: ScenarioPersona

    public init(
        id: String,
        title: String,
        setting: String,
        order: Int,
        goals: [ScenarioGoal],
        phrases: [ScenarioPhrase],
        dialogues: [ScenarioDialogue],
        questions: [PassageQuestion],
        script: [ScenarioNode],
        persona: ScenarioPersona
    ) {
        self.id = id
        self.title = title
        self.setting = setting
        self.order = order
        self.goals = goals
        self.phrases = phrases
        self.dialogues = dialogues
        self.questions = questions
        self.script = script
        self.persona = persona
    }

    public func node(_ id: String) -> ScenarioNode? {
        script.first { $0.id == id }
    }
}

public struct ScenarioLog: Codable, Equatable, Sendable {
    public var quizCorrect: Int
    public var quizAsked: Int
    public var roleScore: Int?
    public var goalsMet: [String]

    public init(quizCorrect: Int = 0, quizAsked: Int = 0, roleScore: Int? = nil, goalsMet: [String] = []) {
        self.quizCorrect = quizCorrect
        self.quizAsked = quizAsked
        self.roleScore = roleScore
        self.goalsMet = goalsMet
    }
}

public struct CultureLog: Codable, Equatable, Sendable {
    public var read: Bool
    public var correct: Int
    public var asked: Int

    public init(read: Bool = false, correct: Int = 0, asked: Int = 0) {
        self.read = read
        self.correct = correct
        self.asked = asked
    }
}

public enum ScenarioMatch {
    /// True when the typed line is the candidate, contains it, or is close after spaces and particles are ignored.
    public static func matches(_ typed: String, candidates: [String]) -> Bool {
        let heard = normalize(typed)
        guard heard.count >= 2 else { return false }
        for candidate in candidates {
            let want = normalize(candidate)
            guard want.count >= 2 else { continue }
            if heard == want || heard.contains(want) || want.contains(heard) { return true }
            let score = SpeakAlign.score(target: want, heard: heard, dictionary: []).score
            if score >= 72 { return true }
        }
        return false
    }

    public static func normalize(_ text: String) -> String {
        var value = text
        for particle in ["ครับผม", "ครับ", "ค่ะ", "คะ", "นะครับ", "นะคะ", "นะ"] {
            value = value.replacingOccurrences(of: particle, with: "")
        }
        return value.unicodeScalars.filter { !$0.properties.isWhitespace && $0.value != 0x0E46 }.map(String.init).joined()
    }
}

public struct ScenarioTurn: Codable, Equatable, Identifiable, Sendable {
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

public struct ScenarioGoalMark: Codable, Equatable, Sendable {
    public var id: String
    public var done: Bool

    public init(id: String, done: Bool) {
        self.id = id
        self.done = done
    }
}

public struct ScenarioCorrection: Codable, Equatable, Sendable {
    public var corrected: String
    public var romanization: String
    public var note: String

    public init(corrected: String, romanization: String, note: String) {
        self.corrected = corrected
        self.romanization = romanization
        self.note = note
    }
}

public struct ScenarioCoachReply: Codable, Equatable, Sendable {
    public var thai: String
    public var chinese: String
    public var correction: ScenarioCorrection?
    public var goals: [ScenarioGoalMark]
    public var finished: Bool
    public var feedback: String
    public var review: [String]

    public init(
        thai: String,
        chinese: String,
        correction: ScenarioCorrection?,
        goals: [ScenarioGoalMark],
        finished: Bool,
        feedback: String,
        review: [String]
    ) {
        self.thai = thai
        self.chinese = chinese
        self.correction = correction
        self.goals = goals
        self.finished = finished
        self.feedback = feedback
        self.review = review
    }
}

public struct ScenarioCoachOutcome: Equatable, Sendable {
    public var reply: ScenarioCoachReply
    public var usedFallback: Bool

    public init(reply: ScenarioCoachReply, usedFallback: Bool) {
        self.reply = reply
        self.usedFallback = usedFallback
    }
}

public enum ScenarioCoach {
    public static func messages(scenario: Scenario, history: [ScenarioTurn]) -> [AIChatMessage] {
        let goals = scenario.goals.map { "- \($0.id): \($0.chinese)" }.joined(separator: "\n")
        let phrases = scenario.phrases.map { "- \($0.thai)（\($0.meaning)）" }.joined(separator: "\n")
        let past = history.map { "\($0.role == "user" ? "学习者" : "你"): \($0.thai)" }.joined(separator: "\n")
        let userTurns = history.filter { $0.role == "user" }.count
        let system = """
        你在扮演\(scenario.persona.name)，\(scenario.persona.role)。
        \(scenario.persona.brief)
        场景：\(scenario.setting)
        学习者是男性，自称 ผม，句尾用 ครับ。你用女生说法，句尾用 ค่ะ 或 คะ。
        目标：
        \(goals)
        可以自然用到的句子：
        \(phrases)
        已经进行了 \(userTurns) 轮学习者发言，上限是 \(scenario.persona.turnLimit) 轮。到上限必须结束。
        只输出一个 JSON 对象，不要 Markdown：
        {"thai":"你这句泰语","chinese":"这句的中文","correction":null,"goals":[{"id":"目标id","done":false}],"finished":false,"feedback":"","review":[]}
        correction 只有在学习者刚才那句泰语明显不通时才填 {"corrected":"改后的泰语","romanization":"Paiboon","note":"一句中文"}，否则 null。
        goals 覆盖全部目标 id。finished 为 true 时 feedback 用中文总结，review 给 2 到 4 条值得复习的泰语句子。
        不要跳出角色，不要用英语长段，不要索要私人联系方式以外的敏感信息。
        """
        return [.system(system), .user(past.isEmpty ? "学习者刚走到你面前。" : past)]
    }

    public static func issues(_ reply: ScenarioCoachReply, scenario: Scenario) -> [String] {
        var found: [String] = []
        if reply.thai.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            found.append("没有泰语")
        }
        let known = Set(scenario.goals.map(\.id))
        let marked = Set(reply.goals.map(\.id))
        if !known.isSubset(of: marked) && !marked.isSubset(of: known) && !marked.isEmpty {
            found.append("目标对不上")
        }
        if reply.finished && reply.feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            found.append("结束时没有中文反馈")
        }
        return found
    }

    public static func score(scenario: Scenario, marks: [ScenarioGoalMark]) -> Int {
        let total = max(scenario.goals.count, 1)
        let done = scenario.goals.filter { goal in
            marks.contains { $0.id == goal.id && $0.done }
        }.count
        return Int((100.0 * Double(done) / Double(total)).rounded())
    }

    public static func fallback(scenario: Scenario, history: [ScenarioTurn]) -> ScenarioCoachReply {
        let index = min(history.filter { $0.role != "user" }.count, max(scenario.script.count - 1, 0))
        let node = scenario.script.isEmpty ? nil : scenario.script[index]
        let userTurns = history.filter { $0.role == "user" }.count
        let finished = userTurns >= scenario.persona.turnLimit || node?.end == true
        return ScenarioCoachReply(
            thai: node?.thai ?? scenario.phrases.first?.thai ?? "สวัสดีครับ",
            chinese: node?.meaning ?? "你好",
            correction: nil,
            goals: scenario.goals.map { ScenarioGoalMark(id: $0.id, done: false) },
            finished: finished,
            feedback: finished ? "没有连上模型。这句来自写好的分支。可以改用选择题再走一遍。" : "没有连上模型，先接一句写好的话。",
            review: Array(scenario.phrases.prefix(3).map(\.thai))
        )
    }

    public static func reply(chat: ChatModel, scenario: Scenario, history: [ScenarioTurn]) async -> ScenarioCoachOutcome {
        let prompt = messages(scenario: scenario, history: history)
        var last = ""
        for _ in 0..<2 {
            do {
                last = try await chat.complete(messages: prompt, jsonObject: true)
                let decoded = try AIJSON.decode(last, as: ScenarioCoachReply.self)
                if issues(decoded, scenario: scenario).isEmpty {
                    return ScenarioCoachOutcome(reply: forceFinish(decoded, scenario: scenario, history: history), usedFallback: false)
                }
            } catch {
                continue
            }
        }
        return ScenarioCoachOutcome(reply: fallback(scenario: scenario, history: history), usedFallback: true)
    }

    private static func forceFinish(_ reply: ScenarioCoachReply, scenario: Scenario, history: [ScenarioTurn]) -> ScenarioCoachReply {
        let userTurns = history.filter { $0.role == "user" }.count
        guard userTurns >= scenario.persona.turnLimit, !reply.finished else { return reply }
        var copy = reply
        copy.finished = true
        if copy.feedback.isEmpty {
            copy.feedback = "这一轮到轮数了。看看哪些目标已经说到。"
        }
        return copy
    }
}

public enum ScenarioReview {
    public static func add(phrase: ScenarioPhrase, progress: inout LearningProgress, on day: CivilDay) {
        let key = "scenario:\(phrase.id)"
        if progress.cards[key] == nil {
            var card = CardState.fresh(on: day)
            card.stage = .new
            card.due = day
            progress.cards[key] = card
        }
        let note = ReaderNote(
            id: key,
            thai: phrase.thai,
            romanization: phrase.romanization,
            meaning: phrase.meaning,
            context: phrase.female
        )
        if let index = progress.readerNotes.firstIndex(where: { $0.id == key }) {
            progress.readerNotes[index] = note
        } else {
            progress.readerNotes.append(note)
        }
    }
}
