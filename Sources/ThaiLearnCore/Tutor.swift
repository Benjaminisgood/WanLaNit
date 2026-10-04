import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Stored tutor state

public struct TutorNote: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var text: String
    public var on: String

    public init(id: String, text: String, on: String) {
        self.id = id
        self.text = text
        self.on = on
    }
}

public struct TutorMistake: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var thai: String
    public var expected: String
    public var heard: String
    public var note: String
    public var source: String
    public var on: String
    public var resolved: Bool

    public init(
        id: String,
        thai: String,
        expected: String,
        heard: String,
        note: String,
        source: String,
        on: String,
        resolved: Bool = false
    ) {
        self.id = id
        self.thai = thai
        self.expected = expected
        self.heard = heard
        self.note = note
        self.source = source
        self.on = on
        self.resolved = resolved
    }
}

public struct TutorChatTurn: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var role: String
    public var text: String
    public var on: String

    public init(id: String, role: String, text: String, on: String) {
        self.id = id
        self.role = role
        self.text = text
        self.on = on
    }
}

public struct TutorSessionRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var on: String
    public var summary: String
    public var score: Int
    public var minutes: Int
    public var homework: [String]

    public init(id: String, on: String, summary: String, score: Int, minutes: Int, homework: [String]) {
        self.id = id
        self.on = on
        self.summary = summary
        self.score = score
        self.minutes = minutes
        self.homework = homework
    }
}

public struct TutorWeekPlan: Codable, Equatable, Sendable {
    public var weekOf: String
    public var goals: [String]
    public var milestones: [String]
    public var note: String

    public init(weekOf: String, goals: [String], milestones: [String], note: String) {
        self.weekOf = weekOf
        self.goals = goals
        self.milestones = milestones
        self.note = note
    }
}

public struct TutorRecord: Codable, Equatable, Sendable {
    public var notes: [TutorNote]
    public var mistakes: [TutorMistake]
    public var sessions: [TutorSessionRecord]
    public var weekPlan: TutorWeekPlan?
    public var turns: [TutorChatTurn]
    public var summary: String
    public var minutesTarget: Int
    /// Empty follows the chat assignment. `qwen-plus` or `qwen-max` overrides the tutor only.
    public var model: String
    public var voiceAutoContinue: Bool
    public var requestCap: Int
    public var tokenCap: Int
    public var requestsByDay: [String: Int]
    public var tokensByDay: [String: Int]
    public var checkIns: [String]
    public var lessonCorrect: Int
    public var lessonAsked: Int
    public var homework: [String]

    public init(
        notes: [TutorNote] = [],
        mistakes: [TutorMistake] = [],
        sessions: [TutorSessionRecord] = [],
        weekPlan: TutorWeekPlan? = nil,
        turns: [TutorChatTurn] = [],
        summary: String = "",
        minutesTarget: Int = 20,
        model: String = "",
        voiceAutoContinue: Bool = false,
        requestCap: Int = 30,
        tokenCap: Int = 80_000,
        requestsByDay: [String: Int] = [:],
        tokensByDay: [String: Int] = [:],
        checkIns: [String] = [],
        lessonCorrect: Int = 0,
        lessonAsked: Int = 0,
        homework: [String] = []
    ) {
        self.notes = notes
        self.mistakes = mistakes
        self.sessions = sessions
        self.weekPlan = weekPlan
        self.turns = turns
        self.summary = summary
        self.minutesTarget = minutesTarget
        self.model = model
        self.voiceAutoContinue = voiceAutoContinue
        self.requestCap = requestCap
        self.tokenCap = tokenCap
        self.requestsByDay = requestsByDay
        self.tokensByDay = tokensByDay
        self.checkIns = checkIns
        self.lessonCorrect = lessonCorrect
        self.lessonAsked = lessonAsked
        self.homework = homework
    }

    public func requests(on day: CivilDay) -> Int { requestsByDay[day.iso] ?? 0 }
    public func tokens(on day: CivilDay) -> Int { tokensByDay[day.iso] ?? 0 }

    public var unresolvedMistakes: [TutorMistake] { mistakes.filter { !$0.resolved } }

    public mutating func addNote(_ text: String, on day: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        notes.append(TutorNote(id: UUID().uuidString, text: String(trimmed.prefix(240)), on: day))
        if notes.count > 40 { notes.removeFirst(notes.count - 40) }
    }

    public mutating func addMistake(thai: String, expected: String, heard: String, note: String, source: String, on day: String) {
        let key = thai.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        if mistakes.contains(where: { $0.thai == key && $0.source == source && $0.on == day && !$0.resolved }) { return }
        mistakes.append(TutorMistake(
            id: UUID().uuidString,
            thai: key,
            expected: expected,
            heard: heard,
            note: note,
            source: source,
            on: day
        ))
        if mistakes.count > 80 { mistakes.removeFirst(mistakes.count - 80) }
    }

    public mutating func recordUse(on day: CivilDay, tokens: Int) {
        requestsByDay[day.iso, default: 0] += 1
        tokensByDay[day.iso, default: 0] += max(0, tokens)
    }

    public mutating func appendTurn(role: String, text: String, on day: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        turns.append(TutorChatTurn(id: UUID().uuidString, role: role, text: trimmed, on: day))
    }
}

public enum TutorBudget {
    public static func allows(_ record: TutorRecord, on day: CivilDay) -> Bool {
        if record.requestCap <= 0 || record.tokenCap <= 0 { return false }
        return record.requests(on: day) < record.requestCap && record.tokens(on: day) < record.tokenCap
    }

    public static func estimate(text: String) -> Int {
        max(1, text.count / 2)
    }
}

public enum TutorBook {
    public static func collectReview(ref: StudyRef, catalog: Catalog, progress: inout LearningProgress, on day: CivilDay) {
        let thai: String
        let meaning: String
        if let phrase = catalog.phrase(ref.id) {
            thai = phrase.thai
            meaning = phrase.meaning
        } else if let word = catalog.word(ref.id) {
            thai = word.thai
            meaning = word.meaning
        } else if let consonant = catalog.consonant(ref.id) {
            thai = consonant.symbol
            meaning = consonant.meaning
        } else if let vowel = catalog.vowel(ref.id) {
            thai = vowel.symbols
            meaning = vowel.roman
        } else if let tone = catalog.tones.first(where: { $0.id == ref.id }) {
            thai = tone.exampleThai
            meaning = tone.mandarin
        } else {
            return
        }
        progress.tutor.addMistake(thai: thai, expected: thai, heard: "", note: "复习时忘了：\(meaning)", source: "review", on: day.iso)
    }
}

// MARK: - Learner snapshot

public struct LearnerLapse: Codable, Equatable, Sendable {
    public var id: String
    public var label: String
    public var lapses: Int

    public init(id: String, label: String, lapses: Int) {
        self.id = id
        self.label = label
        self.lapses = lapses
    }
}

public struct LearnerSnapshot: Codable, Equatable, Sendable {
    public var day: String
    public var dayNumber: Int
    public var phase: String
    public var streak: Int
    public var minutesToday: Int
    public var minutesTarget: Int
    public var dueReviews: Int
    public var cardCount: Int
    public var lapses: [LearnerLapse]
    public var weakScript: [String]
    public var typingWPM: Double
    public var typingWeakKeys: [String]
    public var shadowingAverage: Int
    public var missedLines: [String]
    public var scenarioResults: [String]
    public var cultureRead: Int
    public var cultureTotal: Int
    public var statedGoals: String
    public var roadmap: String
    public var speech: String
    public var memory: [String]
    public var grounded: [String]

    public init(
        day: String,
        dayNumber: Int,
        phase: String,
        streak: Int,
        minutesToday: Int,
        minutesTarget: Int,
        dueReviews: Int,
        cardCount: Int,
        lapses: [LearnerLapse],
        weakScript: [String],
        typingWPM: Double,
        typingWeakKeys: [String],
        shadowingAverage: Int,
        missedLines: [String],
        scenarioResults: [String],
        cultureRead: Int,
        cultureTotal: Int,
        statedGoals: String,
        roadmap: String,
        speech: String,
        memory: [String],
        grounded: [String]
    ) {
        self.day = day
        self.dayNumber = dayNumber
        self.phase = phase
        self.streak = streak
        self.minutesToday = minutesToday
        self.minutesTarget = minutesTarget
        self.dueReviews = dueReviews
        self.cardCount = cardCount
        self.lapses = lapses
        self.weakScript = weakScript
        self.typingWPM = typingWPM
        self.typingWeakKeys = typingWeakKeys
        self.shadowingAverage = shadowingAverage
        self.missedLines = missedLines
        self.scenarioResults = scenarioResults
        self.cultureRead = cultureRead
        self.cultureTotal = cultureTotal
        self.statedGoals = statedGoals
        self.roadmap = roadmap
        self.speech = speech
        self.memory = memory
        self.grounded = grounded
    }

    public static let statedGoals = "能和泰国人交谈，了解泰国文化，以后能自然地约会、认识对象。"
    public static let roadmap = "两周发音和生存句，大约一个月认字，然后语法和词汇。每天大约 20 分钟。"
    public static let speech = "学习者是男性，自称 ผม，句尾用 ครับ。听得懂女生的 ค่ะ / คะ，自己不说。"

    public func json() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(self), let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }
}

public enum LearnerModel {
    public static func snapshot(catalog: Catalog, progress: LearningProgress, today: CivilDay) -> LearnerSnapshot {
        let phase = StudyPlan.phase(on: today, start: progress.startDate)
        let report = ProgressReport.make(catalog: catalog, progress: progress, today: today)
        let lapses = progress.cards
            .filter { $0.value.lapses > 0 }
            .sorted { lhs, rhs in
                if lhs.value.lapses != rhs.value.lapses { return lhs.value.lapses > rhs.value.lapses }
                return lhs.key < rhs.key
            }
            .prefix(6)
            .map { key, card in
                LearnerLapse(id: key, label: label(for: key, catalog: catalog), lapses: card.lapses)
            }
        let weakScript = progress.cards.compactMap { key, card -> String? in
            guard card.lapses > 0 || card.stage == .relearning else { return nil }
            if catalog.consonant(key) != nil || catalog.vowel(key) != nil || catalog.tones.contains(where: { $0.id == key }) {
                return label(for: key, catalog: catalog)
            }
            return nil
        }.sorted()
        let wpm = (progress.typing.best.values.map(\.cpm).max() ?? 0) / 5
        let weakKeys = progress.typing.weakKeys.prefix(6).map(\.key)
        let scores = progress.ai.attempts.map(\.score)
        let average = scores.isEmpty ? 0 : scores.reduce(0, +) / scores.count
        let missed = progress.ai.attempts.filter { $0.score < 80 }.suffix(4).map { "\($0.target) ← \($0.transcript)" }
        let scenarios = catalog.scenarios.sorted { $0.order < $1.order }.map { scenario -> String in
            if let log = progress.scenarioLog[scenario.id] {
                return "\(scenario.title)：扮演 \(log.roleScore ?? 0)，理解 \(log.quizCorrect)/\(log.quizAsked)"
            }
            return "\(scenario.title)：还没练"
        }
        let read = progress.cultureLog.values.filter(\.read).count
        let typingMinutes = Int(progress.typing.seconds(on: today) / 60)
        let sessionMinutes = progress.tutor.sessions.filter { $0.on == today.iso }.reduce(0) { $0 + $1.minutes }
        let grounded = groundingLines(catalog: catalog, progress: progress, phase: phase)
        return LearnerSnapshot(
            day: today.iso,
            dayNumber: StudyPlan.dayNumber(on: today, start: progress.startDate),
            phase: phase.title,
            streak: progress.streak,
            minutesToday: typingMinutes + sessionMinutes,
            minutesTarget: progress.tutor.minutesTarget,
            dueReviews: report.due,
            cardCount: progress.cards.count,
            lapses: Array(lapses),
            weakScript: Array(weakScript.prefix(8)),
            typingWPM: (wpm * 10).rounded() / 10,
            typingWeakKeys: Array(weakKeys),
            shadowingAverage: average,
            missedLines: Array(missed),
            scenarioResults: scenarios,
            cultureRead: read,
            cultureTotal: catalog.culture.count,
            statedGoals: LearnerSnapshot.statedGoals,
            roadmap: LearnerSnapshot.roadmap,
            speech: LearnerSnapshot.speech,
            memory: progress.tutor.notes.suffix(6).map(\.text),
            grounded: grounded
        )
    }

    public static func label(for key: String, catalog: Catalog) -> String {
        let id = key.split(separator: "#").first.map(String.init) ?? key
        if let phrase = catalog.phrase(id) { return phrase.thai }
        if let word = catalog.word(id) { return word.thai }
        if let consonant = catalog.consonant(id) { return consonant.symbol }
        if let vowel = catalog.vowel(id) { return vowel.symbols }
        if let tone = catalog.tones.first(where: { $0.id == id }) { return tone.mandarin }
        return id
    }

    public static func groundingLines(catalog: Catalog, progress: LearningProgress, phase: Phase) -> [String] {
        nextPhrases(catalog: catalog, progress: progress, phase: phase, limit: 8).map {
            "\($0.thai) | \($0.romanization) | \($0.meaning)"
        }
    }

    public static func nextPhrases(catalog: Catalog, progress: LearningProgress, phase: Phase, limit: Int) -> [Phrase] {
        let deckOrder = Dictionary(uniqueKeysWithValues: catalog.decks.map { ($0.id, $0.order) })
        return catalog.phrases
            .filter { $0.phase <= phase && progress.cards[$0.id] == nil }
            .sorted { lhs, rhs in
                let left = (deckOrder[lhs.deck] ?? 99) * 1000 + lhs.order
                let right = (deckOrder[rhs.deck] ?? 99) * 1000 + rhs.order
                if left != right { return left < right }
                return lhs.id < rhs.id
            }
            .prefix(limit)
            .map { $0 }
    }
}

// MARK: - Tools

public struct LLMToolCall: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var arguments: String

    public init(id: String, name: String, arguments: String) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }
}

public struct LLMTurn: Equatable, Sendable {
    public var text: String
    public var calls: [LLMToolCall]
    public var tokens: Int

    public init(text: String, calls: [LLMToolCall], tokens: Int) {
        self.text = text
        self.calls = calls
        self.tokens = tokens
    }
}

public struct TutorWireMessage: Codable, Equatable, Sendable {
    public var role: String
    public var content: String
    public var toolCallID: String
    public var toolCalls: [LLMToolCall]

    public init(role: String, content: String, toolCallID: String = "", toolCalls: [LLMToolCall] = []) {
        self.role = role
        self.content = content
        self.toolCallID = toolCallID
        self.toolCalls = toolCalls
    }

    public static func system(_ text: String) -> TutorWireMessage { TutorWireMessage(role: "system", content: text) }
    public static func user(_ text: String) -> TutorWireMessage { TutorWireMessage(role: "user", content: text) }
    public static func tool(id: String, content: String) -> TutorWireMessage {
        TutorWireMessage(role: "tool", content: content, toolCallID: id)
    }
}

public struct TutorToolSpec: Codable, Equatable, Sendable {
    public var name: String
    public var description: String
    public var parameters: String

    public init(name: String, description: String, parameters: String) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

public struct TutorTeachCard: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var thai: String
    public var romanization: String
    public var meaning: String
    public var explanation: String
    public var tone: String

    public init(id: String, thai: String, romanization: String, meaning: String, explanation: String, tone: String) {
        self.id = id
        self.thai = thai
        self.romanization = romanization
        self.meaning = meaning
        self.explanation = explanation
        self.tone = tone
    }
}

public struct TutorExercise: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var kind: String
    public var title: String
    public var detail: String
    public var payload: String

    public init(id: String, kind: String, title: String, detail: String, payload: String) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.payload = payload
    }
}

public struct TutorQuizQuestion: Codable, Equatable, Sendable {
    public var prompt: String
    public var choices: [String]
    public var answer: Int

    public init(prompt: String, choices: [String], answer: Int) {
        self.prompt = prompt
        self.choices = choices
        self.answer = answer
    }
}

public enum TutorTools {
    public static let names = [
        "get_learner_snapshot",
        "start_review",
        "start_typing",
        "start_shadowing",
        "start_roleplay",
        "show_card",
        "teach_item",
        "quiz",
        "add_cards",
        "log_mistake",
        "update_memory",
        "set_plan",
        "open_culture"
    ]

    public static let specs: [TutorToolSpec] = [
        spec("get_learner_snapshot", "读取本地学习快照。安排今天的课之前先看它。", [:]),
        spec("start_review", "在应用里打开复习。deck 用 due 或课组 id，count 是张数。", [
            "deck": ["type": "string"],
            "count": ["type": "integer"]
        ]),
        spec("start_typing", "打开一小节打字。lesson 是课文 id，可以为空。", ["lesson": ["type": "string"]]),
        spec("start_shadowing", "跟读这些泰文句子。必须来自课程。", ["sentences": ["type": "array", "items": ["type": "string"]]]),
        spec("start_roleplay", "打开一个场景扮演。scenario 是场景 id。", [
            "scenario": ["type": "string"],
            "persona": ["type": "string"],
            "goals": ["type": "array", "items": ["type": "string"]]
        ]),
        spec("show_card", "展示课程里已有的一张教学卡。优先给 id。", [
            "id": ["type": "string"],
            "thai": ["type": "string"]
        ]),
        spec("teach_item", "教一个课程里的说法。泰文必须能在词表里对上，否则会被退回。", [
            "id": ["type": "string"],
            "thai": ["type": "string"],
            "explanation": ["type": "string"]
        ]),
        spec("quiz", "出一道应用内小测。items 是短语 id 或泰文，type 是 toChinese、toThai 或 listening。", [
            "items": ["type": "array", "items": ["type": "string"]],
            "type": ["type": "string"]
        ]),
        spec("add_cards", "把课程里的短语或词加入 FSRS。items 是 id。", ["items": ["type": "array", "items": ["type": "string"]]]),
        spec("log_mistake", "记一条错题。", [
            "thai": ["type": "string"],
            "expected": ["type": "string"],
            "heard": ["type": "string"],
            "note": ["type": "string"],
            "source": ["type": "string"]
        ]),
        spec("update_memory", "写一条关于这个学习者的笔记：误解、兴趣、哪种讲法有效。", ["note": ["type": "string"]]),
        spec("set_plan", "写下或修订本周计划。", [
            "week_goals": ["type": "array", "items": ["type": "string"]],
            "milestones": ["type": "array", "items": ["type": "string"]],
            "note": ["type": "string"]
        ]),
        spec("open_culture", "打开一篇文化文章。article 是 id 或标题。", ["article": ["type": "string"]])
    ]

    public static func spec(_ name: String, _ description: String, _ properties: [String: Any]) -> TutorToolSpec {
        let parameters: [String: Any] = ["type": "object", "properties": properties]
        return TutorToolSpec(name: name, description: description, parameters: TutorJSON.text(parameters))
    }
}

public enum TutorJSON {
    public static func text(_ value: Any) -> String {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value),
              let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }

    public static func object(_ raw: String) -> [String: Any] {
        guard let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return object
    }

    public static func string(_ object: [String: Any], _ key: String) -> String {
        if let value = object[key] as? String { return value }
        return ""
    }

    public static func int(_ object: [String: Any], _ key: String, fallback: Int) -> Int {
        if let value = object[key] as? Int { return value }
        if let value = object[key] as? Double { return Int(value) }
        if let value = object[key] as? String, let number = Int(value) { return number }
        return fallback
    }

    public static func strings(_ object: [String: Any], _ key: String) -> [String] {
        if let values = object[key] as? [String] { return values }
        if let values = object[key] as? [Any] { return values.compactMap { $0 as? String } }
        return []
    }
}

public struct TutorHandled: Equatable, Sendable {
    public var resultJSON: String
    public var exercise: TutorExercise?
    public var card: TutorTeachCard?
    public var cultureID: String?

    public init(resultJSON: String, exercise: TutorExercise? = nil, card: TutorTeachCard? = nil, cultureID: String? = nil) {
        self.resultJSON = resultJSON
        self.exercise = exercise
        self.card = card
        self.cultureID = cultureID
    }
}

public enum TutorDispatch {
    public static func apply(
        _ call: LLMToolCall,
        catalog: Catalog,
        progress: inout LearningProgress,
        today: CivilDay
    ) -> TutorHandled {
        guard TutorTools.names.contains(call.name) else {
            return TutorHandled(resultJSON: TutorJSON.text(["ok": false, "error": "没有这个工具"]))
        }
        let args = TutorJSON.object(call.arguments)
        switch call.name {
        case "get_learner_snapshot":
            return TutorHandled(resultJSON: LearnerModel.snapshot(catalog: catalog, progress: progress, today: today).json())
        case "start_review":
            let count = min(12, max(1, TutorJSON.int(args, "count", fallback: 8)))
            let deck = TutorJSON.string(args, "deck")
            let exercise = TutorExercise(
                id: call.id,
                kind: "review",
                title: "复习",
                detail: "先处理到期的卡片。",
                payload: TutorJSON.text(["deck": deck.isEmpty ? "due" : deck, "count": count])
            )
            return TutorHandled(resultJSON: waiting("review"), exercise: exercise)
        case "start_typing":
            let lesson = TutorJSON.string(args, "lesson")
            let exercise = TutorExercise(
                id: call.id,
                kind: "typing",
                title: "打字",
                detail: "打一行。声调符号单独算。",
                payload: TutorJSON.text(["lesson": lesson])
            )
            return TutorHandled(resultJSON: waiting("typing"), exercise: exercise)
        case "start_shadowing":
            let requested = TutorJSON.strings(args, "sentences")
            let phase = StudyPlan.phase(on: today, start: progress.startDate)
            let sentences = TutorGrounding.approvedSentences(requested, catalog: catalog, progress: progress, phase: phase)
            let exercise = TutorExercise(
                id: call.id,
                kind: "shadowing",
                title: "跟读",
                detail: "听一句，再说一遍。分数来自转写对齐。",
                payload: TutorJSON.text(["sentences": sentences])
            )
            return TutorHandled(resultJSON: waiting("shadowing"), exercise: exercise)
        case "start_roleplay":
            let requested = TutorJSON.string(args, "scenario")
            let scenario = catalog.scenarios.first { $0.id == requested } ?? catalog.scenarios.sorted { $0.order < $1.order }.first
            let exercise = TutorExercise(
                id: call.id,
                kind: "roleplay",
                title: scenario?.title ?? "场景",
                detail: scenario?.setting ?? "",
                payload: TutorJSON.text([
                    "scenario": scenario?.id ?? "",
                    "persona": TutorJSON.string(args, "persona"),
                    "goals": TutorJSON.strings(args, "goals")
                ])
            )
            return TutorHandled(resultJSON: waiting("roleplay"), exercise: exercise)
        case "show_card", "teach_item":
            let explanation = TutorJSON.string(args, "explanation")
            guard let card = TutorGrounding.card(id: TutorJSON.string(args, "id"), thai: TutorJSON.string(args, "thai"), explanation: explanation, catalog: catalog) else {
                let suggestion = LearnerModel.nextPhrases(
                    catalog: catalog,
                    progress: progress,
                    phase: StudyPlan.phase(on: today, start: progress.startDate),
                    limit: 1
                ).first
                return TutorHandled(resultJSON: TutorJSON.text([
                    "ok": false,
                    "error": "这句不在课程词表里，不要自己编泰文。",
                    "use": suggestion.map { ["id": $0.id, "thai": $0.thai, "romanization": $0.romanization, "meaning": $0.meaning] } ?? [:]
                ]))
            }
            return TutorHandled(resultJSON: TutorJSON.text(["ok": true, "thai": card.thai, "tone": card.tone]), card: card)
        case "quiz":
            let questions = TutorQuiz.make(items: TutorJSON.strings(args, "items"), type: TutorJSON.string(args, "type"), catalog: catalog)
            guard !questions.isEmpty else {
                return TutorHandled(resultJSON: TutorJSON.text(["ok": false, "error": "没有可考的课程句子"]))
            }
            let payload = TutorJSON.text([
                "type": TutorJSON.string(args, "type"),
                "questions": questions.map { ["prompt": $0.prompt, "choices": $0.choices, "answer": $0.answer] }
            ])
            let exercise = TutorExercise(id: call.id, kind: "quiz", title: "小测", detail: "选一句。", payload: payload)
            return TutorHandled(resultJSON: waiting("quiz"), exercise: exercise)
        case "add_cards":
            var added: [String] = []
            for item in TutorJSON.strings(args, "items") {
                let id = item.split(separator: "#").first.map(String.init) ?? item
                guard catalog.phrase(id) != nil || catalog.word(id) != nil else { continue }
                if progress.cards[id] == nil {
                    progress.cards[id] = CardState.fresh(on: today)
                    added.append(id)
                }
            }
            return TutorHandled(resultJSON: TutorJSON.text(["ok": true, "added": added]))
        case "log_mistake":
            progress.tutor.addMistake(
                thai: TutorJSON.string(args, "thai"),
                expected: TutorJSON.string(args, "expected"),
                heard: TutorJSON.string(args, "heard"),
                note: TutorJSON.string(args, "note"),
                source: TutorJSON.string(args, "source").isEmpty ? "tutor" : TutorJSON.string(args, "source"),
                on: today.iso
            )
            return TutorHandled(resultJSON: TutorJSON.text(["ok": true, "open": progress.tutor.unresolvedMistakes.count]))
        case "update_memory":
            progress.tutor.addNote(TutorJSON.string(args, "note"), on: today.iso)
            return TutorHandled(resultJSON: TutorJSON.text(["ok": true, "notes": progress.tutor.notes.count]))
        case "set_plan":
            let goals = TutorJSON.strings(args, "week_goals")
            let milestones = TutorJSON.strings(args, "milestones")
            progress.tutor.weekPlan = TutorWeekPlan(
                weekOf: today.iso,
                goals: goals.isEmpty ? ["把今天到期的复习完"] : goals,
                milestones: milestones,
                note: TutorJSON.string(args, "note")
            )
            return TutorHandled(resultJSON: TutorJSON.text(["ok": true]))
        case "open_culture":
            let query = TutorJSON.string(args, "article")
            let note = catalog.culture.first { $0.id == query || $0.title == query || $0.title.contains(query) }
            guard let note else {
                return TutorHandled(resultJSON: TutorJSON.text(["ok": false, "error": "没有这篇"]))
            }
            return TutorHandled(resultJSON: TutorJSON.text(["ok": true, "id": note.id, "title": note.title]), cultureID: note.id)
        default:
            return TutorHandled(resultJSON: TutorJSON.text(["ok": false, "error": "没有这个工具"]))
        }
    }

    private static func waiting(_ kind: String) -> String {
        TutorJSON.text(["ok": true, "status": "waiting", "kind": kind])
    }
}

public enum TutorGrounding {
    public static func card(id: String, thai: String, explanation: String, catalog: Catalog) -> TutorTeachCard? {
        if let phrase = catalog.phrase(id) ?? catalog.phrases.first(where: { $0.thai == thai || $0.spoken == thai }) {
            return make(id: phrase.id, thai: phrase.thai, roman: phrase.romanization, meaning: phrase.meaning, explanation: explanation, note: phrase.note)
        }
        if let word = catalog.word(id) ?? catalog.word(thai: thai) {
            return make(id: word.id, thai: word.thai, roman: word.romanization, meaning: word.meaning, explanation: explanation, note: nil)
        }
        if let scenarioPhrase = catalog.scenarios.flatMap(\.phrases).first(where: { $0.id == id || $0.thai == thai }) {
            return make(id: scenarioPhrase.id, thai: scenarioPhrase.thai, roman: scenarioPhrase.romanization, meaning: scenarioPhrase.meaning, explanation: explanation, note: nil)
        }
        if let culture = catalog.culture.flatMap(\.phrases).first(where: { $0.thai == thai }) {
            return make(id: culture.thai, thai: culture.thai, roman: culture.romanization, meaning: culture.meaning, explanation: explanation, note: nil)
        }
        return nil
    }

    public static func approvedSentences(_ requested: [String], catalog: Catalog, progress: LearningProgress, phase: Phase) -> [String] {
        let known = requested.filter { card(id: "", thai: $0, explanation: "", catalog: catalog) != nil }
        if !known.isEmpty { return Array(known.prefix(3)) }
        return LearnerModel.nextPhrases(catalog: catalog, progress: progress, phase: phase, limit: 2).map(\.spoken)
    }

    public static func toneName(romanization: String) -> String {
        var found: [String] = []
        if romanization.contains("ǎ") { found.append("升调") }
        if romanization.contains("á") || romanization.contains("é") || romanization.contains("í") || romanization.contains("ó") || romanization.contains("ú") || romanization.contains("ǽ") {
            found.append("高调")
        }
        if romanization.contains("â") || romanization.contains("ê") || romanization.contains("î") || romanization.contains("ô") || romanization.contains("û") {
            found.append("降调")
        }
        if romanization.contains("à") || romanization.contains("è") || romanization.contains("ì") || romanization.contains("ò") || romanization.contains("ù") {
            found.append("低调")
        }
        let unique = Array(Set(found))
        if unique.count == 1 { return unique[0] }
        if unique.isEmpty { return "中调" }
        return found.joined(separator: "、")
    }

    private static func make(id: String, thai: String, roman: String, meaning: String, explanation: String, note: String?) -> TutorTeachCard? {
        guard ContentLoader.toneMarkBeforeVowel(thai) else { return nil }
        let extra = [explanation, note ?? ""].filter { !$0.isEmpty }.joined(separator: " ")
        return TutorTeachCard(
            id: id,
            thai: thai,
            romanization: roman,
            meaning: meaning,
            explanation: extra.isEmpty ? "男生说这句时用 ครับ。" : extra,
            tone: toneName(romanization: roman)
        )
    }
}

public enum TutorQuiz {
    public static func make(items: [String], type: String, catalog: Catalog) -> [TutorQuizQuestion] {
        let phrases = resolve(items, catalog: catalog)
        let pool = catalog.phrases
        guard !phrases.isEmpty, pool.count >= 3 else { return [] }
        return phrases.prefix(3).map { phrase in
            let distractors = pool.filter { $0.id != phrase.id }.prefix(2)
            switch type {
            case "toThai":
                var choices = distractors.map(\.thai) + [phrase.thai]
                choices.shuffle()
                let answer = choices.firstIndex(of: phrase.thai) ?? 0
                return TutorQuizQuestion(prompt: "「\(phrase.meaning)」泰文怎么说？", choices: choices, answer: answer)
            case "listening":
                var choices = distractors.map(\.meaning) + [phrase.meaning]
                choices.shuffle()
                let answer = choices.firstIndex(of: phrase.meaning) ?? 0
                return TutorQuizQuestion(prompt: "听 \(phrase.thai)。中文是？", choices: choices, answer: answer)
            default:
                var choices = distractors.map(\.meaning) + [phrase.meaning]
                choices.shuffle()
                let answer = choices.firstIndex(of: phrase.meaning) ?? 0
                return TutorQuizQuestion(prompt: phrase.thai, choices: choices, answer: answer)
            }
        }
    }

    private static func resolve(_ items: [String], catalog: Catalog) -> [Phrase] {
        if items.isEmpty { return Array(catalog.phrases.prefix(1)) }
        return items.compactMap { item in
            catalog.phrase(item) ?? catalog.phrases.first { $0.thai == item }
        }
    }
}

// MARK: - Prompt, compaction, agent

public enum TutorPrompt {
    public static func system(snapshot: LearnerSnapshot, summary: String, context: String, minutes: Int) -> String {
        """
        你是วันละนิด里的泰语老师。用简体中文带他学。耐心，但是直接：先说结论，再给一句例子，不要长篇空话。
        他是男性。教他说的句子用 ผม 和 ครับ。可以告诉他女生会说 ค่ะ / คะ，但不要让他用女生的句尾。
        新词一定写出泰文、Paiboon 罗马音和声调。五个声调：中调不标，低调 à，降调 â，高调 á，升调 ǎ。例如 สวัสดีครับ（sà-wàt-dii khráp，你好）、ขอบคุณครับ（khàwp-khun khráp，谢谢）、ผมชื่อเบนครับ（phǒm chʉ̂ʉ ben khráp，我叫 Ben）。
        声调符号写在 า 和 ำ 前面，不要写在后面。
        文化上具体、尊重、不刻板。不要拿王室开玩笑，不要把 สินสอด 说成给人标价，不要说泰国人从不拒绝。
        目标：\(snapshot.statedGoals)
        路线：\(snapshot.roadmap) 这一课大约 \(minutes) 分钟。
        当前画面：\(context)
        之前的摘要：\(summary.isEmpty ? "还没有。" : summary)
        学习者快照：
        \(snapshot.json())
        只能使用快照里 grounded 列出的句子，或工具从课程里取到的句子。不要编造泰文。工具如果退回「不在课程词表里」，就改用它给的 id。
        用工具办事，不要假装已经打开了练习。开始今天的课时：先用一两句回顾笔记，看到期复习，再教一小段，用工具穿插练习，当场纠正，最后用中文总结、给一个分数，留 1 到 2 项作业，并 update_memory。
        练习做完后，下一条用户消息以「练习结果：」开头。根据对错调整难度。
        他问语法、用法或文化时，用中文回答，配上课程里的泰文例子。
        """
    }
}

public enum TutorCompaction {
    public static func compact(summary: String, turns: [TutorChatTurn], keep: Int = 8) -> (summary: String, turns: [TutorChatTurn]) {
        guard turns.count > keep + 4 else { return (summary, turns) }
        let dropped = turns.dropLast(keep)
        let kept = Array(turns.suffix(keep))
        var lines = summary.split(separator: "\n").map(String.init)
        for turn in dropped {
            let who = turn.role == "user" ? "他" : "老师"
            let clip = turn.text.replacingOccurrences(of: "\n", with: " ")
            lines.append("\(who)：\(String(clip.prefix(80)))")
        }
        var folded = lines.suffix(12).joined(separator: "\n")
        if folded.count > 800 { folded = String(folded.suffix(800)) }
        return (folded, kept)
    }
}

public struct TutorAgentResult: Equatable, Sendable {
    public var progress: LearningProgress
    public var assistantText: String
    public var exercise: TutorExercise?
    public var queue: [TutorExercise]
    public var cards: [TutorTeachCard]
    public var cultureID: String?
    public var usedFallback: Bool

    public init(
        progress: LearningProgress,
        assistantText: String,
        exercise: TutorExercise?,
        queue: [TutorExercise],
        cards: [TutorTeachCard],
        cultureID: String?,
        usedFallback: Bool
    ) {
        self.progress = progress
        self.assistantText = assistantText
        self.exercise = exercise
        self.queue = queue
        self.cards = cards
        self.cultureID = cultureID
        self.usedFallback = usedFallback
    }
}

public enum TutorAgent {
    public static func respond(
        fetch: ([TutorWireMessage]) async throws -> LLMTurn,
        userText: String,
        catalog: Catalog,
        progress: LearningProgress,
        today: CivilDay,
        context: String
    ) async -> TutorAgentResult {
        if userText.contains("开始今天的课") == false && userText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return offline(userText: userText, catalog: catalog, progress: progress, today: today, context: context)
        }
        guard TutorBudget.allows(progress.tutor, on: today), progress.ai.usage.allows(today) else {
            return offline(userText: userText, catalog: catalog, progress: progress, today: today, context: context)
        }
        var progress = progress
        if userText.contains("开始今天的课") {
            progress.tutor.lessonCorrect = 0
            progress.tutor.lessonAsked = 0
        }
        let folded = TutorCompaction.compact(summary: progress.tutor.summary, turns: progress.tutor.turns)
        progress.tutor.summary = folded.summary
        progress.tutor.turns = folded.turns
        let snapshot = LearnerModel.snapshot(catalog: catalog, progress: progress, today: today)
        var wire: [TutorWireMessage] = [
            .system(TutorPrompt.system(snapshot: snapshot, summary: progress.tutor.summary, context: context, minutes: progress.tutor.minutesTarget))
        ]
        wire += progress.tutor.turns.map { TutorWireMessage(role: $0.role == "assistant" ? "assistant" : "user", content: $0.text) }
        wire.append(.user(userText))
        var assistant = ""
        var cards: [TutorTeachCard] = []
        var exercise: TutorExercise?
        var cultureID: String?
        var fallback = false
        for round in 0..<4 {
            var turn: LLMTurn?
            var attempts = 0
            while attempts < 2 && turn == nil {
                attempts += 1
                do {
                    turn = try await fetch(wire)
                } catch {
                    if attempts >= 2 { fallback = true }
                }
            }
            guard let turn else { break }
            progress.tutor.recordUse(on: today, tokens: max(turn.tokens, TutorBudget.estimate(text: turn.text)))
            progress.ai.usage.record(on: today)
            if !turn.text.isEmpty { assistant = turn.text }
            if turn.calls.isEmpty { break }
            wire.append(TutorWireMessage(role: "assistant", content: turn.text, toolCalls: turn.calls))
            var waiting = false
            for call in turn.calls {
                let handled = TutorDispatch.apply(call, catalog: catalog, progress: &progress, today: today)
                if let card = handled.card { cards.append(card) }
                if let id = handled.cultureID { cultureID = id }
                if let item = handled.exercise {
                    exercise = item
                    waiting = true
                    wire.append(.tool(id: call.id, content: handled.resultJSON))
                    break
                }
                wire.append(.tool(id: call.id, content: handled.resultJSON))
            }
            if waiting || round == 3 { break }
        }
        if fallback || assistant.isEmpty && exercise == nil && cards.isEmpty {
            return offline(userText: userText, catalog: catalog, progress: progress, today: today, context: context)
        }
        progress.tutor.appendTurn(role: "user", text: userText, on: today.iso)
        progress.tutor.appendTurn(role: "assistant", text: assistant, on: today.iso)
        return TutorAgentResult(
            progress: progress,
            assistantText: assistant,
            exercise: exercise,
            queue: [],
            cards: cards,
            cultureID: cultureID,
            usedFallback: false
        )
    }

    public static func offline(
        userText: String,
        catalog: Catalog,
        progress: LearningProgress,
        today: CivilDay,
        context: String
    ) -> TutorAgentResult {
        var progress = progress
        let daily = userText.contains("开始今天的课") || userText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if daily {
            let lesson = OfflineTutor.lesson(catalog: catalog, progress: progress, today: today)
            progress.tutor.homework = lesson.homework
            progress.tutor.lessonCorrect = 0
            progress.tutor.lessonAsked = 0
            if progress.tutor.weekPlan == nil {
                progress.tutor.weekPlan = OfflineTutor.weekPlan(catalog: catalog, progress: progress, today: today)
            }
            progress.tutor.appendTurn(role: "user", text: userText.isEmpty ? "开始今天的课" : userText, on: today.iso)
            progress.tutor.appendTurn(role: "assistant", text: lesson.assistantText, on: today.iso)
            return TutorAgentResult(
                progress: progress,
                assistantText: lesson.assistantText,
                exercise: lesson.steps.compactMap(\.exercise).first,
                queue: Array(lesson.steps.compactMap(\.exercise).dropFirst()),
                cards: lesson.steps.compactMap(\.card),
                cultureID: nil,
                usedFallback: true
            )
        }
        let reply = OfflineTutor.localReply(userText: userText, context: context, catalog: catalog, progress: progress, today: today)
        progress.tutor.appendTurn(role: "user", text: userText, on: today.iso)
        progress.tutor.appendTurn(role: "assistant", text: reply, on: today.iso)
        return TutorAgentResult(
            progress: progress,
            assistantText: reply,
            exercise: nil,
            queue: [],
            cards: [],
            cultureID: nil,
            usedFallback: true
        )
    }
}

public struct OfflineStep: Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var detail: String
    public var exercise: TutorExercise?
    public var card: TutorTeachCard?

    public init(id: String, title: String, detail: String, exercise: TutorExercise? = nil, card: TutorTeachCard? = nil) {
        self.id = id
        self.title = title
        self.detail = detail
        self.exercise = exercise
        self.card = card
    }
}

public struct OfflineLesson: Equatable, Sendable {
    public var greeting: String
    public var steps: [OfflineStep]
    public var homework: [String]
    public var assistantText: String

    public init(greeting: String, steps: [OfflineStep], homework: [String], assistantText: String) {
        self.greeting = greeting
        self.steps = steps
        self.homework = homework
        self.assistantText = assistantText
    }
}

public enum OfflineTutor {
    public static func lesson(catalog: Catalog, progress: LearningProgress, today: CivilDay) -> OfflineLesson {
        let phase = StudyPlan.phase(on: today, start: progress.startDate)
        let minutes = min(40, max(10, progress.tutor.minutesTarget))
        let reviewCount = minutes >= 30 ? 10 : (minutes >= 20 ? 8 : 4)
        let memory = progress.tutor.notes.suffix(2).map(\.text).joined(separator: " ")
        var greeting = "今天大约 \(minutes) 分钟。路线还是：\(LearnerSnapshot.roadmap) 你是男生，句子用 ผม 和 ครับ。"
        if progress.streak > 0 { greeting += " 连续 \(progress.streak) 天。" }
        if !memory.isEmpty { greeting += " 上次记下：\(memory)" }
        var steps: [OfflineStep] = []
        let due = ProgressReport.make(catalog: catalog, progress: progress, today: today).due
        if due > 0 {
            steps.append(OfflineStep(
                id: "review",
                title: "复习",
                detail: "到期 \(due) 张，这一轮做 \(min(reviewCount, due)) 张。",
                exercise: TutorExercise(id: "review", kind: "review", title: "复习", detail: "到期的卡片。", payload: TutorJSON.text(["deck": "due", "count": min(reviewCount, due)]))
            ))
        }
        if let phrase = LearnerModel.nextPhrases(catalog: catalog, progress: progress, phase: phase, limit: 1).first,
           let card = TutorGrounding.card(id: phrase.id, thai: phrase.thai, explanation: "先听，再自己说一遍，句尾用 ครับ。", catalog: catalog) {
            steps.append(OfflineStep(id: "teach", title: "新的一小段", detail: "\(phrase.thai)  \(phrase.romanization)  \(phrase.meaning)", card: card))
            let questions = TutorQuiz.make(items: [phrase.id], type: "toChinese", catalog: catalog)
            if !questions.isEmpty {
                steps.append(OfflineStep(
                    id: "quiz",
                    title: "理解",
                    detail: "看泰文，选中文。",
                    exercise: TutorExercise(
                        id: "quiz",
                        kind: "quiz",
                        title: "小测",
                        detail: "选中文。",
                        payload: TutorJSON.text(["questions": questions.map { ["prompt": $0.prompt, "choices": $0.choices, "answer": $0.answer] }])
                    )
                ))
            }
        }
        if phase == .pronunciation || !progress.typing.weakKeys.isEmpty {
            let lesson = progress.typing.weakKeys.isEmpty ? "marks" : "weak"
            steps.append(OfflineStep(
                id: "typing",
                title: "打字",
                detail: "打一行，看薄弱的键。",
                exercise: TutorExercise(id: "typing", kind: "typing", title: "打字", detail: "一行就够。", payload: TutorJSON.text(["lesson": lesson]))
            ))
        }
        let spoken = LearnerModel.nextPhrases(catalog: catalog, progress: progress, phase: phase, limit: 2).map(\.spoken)
        if !spoken.isEmpty && (phase == .pronunciation || progress.ai.attempts.contains { $0.score < 80 }) {
            steps.append(OfflineStep(
                id: "shadow",
                title: "跟读",
                detail: "听完自己说。",
                exercise: TutorExercise(id: "shadow", kind: "shadowing", title: "跟读", detail: "分数来自转写。", payload: TutorJSON.text(["sentences": spoken]))
            ))
        }
        if checkInDue(progress: progress, today: today) {
            steps.append(OfflineStep(
                id: "checkin",
                title: "每周核对",
                detail: "这周哪一块最不稳。",
                exercise: TutorExercise(
                    id: "checkin",
                    kind: "checkin",
                    title: "每周核对",
                    detail: "选一个最接近的。",
                    payload: TutorJSON.text(["prompts": ["声调听得更稳了", "句子能说出口", "这周几乎没练"]])
                )
            ))
        }
        if let scenario = catalog.scenarios.sorted(by: { $0.order < $1.order }).first(where: { (progress.scenarioLog[$0.id]?.roleScore ?? 0) < 80 }) {
            steps.append(OfflineStep(
                id: "role",
                title: scenario.title,
                detail: scenario.setting,
                exercise: TutorExercise(id: "role", kind: "roleplay", title: scenario.title, detail: scenario.setting, payload: TutorJSON.text(["scenario": scenario.id]))
            ))
        }
        let homework = Array(progress.tutor.unresolvedMistakes.prefix(2).map { "再看 \($0.thai)：\($0.note)" })
        let homeworkText = homework.isEmpty ? "把今天这句再说一遍，句尾用 ครับ。" : homework.joined(separator: "；")
        var lines = [greeting] + steps.map { "\($0.title)：\($0.detail)" }
        lines.append("作业：\(homeworkText)")
        return OfflineLesson(greeting: greeting, steps: steps, homework: homework.isEmpty ? ["把今天这句再说一遍，句尾用 ครับ。"] : homework, assistantText: lines.joined(separator: "\n"))
    }

    public static func weekPlan(catalog: Catalog, progress: LearningProgress, today: CivilDay) -> TutorWeekPlan {
        let phase = StudyPlan.phase(on: today, start: progress.startDate)
        let goals: [String]
        let milestones: [String]
        switch phase {
        case .pronunciation:
            goals = ["每天听五个声调", "记住见面和自我介绍", "跟读时用 ครับ"]
            milestones = ["第 14 天前能打招呼、道谢、说自己的名字"]
        case .script:
            goals = ["辅音按中高低三类认", "元音和声调符号写对", "句子继续复习"]
            milestones = ["第 45 天前认完常用字母"]
        case .grammar:
            goals = ["虚词和常用词", "把一个场景走完", "读一篇文化"]
            milestones = ["能在语言交换里做自我介绍并约下次"]
        }
        return TutorWeekPlan(weekOf: today.iso, goals: goals, milestones: milestones, note: "按每天 \(progress.tutor.minutesTarget) 分钟。没有模型时用这份。")
    }

    public static func checkInDue(progress: LearningProgress, today: CivilDay) -> Bool {
        guard let last = progress.tutor.checkIns.max(), let day = try? CivilDay(iso: last) else {
            return StudyPlan.dayNumber(on: today, start: progress.startDate) >= 7
        }
        return today.daysSince(day) >= 7
    }

    public static func localReply(userText: String, context: String, catalog: Catalog, progress: LearningProgress, today: CivilDay) -> String {
        if let phrase = catalog.phrases.first(where: { userText.contains($0.thai) || (userText.contains($0.meaning) && $0.meaning.count >= 2) }) {
            let tone = TutorGrounding.toneName(romanization: phrase.romanization)
            return "没有连上老师，用课程里的说法。\(phrase.meaning)：\(phrase.thai)（\(phrase.romanization)，\(tone)）。男生句尾用 ครับ。现在画面是\(context)。"
        }
        if let note = catalog.culture.first(where: { userText.contains($0.title) || $0.title.contains(String(userText.prefix(2))) && userText.count >= 2 }) {
            return "没有连上老师。文化「\(note.title)」可以在侧栏打开。\(String(note.body.prefix(80)))"
        }
        let phase = StudyPlan.phase(on: today, start: progress.startDate)
        if let phrase = LearnerModel.nextPhrases(catalog: catalog, progress: progress, phase: phase, limit: 1).first {
            return "没有连上老师。可以点「今天的课」，按复习、新句子、小测走。下一句是 \(phrase.thai)（\(phrase.romanization)，\(phrase.meaning)）。画面：\(context)。"
        }
        return "没有连上老师。点「今天的课」会按到期复习和课程句子往下排。画面：\(context)。"
    }
}

// MARK: - Streaming

public enum TutorStreamPiece: Equatable, Sendable {
    case text(String)
    case done(LLMTurn)
}

public struct TutorSSEDecoder {
    public var text = ""
    public var calls: [LLMToolCall] = []
    public var tokens = 0
    private var arguments: [Int: String] = [:]
    private var names: [Int: String] = [:]
    private var ids: [Int: String] = [:]

    public init() {}

    public mutating func consume(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("data:") else { return nil }
        let payload = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
        if payload == "[DONE]" { return nil }
        guard let data = payload.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let usage = object["usage"] as? [String: Any], let total = usage["total_tokens"] as? Int {
            tokens = total
        }
        guard let choices = object["choices"] as? [[String: Any]], let choice = choices.first else { return nil }
        let delta = (choice["delta"] as? [String: Any]) ?? (choice["message"] as? [String: Any]) ?? [:]
        var yielded: String?
        if let piece = delta["content"] as? String, !piece.isEmpty {
            text += piece
            yielded = piece
        }
        if let toolCalls = delta["tool_calls"] as? [[String: Any]] {
            for raw in toolCalls {
                let index = raw["index"] as? Int ?? 0
                if let id = raw["id"] as? String { ids[index] = id }
                let function = raw["function"] as? [String: Any] ?? [:]
                if let name = function["name"] as? String, !name.isEmpty { names[index] = name }
                if let argument = function["arguments"] as? String { arguments[index, default: ""] += argument }
            }
        }
        return yielded
    }

    public func turn() -> LLMTurn {
        let indexes = Set(names.keys).union(arguments.keys).union(ids.keys).sorted()
        let calls = indexes.compactMap { index -> LLMToolCall? in
            guard let name = names[index], !name.isEmpty else { return nil }
            return LLMToolCall(id: ids[index] ?? "call-\(index)", name: name, arguments: arguments[index] ?? "{}")
        }
        let tokens = tokens > 0 ? tokens : TutorBudget.estimate(text: text)
        return LLMTurn(text: text, calls: calls.isEmpty ? self.calls : calls, tokens: tokens)
    }
}

public enum TutorTextStream {
    public static func chunks(_ text: String, size: Int = 12) -> [String] {
        guard !text.isEmpty else { return [] }
        var output: [String] = []
        var current = ""
        for character in text {
            current.append(character)
            if current.count >= size {
                output.append(current)
                current = ""
            }
        }
        if !current.isEmpty { output.append(current) }
        return output
    }
}

public enum TutorAPI {
    public static func payload(model: String, messages: [TutorWireMessage], tools: [TutorToolSpec], stream: Bool) -> [String: Any] {
        var body: [String: Any] = [
            "model": model,
            "messages": messages.map { apiMessage($0) },
            "temperature": 0.4,
            "tools": tools.compactMap { openAI($0) }
        ]
        if stream {
            body["stream"] = true
            body["stream_options"] = ["include_usage": true]
        }
        return body
    }

    public static func parseTurn(_ data: Data) throws -> LLMTurn {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = object["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any]
        else { throw AIClientError.decode }
        let text = messageText(message)
        var calls: [LLMToolCall] = []
        if let rawCalls = message["tool_calls"] as? [[String: Any]] {
            for (index, raw) in rawCalls.enumerated() {
                let function = raw["function"] as? [String: Any] ?? [:]
                let name = function["name"] as? String ?? ""
                guard !name.isEmpty else { continue }
                let arguments = argumentText(function["arguments"])
                let id = raw["id"] as? String ?? "call-\(index)"
                calls.append(LLMToolCall(id: id, name: name, arguments: arguments))
            }
        }
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && calls.isEmpty {
            throw AIClientError.empty
        }
        let usage = object["usage"] as? [String: Any]
        let reported = usage?["total_tokens"] as? Int ?? 0
        let tokens = reported > 0 ? reported : TutorBudget.estimate(text: text + calls.map(\.arguments).joined())
        return LLMTurn(text: text.trimmingCharacters(in: .whitespacesAndNewlines), calls: calls, tokens: tokens)
    }

    private static func apiMessage(_ message: TutorWireMessage) -> [String: Any] {
        if message.role == "tool" {
            return ["role": "tool", "tool_call_id": message.toolCallID, "content": message.content]
        }
        if message.role == "assistant", !message.toolCalls.isEmpty {
            let calls: [[String: Any]] = message.toolCalls.map { call in
                [
                    "id": call.id,
                    "type": "function",
                    "function": ["name": call.name, "arguments": call.arguments]
                ]
            }
            var body: [String: Any] = ["role": "assistant", "tool_calls": calls]
            body["content"] = message.content.isEmpty ? NSNull() : message.content
            return body
        }
        return ["role": message.role, "content": message.content]
    }

    private static func openAI(_ spec: TutorToolSpec) -> [String: Any]? {
        guard let data = spec.parameters.data(using: .utf8),
              let parameters = try? JSONSerialization.jsonObject(with: data) else { return nil }
        return [
            "type": "function",
            "function": [
                "name": spec.name,
                "description": spec.description,
                "parameters": parameters
            ]
        ]
    }

    private static func messageText(_ message: [String: Any]) -> String {
        if let content = message["content"] as? String { return content }
        if let parts = message["content"] as? [[String: Any]] {
            return parts.compactMap { $0["text"] as? String }.joined()
        }
        return ""
    }

    private static func argumentText(_ value: Any?) -> String {
        if let text = value as? String { return text.isEmpty ? "{}" : text }
        if let value, JSONSerialization.isValidJSONObject(value), let data = try? JSONSerialization.data(withJSONObject: value), let text = String(data: data, encoding: .utf8) {
            return text
        }
        return "{}"
    }
}

public protocol ToolChatModel: ChatModel {
    func completeTurn(messages: [TutorWireMessage], tools: [TutorToolSpec]) async throws -> LLMTurn
}

public protocol TutorStreamingChat: ToolChatModel {
    func streamTurn(messages: [TutorWireMessage], tools: [TutorToolSpec]) -> AsyncThrowingStream<TutorStreamPiece, Error>
}

public struct TextOnlyToolChat: ToolChatModel {
    public var base: ChatModel

    public init(base: ChatModel) {
        self.base = base
    }

    public func complete(messages: [AIChatMessage], jsonObject: Bool) async throws -> String {
        try await base.complete(messages: messages, jsonObject: jsonObject)
    }

    public func completeTurn(messages: [TutorWireMessage], tools: [TutorToolSpec]) async throws -> LLMTurn {
        let plain = messages.filter { $0.role != "tool" }.map { AIChatMessage(role: $0.role == "assistant" ? "assistant" : ($0.role == "system" ? "system" : "user"), content: $0.content) }
        let text = try await base.complete(messages: plain, jsonObject: false)
        return LLMTurn(text: text, calls: [], tokens: TutorBudget.estimate(text: text))
    }
}

extension OpenAICompatibleClient: TutorStreamingChat {
    public func completeTurn(messages: [TutorWireMessage], tools: [TutorToolSpec]) async throws -> LLMTurn {
        let response = try await post(
            path: "chat/completions",
            json: TutorAPI.payload(model: chatModel, messages: messages, tools: tools, stream: false)
        )
        try throwIfNeeded(response)
        return try TutorAPI.parseTurn(response.data)
    }

    public func streamTurn(messages: [TutorWireMessage], tools: [TutorToolSpec]) -> AsyncThrowingStream<TutorStreamPiece, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    #if os(macOS) || os(iOS)
                    if let live = self.transport as? URLSessionAITransport {
                        try await self.readStream(session: live.session, messages: messages, tools: tools, continuation: continuation)
                    } else {
                        try await self.emitComplete(messages: messages, tools: tools, continuation: continuation)
                    }
                    #else
                    try await self.emitComplete(messages: messages, tools: tools, continuation: continuation)
                    #endif
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func emitComplete(
        messages: [TutorWireMessage],
        tools: [TutorToolSpec],
        continuation: AsyncThrowingStream<TutorStreamPiece, Error>.Continuation
    ) async throws {
        let turn = try await completeTurn(messages: messages, tools: tools)
        for chunk in TutorTextStream.chunks(turn.text) {
            continuation.yield(.text(chunk))
        }
        continuation.yield(.done(turn))
    }

    #if os(macOS) || os(iOS)
    private func readStream(
        session: URLSession,
        messages: [TutorWireMessage],
        tools: [TutorToolSpec],
        continuation: AsyncThrowingStream<TutorStreamPiece, Error>.Continuation
    ) async throws {
        var request = try makeRequest(path: "chat/completions")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: TutorAPI.payload(model: chatModel, messages: messages, tools: tools, stream: true))
        let (bytes, response) = try await session.bytes(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw AIClientError.http(status: http.statusCode, message: "流式连接失败")
        }
        var decoder = TutorSSEDecoder()
        for try await line in bytes.lines {
            if let piece = decoder.consume(line) {
                continuation.yield(.text(piece))
            }
        }
        continuation.yield(.done(decoder.turn()))
    }
    #endif
}
