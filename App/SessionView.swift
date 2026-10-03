import SwiftUI
import ThaiLearnCore

struct SessionView: View {
    @Environment(AppModel.self) private var model
    @State private var revealed = false

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 22) {
                    if let session = model.active, session.isFinished {
                        finished
                    } else if let ref = model.active?.current {
                        card(ref)
                        if revealed {
                            grades
                        } else {
                            Button("看答案") { revealed = true }
                                .buttonStyle(.borderedProminent)
                                .tint(Ink.lacquer)
                                .keyboardShortcut(.space, modifiers: [])
                        }
                    }
                }
                .padding(28)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
        }
        .onChange(of: model.active?.index) { _, _ in
            revealed = false
        }
        .navigationTitle("这一轮")
    }

    private var header: some View {
        HStack {
            if let session = model.active {
                Text(session.positionLabel)
                    .font(.headline.monospacedDigit())
                if let ref = session.current {
                    Text("\(ref.kind.chinese) · \(ref.template.chinese)")
                        .foregroundStyle(Ink.muted)
                }
            }
            Spacer()
            Button("先停在这里") { model.closeSession() }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Ink.card)
        .overlay(alignment: .bottom) { Divider() }
    }

    @ViewBuilder
    private func card(_ ref: StudyRef) -> some View {
        CardShell {
            VStack(alignment: .leading, spacing: 14) {
                switch ref.kind {
                case .phrase:
                    if let phrase = model.catalog?.phrase(ref.id) {
                        phraseCard(phrase, template: ref.template)
                    }
                case .consonant:
                    if let consonant = model.catalog?.consonant(ref.id) {
                        consonantCard(consonant)
                    }
                case .vowel:
                    if let vowel = model.catalog?.vowel(ref.id) {
                        vowelCard(vowel)
                    }
                case .tone:
                    if let drill = model.catalog.flatMap({ ToneDrills.drill(id: ref.id, catalog: $0) }) {
                        toneCard(drill)
                    }
                case .word:
                    if let word = model.catalog?.word(ref.id) {
                        wordCard(word, template: ref.template)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func phraseCard(_ phrase: Phrase, template: CardTemplate) -> some View {
        if template == .production {
            Text(phrase.meaning)
                .font(.title2.bold())
                .frame(maxWidth: .infinity)
            Text("写出泰文")
                .font(.callout)
                .foregroundStyle(Ink.muted)
                .frame(maxWidth: .infinity)
        } else {
            HStack {
                Spacer()
                ThaiLine(text: phrase.thai)
                Spacer()
            }
            HStack {
                Spacer()
                PlayButton(text: phrase.spoken)
                Spacer()
            }
        }
        if revealed {
            if template == .production {
                ThaiLine(text: phrase.thai, size: 40)
                    .frame(maxWidth: .infinity)
                PlayButton(text: phrase.spoken)
                    .frame(maxWidth: .infinity)
            }
            Text(phrase.romanization)
                .font(.title3)
                .frame(maxWidth: .infinity)
            if template != .production {
                Text(phrase.meaning)
                    .font(.title3)
                    .frame(maxWidth: .infinity)
            }
            if let note = phrase.note {
                Text(note)
                    .font(.callout)
                    .foregroundStyle(Ink.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            DisclosureGroup("音节") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(phrase.syllables.enumerated()), id: \.offset) { _, syllable in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(syllable.thai)  \(syllable.roman)")
                            if let note = syllable.note {
                                Text(note)
                                    .font(.caption)
                                    .foregroundStyle(Ink.muted)
                            }
                        }
                    }
                }
                .padding(.top, 6)
            }
            .font(.callout)
        }
    }

    @ViewBuilder
    private func consonantCard(_ consonant: Consonant) -> some View {
        ThaiLine(text: consonant.symbol, size: 88)
            .frame(maxWidth: .infinity)
        Text("这个字母是哪一类，怎么读？")
            .font(.callout)
            .foregroundStyle(Ink.muted)
            .frame(maxWidth: .infinity)
        if revealed {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(consonant.consonantClass.chinese)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(consonant.consonantClass.tint.opacity(0.15), in: Capsule())
                    .foregroundStyle(consonant.consonantClass.tint)
                if consonant.obsolete {
                    Text("现在基本不用")
                        .font(.caption)
                        .foregroundStyle(Ink.muted)
                }
            }
            ThaiLine(text: consonant.nameThai, size: 28)
                .frame(maxWidth: .infinity)
            PlayButton(text: consonant.spoken)
                .frame(maxWidth: .infinity)
            Text(consonant.nameRoman)
                .font(.title3)
            Text(consonant.meaning)
                .font(.title3)
            Text(consonantLine(consonant))
                .foregroundStyle(Ink.muted)
            if let note = consonant.note {
                Text(note)
                    .font(.callout)
                    .foregroundStyle(Ink.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func vowelCard(_ vowel: Vowel) -> some View {
        ThaiLine(text: vowel.symbols, size: 56)
            .frame(maxWidth: .infinity)
        Text("这个元音怎么读？")
            .font(.callout)
            .foregroundStyle(Ink.muted)
            .frame(maxWidth: .infinity)
        if revealed {
            Text("\(vowel.lengthLabel) · \(vowel.roman)")
                .font(.title3)
                .frame(maxWidth: .infinity)
            Text(vowel.soundHint)
                .foregroundStyle(Ink.muted)
                .fixedSize(horizontal: false, vertical: true)
            ThaiLine(text: vowel.exampleThai, size: 32)
                .frame(maxWidth: .infinity)
            PlayButton(text: vowel.exampleThai)
                .frame(maxWidth: .infinity)
            Text("\(vowel.exampleRoman)  \(vowel.exampleMeaning)")
                .font(.title3)
            if let note = vowel.note {
                Text(note)
                    .font(.callout)
                    .foregroundStyle(Ink.muted)
            }
        }
    }

    @ViewBuilder
    private func toneCard(_ drill: ToneDrill) -> some View {
        Text(drill.consonantClass.chinese)
            .font(.title2.bold())
        Text("\(drill.toneMark.chinese) · \(drill.ending.chinese) · \(drill.length.chinese)")
            .font(.title3)
        Text("读第几声？")
            .font(.callout)
            .foregroundStyle(Ink.muted)
        if revealed {
            Text(drill.tone.chinese)
                .font(.title.bold())
            if let thai = drill.exampleThai {
                ThaiLine(text: thai, size: 36)
                if let roman = drill.exampleRoman, let meaning = drill.exampleMeaning {
                    Text("\(roman)  \(meaning)")
                        .foregroundStyle(Ink.muted)
                }
                if let spoken = drill.spoken {
                    PlayButton(text: spoken)
                }
            }
        }
    }

    @ViewBuilder
    private func wordCard(_ word: VocabWord, template: CardTemplate) -> some View {
        if template == .production {
            Text(word.meaning)
                .font(.title2.bold())
                .frame(maxWidth: .infinity)
            Text(word.topic)
                .font(.callout)
                .foregroundStyle(Ink.muted)
                .frame(maxWidth: .infinity)
        } else {
            ThaiLine(text: word.thai, size: 52)
                .frame(maxWidth: .infinity)
            PlayButton(text: word.spoken)
                .frame(maxWidth: .infinity)
        }
        if revealed {
            if template == .production {
                ThaiLine(text: word.thai, size: 44)
                    .frame(maxWidth: .infinity)
                PlayButton(text: word.spoken)
                    .frame(maxWidth: .infinity)
            } else {
                Text(word.meaning)
                    .font(.title3)
                    .frame(maxWidth: .infinity)
            }
            Text(word.romanization)
                .font(.title3)
                .frame(maxWidth: .infinity)
            Text("词频第 \(word.band) 档 · \(word.topic)")
                .font(.caption)
                .foregroundStyle(Ink.muted)
                .frame(maxWidth: .infinity)
        }
    }

    private var grades: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("这张怎么样")
                .font(.headline)
            HStack(spacing: 8) {
                gradeButton(.again, shortcut: "1")
                gradeButton(.hard, shortcut: "2")
                gradeButton(.good, shortcut: "3")
                gradeButton(.easy, shortcut: "4")
            }
        }
    }

    private func gradeButton(_ grade: Grade, shortcut: Character) -> some View {
        Button {
            model.grade(grade)
        } label: {
            VStack(spacing: 2) {
                Text(grade.title).font(.body.weight(.semibold))
                Text(intervalText(grade))
                    .font(.caption2)
                    .foregroundStyle(Ink.muted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
        .tint(grade == .good ? Ink.leaf : Ink.ink)
        .keyboardShortcut(KeyEquivalent(shortcut), modifiers: [])
    }

    private var finished: some View {
        CardShell {
            VStack(alignment: .leading, spacing: 10) {
                Text("今天先到这里")
                    .font(.title2.bold())
                Text("连续 \(model.progress.streak) 天。明天打开，到期的会自己排进来。")
                    .foregroundStyle(Ink.muted)
                Button("回到今天") { model.closeSession() }
                    .buttonStyle(.borderedProminent)
                    .tint(Ink.lacquer)
            }
        }
    }

    private func intervalText(_ grade: Grade) -> String {
        guard let session = model.active, let ref = session.current else { return grade.hint }
        let card = model.progress.cards[ref.cardKey]
        let label = StudySession.intervalLabel(
            for: grade,
            card: card,
            on: session.day,
            retention: model.progress.desiredRetention
        )
        return "\(grade.hint) · \(label)"
    }

    private func consonantLine(_ consonant: Consonant) -> String {
        var parts = ["声母 \(consonant.initial)"]
        if let final = consonant.final {
            parts.append("韵尾 \(final)")
        }
        if let note = consonant.finalNote {
            parts.append(note)
        }
        return parts.joined(separator: " · ")
    }
}
