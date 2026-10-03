import SwiftUI
import ThaiLearnCore

private enum PracticeMode: String, CaseIterable, Identifiable {
    case tap
    case aloud
    case shadow
    case quiz
    case dictation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tap: return "点词"
        case .aloud: return "朗读"
        case .shadow: return "跟读"
        case .quiz: return "理解"
        case .dictation: return "听写"
        }
    }
}

struct PassagePracticeView: View {
    @Environment(AppModel.self) private var model
    @Environment(SpeechService.self) private var speech
    @State private var level = 0
    @State private var selectedID: String?
    @State private var mode: PracticeMode = .tap
    @State private var tokenID: Int?
    @State private var showChinese = true
    @State private var sentenceIndex = 0
    @State private var rate = 0.82
    @State private var playing = false
    @State private var shadowReady = false
    @State private var picks: [Int] = []
    @State private var submitted = false
    @State private var dictIndex = 0
    @State private var dictTyped = ""
    @State private var dictSolved: Set<Int> = []
    @State private var reveal = false
    @State private var added = false

    var body: some View {
        if let catalog = model.catalog {
            loaded(catalog)
        } else {
            ContentUnavailableView("还没有短文", systemImage: "book")
        }
    }

    private func loaded(_ catalog: Catalog) -> some View {
        let passages = filtered(catalog)
        let passage = passages.first { $0.id == selectedID } ?? passages.first
        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Picker("级别", selection: $level) {
                    Text("全部").tag(0)
                    Text("1").tag(1)
                    Text("2").tag(2)
                    Text("3").tag(3)
                    Text("4").tag(4)
                }
                .pickerStyle(.segmented)
                .padding(12)
                List(passages, selection: $selectedID) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                        Text(listCaption(item))
                            .font(.caption)
                            .foregroundStyle(Ink.muted)
                    }
                    .tag(Optional(item.id))
                    .padding(.vertical, 4)
                }
                .listStyle(.sidebar)
            }
            .frame(minWidth: 200, idealWidth: 230, maxWidth: 280)

            if let passage {
                practice(passage, catalog: catalog)
            } else {
                ContentUnavailableView("这一级还没有短文", systemImage: "book")
            }
        }
        .navigationTitle("精读")
        .onAppear {
            if selectedID == nil { selectedID = passages.first?.id }
            if let id = selectedID ?? passages.first?.id {
                model.markPassageRead(id)
            }
        }
        .onChange(of: selectedID) { _, id in
            tokenID = nil
            sentenceIndex = 0
            dictIndex = 0
            dictTyped = ""
            dictSolved = []
            reveal = false
            submitted = false
            shadowReady = false
            added = false
            playing = false
            speech.stop()
            if let id {
                picks = Array(repeating: -1, count: catalog.passage(id)?.questions.count ?? 0)
                model.markPassageRead(id)
            }
        }
        .onChange(of: level) { _, _ in
            let next = filtered(catalog)
            if !next.contains(where: { $0.id == selectedID }) {
                selectedID = next.first?.id
            }
        }
        .onDisappear {
            speech.stop()
        }
    }

    private func filtered(_ catalog: Catalog) -> [ReadingPassage] {
        catalog.passages.filter { level == 0 || $0.level == level }
    }

    private func listCaption(_ item: ReadingPassage) -> String {
        var parts = ["第 \(item.level) 级", item.topic]
        if let log = model.progress.passageLog[item.id] {
            if log.asked > 0 { parts.append("理解 \(log.correct)/\(log.asked)") }
            if log.dictated > 0 { parts.append("听写 \(log.dictated) 句") }
        }
        return parts.joined(separator: " · ")
    }

    private func practice(_ passage: ReadingPassage, catalog: Catalog) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(passage.title).font(.title2.bold())
                    Text("第 \(passage.level) 级 · \(passage.topic)")
                        .foregroundStyle(Ink.muted)
                }
                Spacer()
                ForEach(PracticeMode.allCases) { item in
                    Button(item.title) {
                        mode = item
                        playing = false
                        shadowReady = false
                        speech.stop()
                    }
                    .buttonStyle(.bordered)
                    .tint(mode == item ? Ink.lacquer : Ink.ink)
                }
            }
            VoiceBanner()
            switch mode {
            case .tap:
                tapMode(passage, catalog: catalog)
            case .aloud:
                speakMode(passage, shadow: false)
            case .shadow:
                speakMode(passage, shadow: true)
            case .quiz:
                quizMode(passage)
            case .dictation:
                dictationMode(passage)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func tapMode(_ passage: ReadingPassage, catalog: Catalog) -> some View {
        let dictionary = catalog.words.map(\.thai) + passage.glosses.map(\.thai)
        let tokens = ThaiSegmenter.tokens(in: passage.paragraph, dictionary: dictionary)
        let selected = tokens.first { $0.id == tokenID }
        return HStack(alignment: .top, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    FlowLayout(spacing: 4) {
                        ForEach(tokens) { token in
                            tokenButton(token, catalog: catalog)
                        }
                    }
                    if showChinese {
                        Text(passage.chinese)
                            .foregroundStyle(Ink.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Button(showChinese ? "隐藏译文" : "显示译文") { showChinese.toggle() }
                        .buttonStyle(.bordered)
                    glossList(passage)
                }
                .padding(.trailing, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let selected, selected.isWord {
                wordPanel(selected, tokens: tokens, passage: passage, catalog: catalog)
                    .frame(width: 280)
            }
        }
    }

    private func tokenButton(_ token: ReaderToken, catalog: Catalog) -> some View {
        let shown = token.isWord
            ? ReaderState.display(thai: token.text, catalog: catalog, progress: model.progress)
            : (status: WordMark.new, level: 0)
        return Button {
            tokenID = token.isWord ? token.id : nil
            added = false
        } label: {
            Text(token.text)
                .font(.system(size: token.isWord ? 22 : 16, design: .serif))
                .foregroundStyle(statusColor(shown.status, level: shown.level))
                .padding(.horizontal, token.isWord ? 2 : 0)
                .padding(.vertical, 2)
                .background(
                    tokenID == token.id ? Ink.lacquer.opacity(0.12) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 4)
                )
        }
        .buttonStyle(.plain)
        .disabled(!token.isWord)
    }

    private func wordPanel(_ token: ReaderToken, tokens: [ReaderToken], passage: ReadingPassage, catalog: Catalog) -> some View {
        let shown = ReaderState.display(thai: token.text, catalog: catalog, progress: model.progress)
        let gloss = lookup(token.text, passage: passage, catalog: catalog)
        let sentence = ReaderState.sentence(around: token, in: tokens)
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(token.text)
                    .font(.system(size: 36, design: .serif))
                Text(gloss.roman)
                    .font(.title3)
                Text(gloss.meaning)
                    .font(.title3)
                Text(statusLine(shown.status, level: shown.level))
                    .foregroundStyle(Ink.muted)
                PlayButton(text: token.text)
                Text(sentence)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                Button("加入复习") {
                    model.addWordToReview(thai: token.text, sentence: sentence)
                    added = true
                }
                .buttonStyle(.borderedProminent)
                .tint(Ink.lacquer)
                if added {
                    Text("已加入复习。")
                        .foregroundStyle(Ink.leaf)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Ink.card)
    }

    private func glossList(_ passage: ReadingPassage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("这篇文章里的词").font(.headline)
            ForEach(passage.glosses, id: \.thai) { gloss in
                Text("\(gloss.thai)  \(gloss.romanization)  \(gloss.meaning)")
                    .font(.callout)
            }
        }
    }

    private func speakMode(_ passage: ReadingPassage, shadow: Bool) -> some View {
        let sentences = passage.sentences
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(shadow ? "听完一句就停住，你跟着读。" : "一句一句往下读。点到的那一句会亮起来。")
                    .foregroundStyle(Ink.muted)
                ForEach(Array(sentences.enumerated()), id: \.offset) { index, sentence in
                    Text(sentence)
                        .font(.system(size: 22, design: .serif))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            index == sentenceIndex ? Ink.lacquer.opacity(0.16) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                }
                if showChinese {
                    Text(passage.chinese)
                        .foregroundStyle(Ink.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack {
                    Text("语速")
                    Slider(value: $rate, in: 0.5...1.2)
                        .frame(maxWidth: 220)
                }
                HStack {
                    Button(playing ? "停止" : (shadow ? "播放这一句" : "从头朗读")) {
                        if playing {
                            playing = false
                            speech.stop()
                        } else if shadow {
                            speak(sentences, index: sentenceIndex, advance: false)
                        } else {
                            speak(sentences, index: 0, advance: true)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Ink.lacquer)
                    .disabled(sentences.isEmpty || !speech.hasThaiVoice)
                    if shadow {
                        Button("上一句") {
                            sentenceIndex = max(0, sentenceIndex - 1)
                            shadowReady = false
                            speech.stop()
                            playing = false
                        }
                        .disabled(sentenceIndex == 0)
                        Button("下一句") {
                            sentenceIndex = min(sentences.count - 1, sentenceIndex + 1)
                            shadowReady = false
                            speech.stop()
                            playing = false
                        }
                        .disabled(sentenceIndex >= sentences.count - 1)
                    }
                    Button(showChinese ? "隐藏译文" : "显示译文") { showChinese.toggle() }
                }
                if shadowReady {
                    Text("现在跟着读这一句。")
                        .foregroundStyle(Ink.leaf)
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
        }
    }

    private func quizMode(_ passage: ReadingPassage) -> some View {
        let log = model.progress.passageLog[passage.id]
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(passage.paragraph)
                    .font(.system(size: 20, design: .serif))
                    .fixedSize(horizontal: false, vertical: true)
                Text(passage.chinese)
                    .foregroundStyle(Ink.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if let log, log.asked > 0 {
                    Text("最好成绩 \(log.correct)/\(log.asked)")
                        .foregroundStyle(Ink.muted)
                }
                ForEach(passage.questions.indices, id: \.self) { index in
                    questionBlock(passage.questions[index], index: index)
                }
                Button("交卷") {
                    let correct = score(passage)
                    submitted = true
                    model.recordPassageQuiz(id: passage.id, correct: correct, asked: passage.questions.count)
                }
                .buttonStyle(.borderedProminent)
                .tint(Ink.lacquer)
                .disabled(submitted || picks.count != passage.questions.count || picks.contains(-1))
                if submitted {
                    Text("这次对了 \(score(passage)) / \(passage.questions.count)。")
                        .foregroundStyle(Ink.leaf)
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
        }
        .onAppear {
            if picks.count != passage.questions.count {
                picks = Array(repeating: -1, count: passage.questions.count)
            }
        }
    }

    private func questionBlock(_ question: PassageQuestion, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question.prompt).font(.headline)
            ForEach(question.choices.indices, id: \.self) { choice in
                Button {
                    guard !submitted, picks.indices.contains(index) else { return }
                    picks[index] = choice
                } label: {
                    HStack {
                        Text(question.choices[choice])
                        Spacer()
                        if submitted, choice == question.answer {
                            Image(systemName: "checkmark")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .tint(choiceTint(question: question, index: index, choice: choice))
            }
        }
    }

    private func choiceTint(question: PassageQuestion, index: Int, choice: Int) -> Color {
        guard picks.indices.contains(index), picks[index] == choice else { return Ink.ink }
        if !submitted { return Ink.lacquer }
        return choice == question.answer ? Ink.leaf : Ink.lacquer
    }

    private func score(_ passage: ReadingPassage) -> Int {
        passage.questions.indices.reduce(0) { total, index in
            guard picks.indices.contains(index) else { return total }
            return total + (picks[index] == passage.questions[index].answer ? 1 : 0)
        }
    }

    private func dictationMode(_ passage: ReadingPassage) -> some View {
        let sentences = passage.sentences
        let index = min(dictIndex, max(sentences.count - 1, 0))
        let expected = sentences.indices.contains(index) ? sentences[index] : ""
        let typed = model.progress.typing.qwertyFallback ? TypingInput.thai(fromQWERTY: dictTyped) : dictTyped
        let diff = TypingCompare.diff(expected: expected, typed: typed)
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("听一句，再把它打出来。声调符号和元音要分开打。")
                    .foregroundStyle(Ink.muted)
                Text("第 \(index + 1) / \(max(sentences.count, 1)) 句 · 这篇对了 \(dictSolved.count) 句")
                if let log = model.progress.passageLog[passage.id], log.dictated > 0 {
                    Text("记录里最好是 \(log.dictated) 句。")
                        .foregroundStyle(Ink.muted)
                }
                if reveal || diff.finished {
                    Text(expected)
                        .font(.system(size: 22, design: .serif))
                }
                dictationMarks(diff)
                TextField("在这里打泰文", text: Binding(
                    get: { dictTyped },
                    set: { raw in
                        let next = model.progress.typing.qwertyFallback ? TypingInput.thai(fromQWERTY: raw) : raw
                        dictTyped = next
                        let result = TypingCompare.diff(expected: expected, typed: next)
                        guard result.finished else { return }
                        dictSolved.insert(index)
                        model.recordPassageDictation(id: passage.id, completed: dictSolved.count)
                    }
                ))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 22, design: .serif))
                    .autocorrectionDisabled()
                if diff.focus?.status == .wrong {
                    Text("这个字不对。退回再打。")
                        .foregroundStyle(Ink.lacquer)
                }
                if diff.finished {
                    Text("这一句对了。")
                        .foregroundStyle(Ink.leaf)
                }
                if model.progress.typing.qwertyFallback {
                    Text("正在用打字课里的英文字母键位。")
                        .font(.caption)
                        .foregroundStyle(Ink.muted)
                }
                HStack {
                    Button("听这一句") {
                        speak(sentences, index: index, advance: false)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Ink.lacquer)
                    .disabled(!speech.hasThaiVoice || expected.isEmpty)
                    Button("上一句") { moveDictation(to: index - 1, count: sentences.count) }
                        .disabled(index == 0)
                    Button("下一句") { moveDictation(to: index + 1, count: sentences.count) }
                        .disabled(index >= sentences.count - 1)
                    Button(reveal ? "隐藏原文" : "看原文") { reveal.toggle() }
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
        }
    }

    private func dictationMarks(_ diff: TypingDiff) -> some View {
        FlowLayout(spacing: 4) {
            ForEach(Array(diff.marks.enumerated()), id: \.offset) { _, mark in
                Text(mark.status == .pending ? "·" : KedmaneeKeyboard.label(for: mark.typed ?? mark.expected))
                    .font(.system(size: 22, design: .serif))
                    .foregroundStyle(markColor(mark.status))
            }
        }
    }

    private func moveDictation(to index: Int, count: Int) {
        guard count > 0 else { return }
        dictIndex = min(max(0, index), count - 1)
        dictTyped = ""
        reveal = false
        speech.stop()
        playing = false
    }

    private func speak(_ sentences: [String], index: Int, advance: Bool) {
        guard sentences.indices.contains(index) else {
            playing = false
            return
        }
        sentenceIndex = index
        shadowReady = false
        let text = sentences[index]
        playing = true
        let started = speech.speak(text, rateScale: rate) {
            DispatchQueue.main.async {
                playing = false
                if advance, index + 1 < sentences.count {
                    speak(sentences, index: index + 1, advance: true)
                } else if !advance {
                    shadowReady = true
                }
            }
        }
        if !started { playing = false }
    }

    private func lookup(_ thai: String, passage: ReadingPassage, catalog: Catalog) -> (roman: String, meaning: String) {
        if let word = catalog.word(thai: thai) {
            return (word.romanization, word.meaning)
        }
        if let gloss = passage.glosses.first(where: { $0.thai == thai }) {
            return (gloss.romanization, gloss.meaning)
        }
        return ("还没有罗马音", "词表里还没有")
    }

    private func statusLine(_ status: WordMark, level: Int) -> String {
        switch status {
        case .new: return "生词"
        case .known: return "已经认识"
        case .ignored: return "忽略"
        case .learning: return "学习中 \(level) / 5"
        }
    }

    private func statusColor(_ status: WordMark, level: Int) -> Color {
        switch status {
        case .new: return Ink.ink
        case .ignored: return Ink.line
        case .known: return Ink.leaf
        case .learning:
            return Ink.lacquer.opacity(0.45 + 0.1 * Double(max(level, 1)))
        }
    }

    private func markColor(_ status: TypingMark) -> Color {
        switch status {
        case .pending: return Ink.muted
        case .correct: return Ink.leaf
        case .wrong: return Ink.lacquer
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
