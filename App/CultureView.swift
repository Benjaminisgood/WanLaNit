import SwiftUI
import ThaiLearnCore

struct CultureView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selectedID: String? = "culture-wai"

    private var notes: [CultureNote] {
        (model.catalog?.culture ?? []).sorted { $0.order < $1.order }
    }

    private var compact: Bool {
        #if os(iOS)
        sizeClass == .compact
        #else
        false
        #endif
    }

    var body: some View {
        Group {
            if compact {
                List(notes) { note in
                    NavigationLink(note.title) {
                        article(note)
                    }
                }
            } else {
                HStack(spacing: 0) {
                    List(notes, selection: $selectedID) { note in
                        Text(note.title)
                            .tag(Optional(note.id))
                            .padding(.vertical, 4)
                    }
                    .listStyle(.sidebar)
                    .frame(minWidth: 200, idealWidth: 240, maxWidth: 300)
                    if let note = notes.first(where: { $0.id == selectedID }) ?? notes.first {
                        article(note)
                    }
                }
            }
        }
        .navigationTitle("文化")
    }

    private func article(_ note: CultureNote) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(note.title)
                    .font(.title.bold())
                if model.progress.cultureLog[note.id]?.read == true {
                    Text("读过")
                        .font(.caption)
                        .foregroundStyle(Ink.leaf)
                }
                if let thai = note.thai {
                    Text(thai)
                        .font(.system(size: 36, design: .serif))
                    HStack {
                        if let roman = note.roman {
                            Text(roman)
                                .font(.title3)
                        }
                        PlayButton(text: thai, title: "听")
                    }
                }
                Text(note.body)
                    .font(.title3)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                if !note.phrases.isEmpty {
                    Text("相关的说法")
                        .font(.headline)
                    ForEach(Array(note.phrases.enumerated()), id: \.offset) { _, phrase in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(phrase.thai)
                                .font(.system(size: 22, design: .serif))
                            Text("\(phrase.romanization)  ·  \(phrase.meaning)")
                                .foregroundStyle(Ink.muted)
                            PlayButton(text: phrase.thai)
                        }
                    }
                }
                if !note.questions.isEmpty {
                    CultureQuiz(note: note)
                }
            }
            .padding(32)
            .frame(maxWidth: 680, alignment: .leading)
        }
        .onAppear { model.markCultureRead(note.id) }
    }
}

private struct CultureQuiz: View {
    @Environment(AppModel.self) private var model
    var note: CultureNote
    @State private var answers: [Int: Int] = [:]
    @State private var result = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("三道小题")
                .font(.headline)
            ForEach(Array(note.questions.enumerated()), id: \.offset) { index, question in
                VStack(alignment: .leading, spacing: 6) {
                    Text(question.prompt)
                    ForEach(Array(question.choices.enumerated()), id: \.offset) { choice, text in
                        Button(text) { answers[index] = choice }
                            .buttonStyle(.bordered)
                            .tint(answers[index] == choice ? Ink.leaf : Ink.ink)
                    }
                }
            }
            Button("对一下") {
                var correct = 0
                for (index, question) in note.questions.enumerated() where answers[index] == question.answer {
                    correct += 1
                }
                result = "对了 \(correct) / \(note.questions.count)。"
                model.recordCultureQuiz(id: note.id, correct: correct, asked: note.questions.count)
            }
            .buttonStyle(.borderedProminent)
            .tint(Ink.lacquer)
            if !result.isEmpty {
                Text(result)
            }
        }
    }
}
