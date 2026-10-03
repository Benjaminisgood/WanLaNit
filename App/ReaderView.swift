import SwiftUI
import ThaiLearnCore
import UniformTypeIdentifiers

struct ReaderView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedID: String?
    @State private var tokenID: Int?
    @State private var showPaste = false
    @State private var showURL = false
    @State private var showFile = false
    @State private var pasteTitle = ""
    @State private var pasteBody = ""
    @State private var urlText = ""
    private var pieces: [ReaderPiece] {
        let starters = (model.catalog?.starters ?? []).map {
            ReaderPiece(id: $0.id, title: $0.title, body: $0.body, source: "入门 \($0.level)")
        }
        let saved = model.progress.library.map {
            ReaderPiece(id: $0.id, title: $0.title, body: $0.body, source: $0.source)
        }
        return starters + saved
    }

    private var selected: ReaderPiece? {
        let id = selectedID ?? pieces.first?.id
        return pieces.first { $0.id == id }
    }

    var body: some View {
        HStack(spacing: 0) {
            List(pieces, selection: $selectedID) { piece in
                VStack(alignment: .leading, spacing: 2) {
                    Text(piece.title)
                    Text(piece.source)
                        .font(.caption)
                        .foregroundStyle(Ink.muted)
                }
                .tag(Optional(piece.id))
                .padding(.vertical, 4)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 200, idealWidth: 230, maxWidth: 280)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Button("粘贴文章") { showPaste = true }
                    Button("打开文本文件") { showFile = true }
                    Button("从网址抓取") { showURL = true }
                    if let importError = model.importMessage {
                        Text(importError)
                            .font(.caption)
                            .foregroundStyle(Ink.lacquer)
                    }
                }
                .padding(12)
            }

            if let selected, let catalog = model.catalog {
                reading(selected, catalog: catalog)
            } else {
                ContentUnavailableView("还没有文章", systemImage: "book")
            }
        }
        .navigationTitle("阅读")
        .onAppear {
            if selectedID == nil { selectedID = pieces.first?.id }
        }
        .onChange(of: model.progress.library.count) { _, _ in
            if let id = model.progress.library.last?.id {
                selectedID = id
            }
        }
        .sheet(isPresented: $showPaste) { pasteSheet }
        .sheet(isPresented: $showURL) { urlSheet }
        .fileImporter(isPresented: $showFile, allowedContentTypes: [.plainText]) { result in
            switch result {
            case .success(let url):
                model.importFile(url)
                selectedID = model.progress.library.last?.id
            case .failure:
                model.importMessage = "这个文件打不开。"
            }
        }
    }

    private func reading(_ piece: ReaderPiece, catalog: Catalog) -> some View {
        let dictionary = catalog.words.map(\.thai)
        let tokens = ThaiSegmenter.tokens(in: piece.body, dictionary: dictionary)
        let coverage = ReaderState.coverage(in: piece.body, catalog: catalog, progress: model.progress)
        let selectedToken = tokens.first { $0.id == tokenID }
        return HStack(alignment: .top, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VoiceSourceBar()
                    Text(piece.title).font(.title.bold())
                    Text("\(coverage.uniqueWords) 个不同的词 · 已认识 \(percent(coverage.fraction))")
                        .foregroundStyle(Ink.muted)
                    FlowLayout(spacing: 4) {
                        ForEach(tokens) { token in
                            tokenButton(token, catalog: catalog)
                        }
                    }
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let selectedToken, selectedToken.isWord {
                panel(selectedToken, tokens: tokens, catalog: catalog)
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
        } label: {
            Text(token.text)
                .font(.system(size: token.isWord ? 22 : 16, design: .serif))
                .foregroundStyle(color(shown.status, level: shown.level))
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

    private func panel(_ token: ReaderToken, tokens: [ReaderToken], catalog: Catalog) -> some View {
        let shown = ReaderState.display(thai: token.text, catalog: catalog, progress: model.progress)
        let word = catalog.word(thai: token.text)
        let note = model.progress.readerNotes.first { $0.thai == token.text }
        let sentence = ReaderState.sentence(around: token, in: tokens)
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(token.text)
                    .font(.system(size: 36, design: .serif))
                Text(word?.romanization ?? note?.romanization ?? "还没有罗马音")
                    .font(.title3)
                Text(word?.meaning ?? (note?.meaning.isEmpty == false ? note?.meaning : nil) ?? "词表里还没有")
                    .font(.title3)
                if let topic = word?.topic {
                    Text("\(topic) · 第 \(word?.band ?? 0) 档")
                        .font(.caption)
                        .foregroundStyle(Ink.muted)
                }
                Text(statusLine(shown.status, level: shown.level))
                    .foregroundStyle(Ink.muted)
                PlayButton(text: token.text)
                Text(sentence)
                    .font(.callout)
                    .foregroundStyle(Ink.ink)
                    .fixedSize(horizontal: false, vertical: true)
                statusButtons(token.text, current: shown.status, catalog: catalog)
                Button("加入复习") {
                    model.addWordToReview(thai: token.text, sentence: sentence)
                }
                .buttonStyle(.borderedProminent)
                .tint(Ink.lacquer)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Ink.card)
    }

    private func statusButtons(_ thai: String, current: WordMark, catalog: Catalog) -> some View {
        let shown = ReaderState.display(thai: thai, catalog: catalog, progress: model.progress)
        return VStack(alignment: .leading, spacing: 8) {
            Text("这个词的状态")
                .font(.headline)
            HStack {
                markButton("生词", thai: thai, status: .new, level: 0, on: current == .new)
                markButton("认识", thai: thai, status: .known, level: 5, on: current == .known)
                markButton("忽略", thai: thai, status: .ignored, level: 0, on: current == .ignored)
            }
            HStack {
                ForEach(1...5, id: \.self) { level in
                    markButton("\(level)", thai: thai, status: .learning, level: level, on: shown.status == .learning && shown.level == level)
                }
            }
        }
    }

    private func markButton(_ title: String, thai: String, status: WordMark, level: Int, on: Bool) -> some View {
        Button(title) {
            model.setWordMark(thai, status: status, level: level)
        }
        .buttonStyle(.bordered)
        .tint(on ? Ink.leaf : Ink.ink)
    }

    private func statusLine(_ status: WordMark, level: Int) -> String {
        switch status {
        case .new: return "生词"
        case .known: return "已经认识"
        case .ignored: return "忽略，不计入认识比例"
        case .learning: return "学习中 \(level) / 5"
        }
    }

    private func color(_ status: WordMark, level: Int) -> Color {
        switch status {
        case .new: return Ink.ink
        case .ignored: return Ink.line
        case .known: return Ink.leaf
        case .learning:
            return Ink.lacquer.opacity(0.45 + 0.1 * Double(max(level, 1)))
        }
    }

    private func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }

    private var pasteSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("粘贴文章").font(.title2.bold())
            TextField("标题", text: $pasteTitle)
                .textFieldStyle(.roundedBorder)
            TextEditor(text: $pasteBody)
                .font(.body)
                .frame(minHeight: 180)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Ink.line))
            HStack {
                Button("取消") { showPaste = false }
                Spacer()
                Button("加入书架") {
                    model.importPasted(title: pasteTitle, body: pasteBody)
                    selectedID = model.progress.library.last?.id
                    pasteTitle = ""
                    pasteBody = ""
                    showPaste = false
                }
                .disabled(pasteBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 460, minHeight: 320)
    }

    private var urlSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("从网址抓取").font(.title2.bold())
            Text("只取网页里的文字，不打开浏览器。")
                .foregroundStyle(Ink.muted)
            TextField("https://", text: $urlText)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("取消") { showURL = false }
                Spacer()
                Button("抓取") {
                    let raw = urlText
                    showURL = false
                    Task { await model.importRemote(raw) }
                }
                .disabled(URL(string: urlText) == nil)
            }
        }
        .padding(20)
        .frame(minWidth: 420)
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 600
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

private struct ReaderPiece: Identifiable, Hashable {
    var id: String
    var title: String
    var body: String
    var source: String
}
