import SwiftUI
import ThaiLearnCore

struct TutorView: View {
    @Environment(AppModel.self) private var model
    @State private var draft = ""
    @State private var voiceOn = false
    @State private var listenLanguage = "th"
    @State private var holding = false
    @State private var mic = MicCapture()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                usage
                plan
                if !model.tutorCards.isEmpty { cards }
                transcript
                if let exercise = model.tutorExercise {
                    TutorExerciseHost(exercise: exercise) { json in
                        model.submitTutorExercise(json)
                    }
                }
                if !model.tutorLive.isEmpty {
                    Text(model.tutorLive)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Ink.card, in: RoundedRectangle(cornerRadius: 12))
                }
                composer
                mistakes
                TutorMemoryEditor()
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .navigationTitle("AI 老师")
        .onAppear {
            model.noteTutorContext("AI 老师")
            model.consumeDailyLessonIfNeeded()
        }
        .onChange(of: model.tutorSpeakID) { _, id in
            guard voiceOn, let turn = model.progress.tutor.turns.last(where: { $0.id == id }), turn.role == "assistant" else { return }
            let auto = model.progress.tutor.voiceAutoContinue
            model.play(turn.text) {
                guard auto else { return }
                Task { await autoListen() }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI 老师")
                .font(.title.bold())
            Text("他按你的进度带一课：复习、新句子、当场改。没有钥匙时仍按同一条路线走，只是不聊天。")
                .foregroundStyle(Ink.muted)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("今天的课") { model.sendTutor("开始今天的课") }
                    .buttonStyle(.borderedProminent)
                    .tint(Ink.lacquer)
                    .disabled(model.tutorBusy)
                Button("记下这一课") { model.finishTutorLesson() }
                Stepper("大约 \(model.progress.tutor.minutesTarget) 分钟", value: Binding(
                    get: { model.progress.tutor.minutesTarget },
                    set: { model.setTutorMinutes($0) }
                ), in: 10...40, step: 5)
            }
        }
    }

    private var usage: some View {
        let tutor = model.progress.tutor
        return VStack(alignment: .leading, spacing: 6) {
            Text("今天 \(tutor.requests(on: model.today)) / \(tutor.requestCap) 次，约 \(tutor.tokens(on: model.today)) / \(tutor.tokenCap) tokens")
                .font(.caption)
                .foregroundStyle(Ink.muted)
            Picker("老师模型", selection: Binding(
                get: { model.progress.tutor.model },
                set: { model.setTutorModel($0) }
            )) {
                Text("跟随对话模型").tag("")
                Text("qwen-plus").tag("qwen-plus")
                Text("qwen-max").tag("qwen-max")
            }
            Text("通义千问的 qwen-plus 和 qwen-max 都能调用工具。qwen-max 更稳，也更贵。朗读仍用系统泰语。")
                .font(.caption)
                .foregroundStyle(Ink.muted)
        }
    }

    private var plan: some View {
        let week = model.progress.tutor.weekPlan
        return CardShell {
            VStack(alignment: .leading, spacing: 8) {
                Text("本周")
                    .font(.headline)
                if let week {
                    Text(week.weekOf)
                        .font(.caption)
                        .foregroundStyle(Ink.muted)
                    ForEach(week.goals, id: \.self) { goal in
                        Text("· \(goal)")
                    }
                    ForEach(week.milestones, id: \.self) { item in
                        Text(item)
                            .foregroundStyle(Ink.muted)
                    }
                } else {
                    Text("还没有周计划。")
                        .foregroundStyle(Ink.muted)
                }
                HStack {
                    Button("修订本周") { model.makeWeekPlan() }
                    if OfflineTutor.checkInDue(progress: model.progress, today: model.today) {
                        Button("每周核对") { model.weeklyCheckIn() }
                    }
                }
            }
        }
    }

    private var cards: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(model.tutorCards) { card in
                TutorTeachCardView(card: card)
            }
        }
    }

    private var transcript: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(model.progress.tutor.turns) { turn in
                VStack(alignment: .leading, spacing: 4) {
                    Text(turn.role == "user" ? "我" : "老师")
                        .font(.caption)
                        .foregroundStyle(Ink.muted)
                    Text(turn.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(turn.role == "user" ? Ink.paper : Ink.card, in: RoundedRectangle(cornerRadius: 12))
            }
            if model.tutorBusy && model.tutorLive.isEmpty {
                Text("老师在想…")
                    .foregroundStyle(Ink.muted)
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("问语法、用法，或让他改今天的安排", text: $draft, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...5)
            HStack {
                Button("发送") {
                    let text = draft
                    draft = ""
                    model.sendTutor(text)
                }
                .disabled(model.tutorBusy || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Toggle("语音", isOn: $voiceOn)
                Toggle("说完自动继续", isOn: Binding(
                    get: { model.progress.tutor.voiceAutoContinue },
                    set: { model.setTutorVoiceAuto($0) }
                ))
                Picker("识别", selection: $listenLanguage) {
                    Text("泰语").tag("th")
                    Text("中文").tag("zh")
                }
                .frame(maxWidth: 140)
            }
            Text(holding ? "正在听…" : "按住说话，松开就发送。识别默认通义 qwen3-asr-flash，失败再用系统。")
                .font(.caption)
                .foregroundStyle(Ink.muted)
            Text(holding ? "松开结束" : "按住说话")
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(holding ? Ink.lacquer.opacity(0.25) : Ink.card, in: Capsule())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !holding {
                                holding = true
                                Task { await beginListen() }
                            }
                        }
                        .onEnded { _ in
                            holding = false
                            Task { await endListen(send: true) }
                        }
                )
        }
    }

    private var mistakes: some View {
        let open = model.progress.tutor.unresolvedMistakes
        return VStack(alignment: .leading, spacing: 8) {
            Text("错题本")
                .font(.headline)
            if open.isEmpty {
                Text("还没有未掌握的错题。复习忘了、跟读偏低、打错的字会自己进来。")
                    .foregroundStyle(Ink.muted)
            } else {
                ForEach(Array(open.suffix(8))) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.thai)
                            Text(item.note)
                                .font(.caption)
                                .foregroundStyle(Ink.muted)
                        }
                        Spacer()
                        Button("已掌握") { model.resolveMistake(id: item.id) }
                    }
                }
            }
        }
    }

    private func autoListen() async {
        guard !holding else { return }
        await beginListen()
        try? await Task.sleep(nanoseconds: 4_000_000_000)
        guard !holding else { return }
        await endListen(send: true)
    }

    private func beginListen() async {
        guard await mic.requestAccess() else { return }
        try? mic.start()
    }

    private func endListen(send: Bool) async {
        let taken = mic.stop()
        let heard = await model.transcribe(samples: taken.samples, rate: taken.rate, language: listenLanguage)
        guard send, !heard.isEmpty else { return }
        model.sendTutor(heard)
    }
}

struct TutorAskSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("现在的画面：\(model.tutorContext)")
                    .font(.callout)
                    .foregroundStyle(Ink.muted)
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(model.progress.tutor.turns.suffix(8)) { turn in
                            Text("\(turn.role == "user" ? "我" : "老师")：\(turn.text)")
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if !model.tutorLive.isEmpty {
                            Text(model.tutorLive)
                        }
                    }
                }
                TextField("问这一屏、语法或文化", text: $draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                Button("发送") {
                    let text = draft
                    draft = ""
                    model.sendTutor(text)
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.tutorBusy)
            }
            .padding(20)
            .navigationTitle("问老师")
            .toolbar {
                Button("关闭") { dismiss() }
            }
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
    }
}

struct TutorMemoryEditor: View {
    @Environment(AppModel.self) private var model
    @State private var draft = ""

    var body: some View {
        CardShell {
            VStack(alignment: .leading, spacing: 8) {
                Text("老师记下的")
                    .font(.headline)
                Text("误解、兴趣、哪种讲法有效。只存在这台设备的进度里，可以改、可以删。")
                    .font(.caption)
                    .foregroundStyle(Ink.muted)
                if model.progress.tutor.notes.isEmpty {
                    Text("还没有笔记。")
                        .foregroundStyle(Ink.muted)
                }
                ForEach(model.progress.tutor.notes) { note in
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("笔记", text: Binding(
                            get: { note.text },
                            set: { model.updateTutorNote(id: note.id, text: $0) }
                        ), axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        Button("删除") { model.deleteTutorNote(id: note.id) }
                            .font(.caption)
                    }
                }
                TextField("添一句", text: $draft)
                    .textFieldStyle(.roundedBorder)
                Button("添加") {
                    model.addTutorNote(draft)
                    draft = ""
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

struct TutorTeachCardView: View {
    var card: TutorTeachCard

    var body: some View {
        CardShell {
            VStack(alignment: .leading, spacing: 8) {
                Text(card.thai)
                    .font(.system(size: 28, design: .serif))
                Text(card.romanization)
                Text(card.meaning)
                    .foregroundStyle(Ink.muted)
                Text(card.explanation)
                    .fixedSize(horizontal: false, vertical: true)
                toneRow
                PlayButton(text: card.thai, title: "听")
            }
        }
    }

    private var toneRow: some View {
        HStack(spacing: 6) {
            ForEach(["中调", "低调", "降调", "高调", "升调"], id: \.self) { name in
                Text(name)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(card.tone.contains(name) ? Ink.lacquer.opacity(0.25) : Ink.paper, in: Capsule())
            }
        }
    }
}

struct TutorExerciseHost: View {
    @Environment(AppModel.self) private var model
    var exercise: TutorExercise
    var onFinish: (String) -> Void
    @State private var session: ActiveSession?
    @State private var revealed = false
    @State private var correct = 0
    @State private var asked = 0
    @State private var typed = ""
    @State private var nodeID = "start"
    @State private var met: Set<String> = []
    @State private var quizPick: [Int: Int] = [:]
    @State private var shadowIndex = 0
    @State private var shadowScores: [Int] = []
    @State private var mic = MicCapture()

    var body: some View {
        CardShell {
            VStack(alignment: .leading, spacing: 10) {
                Text(exercise.title).font(.headline)
                Text(exercise.detail)
                    .foregroundStyle(Ink.muted)
                switch exercise.kind {
                case "review": reviewBody
                case "typing": typingBody
                case "shadowing": shadowBody
                case "roleplay": roleBody
                case "quiz": quizBody
                case "checkin": checkinBody
                default:
                    Button("继续") { onFinish("{\"correct\":0,\"asked\":0}") }
                }
            }
        }
        .onAppear(perform: prepare)
    }

    private var reviewBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let session, let ref = session.current, let catalog = model.catalog {
                let label = LearnerModel.label(for: ref.id, catalog: catalog)
                Text(revealed ? label : "想一想")
                    .font(.title3)
                Button(revealed ? "再藏起来" : "看答案") { revealed.toggle() }
                if revealed {
                    HStack {
                        gradeButton("忘了", .again)
                        gradeButton("模糊", .hard)
                        gradeButton("记得", .good)
                        gradeButton("简单", .easy)
                    }
                }
            } else {
                Text("这一轮没有到期的卡片。")
                Button("跳过") { onFinish(result(correct: 0, asked: 0)) }
            }
        }
    }

    private var typingBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(typingLesson?.text ?? "")
                .font(.system(size: 22, design: .serif))
            TextField("在这里打", text: $typed)
                .textFieldStyle(.roundedBorder)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
            Button("对一下") { finishTyping() }
        }
    }

    private var shadowBody: some View {
        let sentences = TutorJSON.strings(TutorJSON.object(exercise.payload), "sentences")
        return VStack(alignment: .leading, spacing: 8) {
            if sentences.indices.contains(shadowIndex) {
                Text(sentences[shadowIndex])
                    .font(.system(size: 22, design: .serif))
                Button("听") { model.play(sentences[shadowIndex]) }
                Button("我说完了") { Task { await finishShadow(sentences[shadowIndex], last: shadowIndex + 1 >= sentences.count) } }
            } else {
                Button("完成") { onFinish(result(correct: shadowScores.filter { $0 >= 80 }.count, asked: max(shadowScores.count, 1))) }
            }
        }
    }

    private var roleBody: some View {
        let scenario = currentScenario
        let node = scenario?.node(nodeID) ?? scenario?.script.first
        return VStack(alignment: .leading, spacing: 8) {
            if let scenario, let node {
                Text(node.speaker).font(.caption).foregroundStyle(Ink.muted)
                Text(node.thai).font(.system(size: 22, design: .serif))
                Text(node.meaning).foregroundStyle(Ink.muted)
                PlayButton(text: node.thai)
                if node.end {
                    Button("结束扮演") {
                        let marks = scenario.goals.map { ScenarioGoalMark(id: $0.id, done: met.contains($0.id)) }
                        let score = ScenarioCoach.score(scenario: scenario, marks: marks)
                        onFinish(TutorJSON.text(["correct": score, "asked": 100, "goals": Array(met), "score": score]))
                    }
                } else {
                    ForEach(Array(node.choices.enumerated()), id: \.offset) { _, choice in
                        Button(choice.thai) {
                            met.formUnion(choice.goals)
                            nodeID = choice.next
                        }
                        Text(choice.meaning).font(.caption).foregroundStyle(Ink.muted)
                    }
                }
            } else {
                Button("跳过") { onFinish(result(correct: 0, asked: 0)) }
            }
        }
    }

    private var quizBody: some View {
        let questions = quizQuestions
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(questions.enumerated()), id: \.offset) { index, question in
                Text(question.prompt).font(.headline)
                ForEach(Array(question.choices.enumerated()), id: \.offset) { choice, text in
                    Button(text) { quizPick[index] = choice }
                        .tint(quizPick[index] == choice ? Ink.leaf : Ink.ink)
                }
            }
            Button("交卷") {
                var hit = 0
                for (index, question) in questions.enumerated() where quizPick[index] == question.answer {
                    hit += 1
                }
                onFinish(result(correct: hit, asked: questions.count))
            }
        }
    }

    private var checkinBody: some View {
        let prompts = TutorJSON.strings(TutorJSON.object(exercise.payload), "prompts")
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(prompts, id: \.self) { prompt in
                Button(prompt) {
                    onFinish(TutorJSON.text(["checkIn": true, "correct": 1, "asked": 1, "choice": prompt]))
                }
            }
        }
    }

    private func gradeButton(_ title: String, _ grade: Grade) -> some View {
        Button(title) {
            guard var session else { return }
            let remembered = grade != .again
            model.tutorGrade(grade, session: &session)
            asked += 1
            if remembered { correct += 1 }
            revealed = false
            self.session = session
            if session.isFinished {
                onFinish(result(correct: correct, asked: asked))
            }
        }
    }

    private func prepare() {
        guard exercise.kind == "review", session == nil, let catalog = model.catalog else { return }
        let payload = TutorJSON.object(exercise.payload)
        let count = max(1, TutorJSON.int(payload, "count", fallback: 8))
        let deck = TutorJSON.string(payload, "deck")
        var plan = deck.isEmpty || deck == "due"
            ? StudySession.planToday(catalog: catalog, progress: model.progress, today: model.today)
            : StudySession.planDeck(deckID: deck, catalog: catalog, progress: model.progress, today: model.today)
        plan.items = Array(plan.items.prefix(count))
        guard !plan.items.isEmpty else { return }
        session = StudySession.start(plan)
    }

    private var typingLesson: TypingLesson? {
        guard let catalog = model.catalog else { return nil }
        let id = TutorJSON.string(TutorJSON.object(exercise.payload), "lesson")
        if id == "weak" { return TypingCourse.weakDrill(from: model.progress.typing) }
        let lessons = TypingCourse.lessons(in: catalog)
        return lessons.first { $0.id == id } ?? lessons.first { $0.id == "marks" } ?? lessons.first
    }

    private func finishTyping() {
        guard let lesson = typingLesson else {
            onFinish(result(correct: 0, asked: 0))
            return
        }
        let diff = TypingCompare.diff(expected: lesson.text, typed: typed)
        let score = TypingMetrics.score(correct: diff.correct, wrong: diff.wrong + diff.extra, seconds: 20)
        model.recordTyping(lesson: lesson.id, score: score, expected: lesson.text, typed: typed)
        let attempts = max(diff.correct + diff.wrong, 1)
        onFinish(result(correct: diff.correct, asked: attempts))
    }

    private func finishShadow(_ sentence: String, last: Bool) async {
        guard await mic.requestAccess() else { return }
        try? mic.start()
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        let taken = mic.stop()
        let heard = await model.transcribe(samples: taken.samples, rate: taken.rate, language: "th")
        let dictionary = (model.catalog?.words.map(\.thai) ?? []) + [sentence]
        let score = SpeakAlign.score(target: sentence, heard: heard, dictionary: dictionary).score
        model.saveSpeakAttempt(target: sentence, transcript: heard, score: score)
        shadowScores.append(score)
        if last {
            onFinish(TutorJSON.text([
                "correct": shadowScores.filter { $0 >= 80 }.count,
                "asked": shadowScores.count,
                "score": score,
                "expected": sentence,
                "heard": heard
            ]))
        } else {
            shadowIndex += 1
        }
    }

    private var currentScenario: Scenario? {
        let id = TutorJSON.string(TutorJSON.object(exercise.payload), "scenario")
        return model.catalog?.scenarios.first { $0.id == id } ?? model.catalog?.scenarios.sorted { $0.order < $1.order }.first
    }

    private var quizQuestions: [TutorQuizQuestion] {
        let raw = TutorJSON.object(exercise.payload)["questions"] as? [[String: Any]] ?? []
        return raw.compactMap { item in
            guard let prompt = item["prompt"] as? String, let choices = item["choices"] as? [String] else { return nil }
            let answer = item["answer"] as? Int ?? 0
            return TutorQuizQuestion(prompt: prompt, choices: choices, answer: answer)
        }
    }

    private func result(correct: Int, asked: Int) -> String {
        TutorJSON.text(["correct": correct, "asked": asked, "kind": exercise.kind])
    }
}
