import SwiftUI
import ThaiLearnCore

private enum AIMode: String, CaseIterable, Identifiable {
    case shadow
    case exercises
    case grade
    case chat
    case setup

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shadow: return "跟读打分"
        case .exercises: return "出题"
        case .grade: return "批改"
        case .chat: return "对话"
        case .setup: return "设置"
        }
    }
}

struct AIPracticeView: View {
    @Environment(AppModel.self) private var model
    @State private var mode: AIMode = .shadow
    @State private var mic = MicCapture()
    @State private var recording = false
    @State private var sentence = ""
    @State private var transcript = ""
    @State private var result: SpeakScore?
    @State private var feedback = ""
    @State private var topic = "日常生活"
    @State private var exercises: [AIExercise] = []
    @State private var exerciseNote = ""
    @State private var answers: [String: String] = [:]
    @State private var checks: [String: String] = [:]
    @State private var draft = ""
    @State private var correction: AICorrection?
    @State private var chatDraft = ""
    @State private var busy = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("AI 练习")
                    .font(.title2.bold())
                Text(model.credentials.isEmpty
                     ? "还没有钥匙。跟读、本地出题和系统朗读现在就能用。云端出题、批改和对话要先在「设置」里导入。"
                     : "钥匙在钥匙串里。今天用了 \(model.progress.ai.usage.count(on: model.today)) / \(model.progress.ai.usage.dailyCap) 次。")
                    .foregroundStyle(Ink.muted)
                    .fixedSize(horizontal: false, vertical: true)
                VoiceSourceBar()
                HStack {
                    ForEach(AIMode.allCases) { item in
                        Button(item.title) { mode = item }
                            .buttonStyle(.bordered)
                            .tint(mode == item ? Ink.lacquer : Ink.ink)
                    }
                }
                if let notice = model.aiNotice, !notice.isEmpty {
                    Text(notice)
                        .font(.callout)
                        .foregroundStyle(Ink.muted)
                }
                switch mode {
                case .shadow: shadow
                case .exercises: exerciseList
                case .grade: grading
                case .chat: dialogue
                case .setup: AISettingsView()
                }
            }
            .padding(24)
            .frame(maxWidth: 820, alignment: .leading)
        }
        .navigationTitle("AI 练习")
        .onAppear {
            if sentence.isEmpty { sentence = sampleSentences.first ?? "สวัสดีครับ" }
        }
    }

    private var sampleSentences: [String] {
        (model.catalog?.phrases ?? [])
            .sorted { $0.order < $1.order }
            .map(\.thai)
            .filter { (4...40).contains($0.unicodeScalars.count) }
            .prefix(8)
            .map { $0 }
    }

    private var shadow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("先听一句，再自己说。分数按转写和原句对齐，不是在分析你的声波。")
                .foregroundStyle(Ink.muted)
            Picker("句子", selection: $sentence) {
                ForEach(sampleSentences, id: \.self) { line in
                    Text(line).tag(line)
                }
            }
            Text(sentence)
                .font(.system(size: 28, design: .serif))
            HStack {
                Button("播放") { model.play(sentence) }
                    .disabled(!model.canSpeak)
                Button(recording ? "停止并打分" : "开始说") { toggleRecord() }
                    .buttonStyle(.borderedProminent)
                    .tint(Ink.lacquer)
                    .disabled(busy && !recording)
            }
            TimelineView(.animation(minimumInterval: 0.08, paused: !recording)) { _ in
                let level = mic.currentLevel()
                RoundedRectangle(cornerRadius: 4)
                    .fill(Ink.leaf)
                    .frame(width: max(8, 280 * level), height: 10)
            }
            if !transcript.isEmpty {
                Text("听到：\(transcript)")
            }
            if let result {
                Text("\(result.score) 分")
                    .font(.title3.bold())
                FlowLayout(spacing: 6) {
                    ForEach(Array(result.pieces.enumerated()), id: \.offset) { _, piece in
                        Text(piece.text)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(markColor(piece.status).opacity(0.18), in: RoundedRectangle(cornerRadius: 4))
                    }
                }
                Text(result.note)
                    .font(.callout)
                    .foregroundStyle(Ink.muted)
                Button("请 AI 用中文说说") {
                    let target = sentence
                    let heard = transcript
                    Task { feedback = await model.explainSpeech(target: target, transcript: heard) }
                }
                .disabled(model.credential(for: .chat) == nil)
            }
            if !feedback.isEmpty {
                Text(feedback)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !model.progress.ai.attempts.isEmpty {
                Text("最近的跟读")
                    .font(.headline)
                ForEach(model.progress.ai.attempts.suffix(5).reversed()) { attempt in
                    Text("\(attempt.score) 分 · \(attempt.target)")
                        .font(.callout)
                }
            }
        }
    }

    private var exerciseList: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("话题，例如食物、旅行", text: $topic)
                .textFieldStyle(.roundedBorder)
            Button(busy ? "正在出题…" : "出一组题") { makeExercises() }
                .buttonStyle(.borderedProminent)
                .tint(Ink.lacquer)
                .disabled(busy)
            if !exerciseNote.isEmpty {
                Text(exerciseNote)
                    .foregroundStyle(Ink.muted)
            }
            ForEach(exercises) { exercise in
                exerciseCard(exercise)
            }
        }
    }

    private func exerciseCard(_ exercise: AIExercise) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(kindTitle(exercise.kind))
                .font(.caption)
                .foregroundStyle(Ink.muted)
            Text(exercise.prompt)
                .font(.headline)
            if exercise.kind == .listening {
                Button("听") { model.play(exercise.thai.isEmpty ? exercise.answer : exercise.thai) }
                    .disabled(!model.canSpeak)
            } else if !exercise.thai.isEmpty && exercise.kind != .toThai {
                Text(exercise.thai)
                    .font(.system(size: 22, design: .serif))
            }
            if !exercise.chinese.isEmpty && exercise.kind != .toChinese {
                Text(exercise.chinese)
                    .foregroundStyle(Ink.muted)
            }
            TextField("你的答案", text: Binding(
                get: { answers[exercise.id] ?? "" },
                set: { answers[exercise.id] = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            HStack {
                Button("对一下") { checks[exercise.id] = judge(exercise) }
                Button("听我的") { listen(into: exercise.id) }
            }
            if let line = checks[exercise.id] {
                Text(line)
                    .foregroundStyle(Ink.leaf)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ink.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Ink.line, lineWidth: 1))
    }

    private var grading: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("打或说一段泰文。有钥匙时会改句子、给罗马音和中文说明；没有钥匙时只标出词表里认识的词。")
                .foregroundStyle(Ink.muted)
            TextField("在这里打泰文或中文", text: $draft, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
            HStack {
                Button("听我的") { listen(intoDraft: true) }
                Button(busy ? "正在批改…" : "批改") { correct() }
                    .buttonStyle(.borderedProminent)
                    .tint(Ink.lacquer)
                    .disabled(busy || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if let correction {
                Text(correction.corrected)
                    .font(.system(size: 24, design: .serif))
                Text(correction.romanization)
                Text(correction.explanation)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(correction.score) 分")
                Button("听改后的") { model.play(correction.corrected) }
                    .disabled(!model.canSpeak)
            }
        }
    }

    private var dialogue: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("一个泰语对话伙伴。难度和中文提示可以改。每句都能听。")
                .foregroundStyle(Ink.muted)
            Picker("难度", selection: Binding(
                get: { model.progress.ai.difficulty },
                set: { model.setAIDifficulty($0) }
            )) {
                Text("入门").tag("入门")
                Text("日常").tag("日常")
                Text("随便聊").tag("随便聊")
            }
            .frame(maxWidth: 240)
            Toggle("显示中文", isOn: Binding(
                get: { model.progress.ai.showHints },
                set: { model.setAIHints($0) }
            ))
            ForEach(model.progress.ai.dialogue) { turn in
                VStack(alignment: .leading, spacing: 4) {
                    Text(turn.role == "assistant" ? "对方" : "我")
                        .font(.caption)
                        .foregroundStyle(Ink.muted)
                    Text(turn.thai)
                        .font(.system(size: 20, design: .serif))
                    if model.progress.ai.showHints, !turn.chinese.isEmpty {
                        Text(turn.chinese)
                            .foregroundStyle(Ink.muted)
                    }
                    if turn.role == "assistant" {
                        Button("听") { model.play(turn.thai) }
                            .disabled(!model.canSpeak)
                    }
                }
            }
            TextField("用泰文或中文说一句", text: $chatDraft)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("发送") { sendChat() }
                    .buttonStyle(.borderedProminent)
                    .tint(Ink.lacquer)
                    .disabled(busy)
                Button("说话发送") { listen(intoChat: true) }
                Button("清空") { model.clearDialogue() }
            }
            if model.credential(for: .chat) == nil {
                Text("没有对话钥匙时发不出去。可以先到「设置」导入，或者去句子里朗读。")
                    .font(.callout)
                    .foregroundStyle(Ink.muted)
            }
        }
    }

    private func toggleRecord() {
        if recording {
            recording = false
            let taken = mic.stop()
            busy = true
            let target = sentence
            Task {
                let heard = await model.transcribe(samples: taken.samples, rate: taken.rate)
                let score = SpeakAlign.score(
                    target: target,
                    heard: heard,
                    dictionary: model.catalog?.words.map(\.thai) ?? []
                )
                transcript = heard
                result = score
                model.saveSpeakAttempt(target: target, transcript: heard, score: score.score)
                busy = false
            }
        } else {
            Task {
                let allowed = await mic.requestAccess()
                guard allowed else {
                    model.aiNotice = "需要麦克风和语音识别权限。请在系统设置里允许 วันละนิด。"
                    return
                }
                do {
                    try mic.start()
                    recording = true
                } catch {
                    model.aiNotice = "麦克风没有打开。"
                }
            }
        }
    }

    private func makeExercises() {
        busy = true
        let chosen = topic
        Task {
            let made = await model.generateExercises(topic: chosen)
            exercises = made.0.exercises
            exerciseNote = made.1
            busy = false
        }
    }

    private func correct() {
        busy = true
        let text = draft
        Task {
            correction = await model.grade(text: text)
            busy = false
        }
    }

    private func sendChat() {
        let text = chatDraft
        chatDraft = ""
        busy = true
        Task {
            await model.sendChat(text)
            busy = false
        }
    }

    private func listen(into id: String) {
        Task {
            let allowed = await mic.requestAccess()
            guard allowed else { return }
            try? mic.start()
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            let taken = mic.stop()
            let heard = await model.transcribe(samples: taken.samples, rate: taken.rate)
            answers[id] = heard
        }
    }

    private func listen(intoDraft: Bool) {
        Task {
            let allowed = await mic.requestAccess()
            guard allowed else { return }
            try? mic.start()
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            let taken = mic.stop()
            draft = await model.transcribe(samples: taken.samples, rate: taken.rate)
        }
    }

    private func listen(intoChat: Bool) {
        Task {
            let allowed = await mic.requestAccess()
            guard allowed else { return }
            try? mic.start()
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            let taken = mic.stop()
            let heard = await model.transcribe(samples: taken.samples, rate: taken.rate)
            guard !heard.isEmpty else { return }
            await model.sendChat(heard)
        }
    }

    private func judge(_ exercise: AIExercise) -> String {
        let given = (answers[exercise.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !given.isEmpty else { return "先写一个答案。" }
        if exercise.kind == .toChinese {
            let answer = exercise.answer.trimmingCharacters(in: .whitespacesAndNewlines)
            let hit = given.contains(answer) || answer.contains(given)
            return hit ? "意思接近。参考：\(answer)" : "参考答案：\(answer)"
        }
        let score = SpeakAlign.score(
            target: exercise.answer,
            heard: given,
            dictionary: model.catalog?.words.map(\.thai) ?? [exercise.answer]
        )
        return "\(score.score) 分。参考：\(exercise.answer)。\(score.note)"
    }

    private func kindTitle(_ kind: AIExercise.Kind) -> String {
        switch kind {
        case .fillBlank: return "填空"
        case .toThai: return "中译泰"
        case .toChinese: return "泰译中"
        case .listening: return "听写"
        case .dialogue: return "小对话"
        }
    }

    private func markColor(_ status: SpeakMark) -> Color {
        switch status {
        case .match: return Ink.leaf
        case .tone: return Ink.river
        case .wrong, .missing: return Ink.lacquer
        case .extra: return Ink.muted
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 640
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}
