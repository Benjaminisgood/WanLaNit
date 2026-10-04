import SwiftUI
import ThaiLearnCore

struct ScenarioView: View {
    @Environment(AppModel.self) private var model
    @State private var scenarioID: String?
    @State private var mode = "短语"
    @State private var lineIndex = 0
    @State private var dialogueID: String?
    @State private var answers: [Int: Int] = [:]
    @State private var quizNote = ""
    @State private var nodeID = "start"
    @State private var typedReply = ""
    @State private var scriptNote = ""
    @State private var metGoals: Set<String> = []
    @State private var scriptLines: [ScenarioTurn] = []
    @State private var aiTurns: [ScenarioTurn] = []
    @State private var coach: ScenarioCoachReply?
    @State private var usedFallback = false
    @State private var busy = false
    private let mic = MicCapture()

    private var scenarios: [Scenario] {
        (model.catalog?.scenarios ?? []).sorted { $0.order < $1.order }
    }

    private var scenario: Scenario? {
        scenarios.first { $0.id == scenarioID } ?? scenarios.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("场景")
                    .font(.title.bold())
                Text("默认用男生的 ผม 和 ครับ。女生的说法写在旁边，用来听懂。没有 AI 时走选择题；有钥匙时可以由对方扮演。")
                    .foregroundStyle(Ink.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if scenarios.isEmpty {
                    Text("场景还没有载入。")
                } else if let scenario {
                    Picker("场景", selection: Binding(
                        get: { scenario.id },
                        set: { scenarioID = $0; reset(scenarioID: $0) }
                    )) {
                        ForEach(scenarios) { item in
                            Text(item.title).tag(item.id)
                        }
                    }
                    Text(scenario.setting)
                        .foregroundStyle(Ink.muted)
                    goals(scenario)
                    Picker("练法", selection: $mode) {
                        Text("短语").tag("短语")
                        Text("示范").tag("示范")
                        Text("理解").tag("理解")
                        Text("扮演").tag("扮演")
                    }
                    .pickerStyle(.segmented)
                    switch mode {
                    case "示范": dialogue(scenario)
                    case "理解": quiz(scenario)
                    case "扮演": rolePlay(scenario)
                    default: phrases(scenario)
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .navigationTitle("场景")
        .onAppear {
            if scenarioID == nil { scenarioID = scenarios.first?.id }
        }
    }

    private func goals(_ scenario: Scenario) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("这一课要说到")
                .font(.headline)
            ForEach(scenario.goals) { goal in
                let done = metGoals.contains(goal.id) || (coach?.goals.contains { $0.id == goal.id && $0.done } ?? false)
                Label(goal.chinese, systemImage: done ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(done ? Ink.leaf : Ink.ink)
            }
        }
    }

    private func phrases(_ scenario: Scenario) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(scenario.phrases) { phrase in
                CardShell {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(phrase.thai)
                            .font(.system(size: 24, design: .serif))
                        Text(phrase.romanization)
                        Text(phrase.meaning)
                            .foregroundStyle(Ink.muted)
                        Text("女生会说：\(phrase.female)")
                            .font(.callout)
                            .foregroundStyle(Ink.muted)
                        HStack {
                            PlayButton(text: phrase.thai)
                            Button("加入复习") { model.addScenarioPhrase(phrase) }
                        }
                    }
                }
            }
        }
    }

    private func dialogue(_ scenario: Scenario) -> some View {
        let dialogue = scenario.dialogues.first { $0.id == dialogueID } ?? scenario.dialogues.first
        return VStack(alignment: .leading, spacing: 12) {
            Picker("对话", selection: Binding(
                get: { dialogue?.id ?? "" },
                set: { dialogueID = $0; lineIndex = 0 }
            )) {
                ForEach(scenario.dialogues) { item in
                    Text(item.title).tag(item.id)
                }
            }
            if let dialogue {
                ForEach(Array(dialogue.lines.enumerated()), id: \.element.id) { index, line in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(line.speaker)
                            .font(.caption)
                            .foregroundStyle(Ink.muted)
                        Text(line.thai)
                            .font(.system(size: 22, design: .serif))
                            .opacity(index <= lineIndex ? 1 : 0.35)
                        if index <= lineIndex {
                            Text("\(line.romanization)  ·  \(line.meaning)")
                                .foregroundStyle(Ink.muted)
                        }
                    }
                }
                HStack {
                    Button("听这一句") {
                        if let line = dialogue.lines[safe: lineIndex] ?? dialogue.lines.last {
                            model.play(line.thai)
                        }
                    }
                    .disabled(!model.canSpeak)
                    Button("下一句") {
                        lineIndex = min(lineIndex + 1, dialogue.lines.count - 1)
                        if let line = dialogue.lines[safe: lineIndex] {
                            model.play(line.thai)
                        }
                    }
                    .disabled(lineIndex >= dialogue.lines.count - 1)
                }
            }
        }
    }

    private func quiz(_ scenario: Scenario) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(scenario.questions.enumerated()), id: \.offset) { index, question in
                CardShell {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(question.prompt).font(.headline)
                        ForEach(Array(question.choices.enumerated()), id: \.offset) { choice, text in
                            Button(text) { answers[index] = choice }
                                .buttonStyle(.bordered)
                                .tint(answers[index] == choice ? Ink.leaf : Ink.ink)
                        }
                    }
                }
            }
            Button("对一下") { gradeQuiz(scenario) }
                .buttonStyle(.borderedProminent)
                .tint(Ink.lacquer)
            if !quizNote.isEmpty {
                Text(quizNote)
            }
        }
    }

    private func rolePlay(_ scenario: Scenario) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("没有对话钥匙时用下面的选择题。有通义或其他对话钥匙时，可以让对方按这个场景说话。")
                .font(.callout)
                .foregroundStyle(Ink.muted)
            if model.credential(for: .chat) != nil {
                aiRole(scenario)
            }
            scriptedRole(scenario)
        }
    }

    private func scriptedRole(_ scenario: Scenario) -> some View {
        let node = scenario.node(nodeID) ?? scenario.script.first
        return CardShell {
            VStack(alignment: .leading, spacing: 8) {
                Text("写好的分支")
                    .font(.headline)
                if let node {
                    Text(node.speaker)
                        .font(.caption)
                        .foregroundStyle(Ink.muted)
                    Text(node.thai)
                        .font(.system(size: 22, design: .serif))
                    Text(node.meaning)
                        .foregroundStyle(Ink.muted)
                    PlayButton(text: node.thai)
                    if node.end {
                        Text(scriptScore(scenario))
                        Button("再走一遍") { reset(scenarioID: scenario.id) }
                    } else {
                        ForEach(Array(node.choices.enumerated()), id: \.offset) { _, choice in
                            Button(choice.thai) { choose(choice, scenario: scenario) }
                                .buttonStyle(.bordered)
                            Text(choice.meaning)
                                .font(.caption)
                                .foregroundStyle(Ink.muted)
                        }
                        TextField("也可以自己打一句泰文", text: $typedReply)
                            .textFieldStyle(.roundedBorder)
                        HStack {
                            Button("发送打字") { submitTyped(scenario) }
                            Button("说一句") { listen(scenario) }
                        }
                    }
                }
                if !scriptNote.isEmpty {
                    Text(scriptNote)
                        .foregroundStyle(Ink.muted)
                }
                ForEach(scriptLines) { turn in
                    Text("\(turn.role == "user" ? "我" : "对方")：\(turn.thai)")
                        .font(.callout)
                }
            }
        }
    }

    private func aiRole(_ scenario: Scenario) -> some View {
        CardShell {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(scenario.persona.name) · \(scenario.persona.role)")
                    .font(.headline)
                Text("最多 \(scenario.persona.turnLimit) 轮。每轮可以改一句。")
                    .font(.caption)
                    .foregroundStyle(Ink.muted)
                if usedFallback {
                    Text("这一句来自写好的分支，模型没有接上。")
                        .font(.caption)
                        .foregroundStyle(Ink.lacquer)
                }
                ForEach(aiTurns) { turn in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(turn.role == "user" ? "我" : scenario.persona.name)
                            .font(.caption)
                            .foregroundStyle(Ink.muted)
                        Text(turn.thai)
                            .font(.system(size: 20, design: .serif))
                        if !turn.chinese.isEmpty {
                            Text(turn.chinese)
                                .foregroundStyle(Ink.muted)
                        }
                    }
                }
                if let correction = coach?.correction {
                    Text("改一下：\(correction.corrected)")
                    Text("\(correction.romanization)  ·  \(correction.note)")
                        .font(.caption)
                        .foregroundStyle(Ink.muted)
                }
                if coach?.finished == true {
                    Text(coach?.feedback ?? "")
                    Text("目标分数 \(ScenarioCoach.score(scenario: scenario, marks: coach?.goals ?? []))")
                    ForEach(coach?.review ?? [], id: \.self) { line in
                        HStack {
                            Text(line)
                            Button("复习") {
                                if let phrase = scenario.phrases.first(where: { line.contains($0.thai) || $0.thai.contains(line) }) {
                                    model.addScenarioPhrase(phrase)
                                }
                            }
                        }
                    }
                } else {
                    TextField("用泰文回复", text: $typedReply)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("发送") { sendAI(scenario, text: typedReply) }
                            .disabled(busy || typedReply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button("说一句") { listenAI(scenario) }
                            .disabled(busy)
                    }
                }
            }
        }
    }

    private func gradeQuiz(_ scenario: Scenario) {
        var correct = 0
        for (index, question) in scenario.questions.enumerated() where answers[index] == question.answer {
            correct += 1
        }
        quizNote = "对了 \(correct) / \(scenario.questions.count)。"
        model.recordScenarioQuiz(id: scenario.id, correct: correct, asked: scenario.questions.count)
    }

    private func choose(_ choice: ScenarioChoice, scenario: Scenario) {
        metGoals.formUnion(choice.goals)
        scriptLines.append(ScenarioTurn(id: UUID().uuidString, role: "user", thai: choice.thai, chinese: choice.meaning))
        nodeID = choice.next
        typedReply = ""
        scriptNote = ""
        if let node = scenario.node(choice.next) {
            scriptLines.append(ScenarioTurn(id: UUID().uuidString, role: "partner", thai: node.thai, chinese: node.meaning))
            model.play(node.thai)
            if node.end { finishScript(scenario) }
        }
    }

    private func submitTyped(_ scenario: Scenario) {
        guard let node = scenario.node(nodeID) else { return }
        let candidates = node.typed + node.choices.map(\.thai)
        guard ScenarioMatch.matches(typedReply, candidates: candidates) else {
            scriptNote = "还不太像。可以点一句，或再打一次。句尾用 ครับ。"
            return
        }
        metGoals.formUnion(node.typedGoals)
        scriptLines.append(ScenarioTurn(id: UUID().uuidString, role: "user", thai: typedReply, chinese: ""))
        nodeID = node.typedNext
        typedReply = ""
        scriptNote = ""
        if let next = scenario.node(node.typedNext) {
            scriptLines.append(ScenarioTurn(id: UUID().uuidString, role: "partner", thai: next.thai, chinese: next.meaning))
            model.play(next.thai)
            if next.end { finishScript(scenario) }
        }
    }

    private func finishScript(_ scenario: Scenario) {
        let marks = scenario.goals.map { ScenarioGoalMark(id: $0.id, done: metGoals.contains($0.id)) }
        let score = ScenarioCoach.score(scenario: scenario, marks: marks)
        scriptNote = "这趟 \(score) 分。"
        model.recordScenarioRole(id: scenario.id, score: score, goals: Array(metGoals))
    }

    private func scriptScore(_ scenario: Scenario) -> String {
        let marks = scenario.goals.map { ScenarioGoalMark(id: $0.id, done: metGoals.contains($0.id)) }
        return "目标分数 \(ScenarioCoach.score(scenario: scenario, marks: marks))。上面打勾的是已经说到的。"
    }

    private func sendAI(_ scenario: Scenario, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        typedReply = ""
        aiTurns.append(ScenarioTurn(id: UUID().uuidString, role: "user", thai: trimmed, chinese: ""))
        busy = true
        let history = aiTurns
        Task {
            let outcome = await model.scenarioTurn(scenario: scenario, history: history)
            usedFallback = outcome.usedFallback
            coach = outcome.reply
            aiTurns.append(ScenarioTurn(id: UUID().uuidString, role: "partner", thai: outcome.reply.thai, chinese: outcome.reply.chinese))
            for mark in outcome.reply.goals where mark.done {
                metGoals.insert(mark.id)
            }
            model.play(outcome.reply.thai)
            if outcome.reply.finished {
                model.recordScenarioRole(
                    id: scenario.id,
                    score: ScenarioCoach.score(scenario: scenario, marks: outcome.reply.goals),
                    goals: outcome.reply.goals.filter(\.done).map(\.id)
                )
            }
            busy = false
        }
    }

    private func listen(_ scenario: Scenario) {
        Task {
            guard await mic.requestAccess() else {
                scriptNote = "需要麦克风和语音识别权限。"
                return
            }
            try? mic.start()
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            let taken = mic.stop()
            let heard = await model.transcribe(samples: taken.samples, rate: taken.rate)
            typedReply = heard
            if !heard.isEmpty { submitTyped(scenario) }
        }
    }

    private func listenAI(_ scenario: Scenario) {
        Task {
            guard await mic.requestAccess() else { return }
            try? mic.start()
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            let taken = mic.stop()
            let heard = await model.transcribe(samples: taken.samples, rate: taken.rate)
            if !heard.isEmpty { sendAI(scenario, text: heard) }
        }
    }

    private func reset(scenarioID: String) {
        self.scenarioID = scenarioID
        lineIndex = 0
        dialogueID = nil
        answers = [:]
        quizNote = ""
        nodeID = "start"
        typedReply = ""
        scriptNote = ""
        metGoals = []
        scriptLines = []
        aiTurns = []
        coach = nil
        usedFallback = false
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
