import SwiftUI
import ThaiLearnCore

struct ScriptView: View {
    @Environment(AppModel.self) private var model
    @State private var page = ScriptPage.consonants

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("文字", selection: $page) {
                ForEach(ScriptPage.allCases) { page in
                    Text(page.title).tag(page)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 28)
            .padding(.top, 18)
            .frame(maxWidth: 520, alignment: .leading)

            switch page {
            case .consonants:
                ConsonantBrowser()
            case .vowels:
                VowelBrowser()
            case .rules:
                ToneHelper()
            }
        }
        .navigationTitle("文字")
    }
}

private enum ScriptPage: String, CaseIterable, Identifiable {
    case consonants
    case vowels
    case rules

    var id: String { rawValue }
    var title: String {
        switch self {
        case .consonants: return "辅音"
        case .vowels: return "元音"
        case .rules: return "声调规则"
        }
    }
}

private struct ConsonantBrowser: View {
    @Environment(AppModel.self) private var model
    @State private var selectedID: String? = "ko-kai"

    private var consonants: [Consonant] {
        (model.catalog?.consonants ?? []).sorted { $0.order < $1.order }
    }

    var body: some View {
        HStack(spacing: 0) {
            List(selection: $selectedID) {
                ForEach(ConsonantClass.allCases, id: \.self) { klass in
                    Section(klass.chinese) {
                        ForEach(consonants.filter { $0.consonantClass == klass }) { consonant in
                            HStack {
                                Text(consonant.symbol)
                                    .font(.system(size: 22, design: .serif))
                                    .frame(width: 36, alignment: .leading)
                                Text(consonant.nameThai)
                                if consonant.obsolete {
                                    Text("旧")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Ink.line, in: Capsule())
                                }
                            }
                            .tag(Optional(consonant.id))
                        }
                    }
                }
            }
            .frame(minWidth: 240, idealWidth: 300, maxWidth: 360)

            if let consonant = consonants.first(where: { $0.id == selectedID }) ?? consonants.first {
                ScrollView {
                    ConsonantDetail(consonant: consonant)
                        .padding(28)
                        .frame(maxWidth: 640, alignment: .leading)
                }
            }
        }
    }
}

private struct ConsonantDetail: View {
    var consonant: Consonant

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(consonant.symbol)
                    .font(.system(size: 80, weight: .regular, design: .serif))
                VStack(alignment: .leading, spacing: 6) {
                    Text(consonant.consonantClass.chinese)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(consonant.consonantClass.tint.opacity(0.15), in: Capsule())
                        .foregroundStyle(consonant.consonantClass.tint)
                    Text("第 \(consonant.order) 个")
                        .font(.callout)
                        .foregroundStyle(Ink.muted)
                }
            }
            Text(consonant.nameThai)
                .font(.system(size: 32, design: .serif))
            Text("\(consonant.nameRoman)  ·  \(consonant.meaning)")
                .font(.title3)
            PlayButton(text: consonant.nameThai, title: "听名字")
            Text(soundLine)
                .fixedSize(horizontal: false, vertical: true)
            if let note = consonant.note {
                Text(note)
                    .foregroundStyle(Ink.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("前两周可以先不背字母。第 15 天起，每天的练习会带几个进来。这里随时能翻。")
                .font(.callout)
                .foregroundStyle(Ink.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var soundLine: String {
        var parts = ["声母 \(consonant.initial)"]
        if let final = consonant.final {
            parts.append("做韵尾时是 \(final)")
        } else {
            parts.append("一般不做韵尾")
        }
        if let note = consonant.finalNote {
            parts.append(note)
        }
        if consonant.obsolete {
            parts.append("废字母，看到认得就行")
        }
        return parts.joined(separator: "。") + "。"
    }
}

private struct VowelBrowser: View {
    @Environment(AppModel.self) private var model
    @State private var selectedID: String? = "v-a"

    private var vowels: [Vowel] {
        (model.catalog?.vowels ?? []).sorted { $0.order < $1.order }
    }

    var body: some View {
        HStack(spacing: 0) {
            List(vowels, selection: $selectedID) { vowel in
                HStack {
                    Text(vowel.symbols)
                        .font(.system(size: 18, design: .serif))
                    Spacer()
                    Text(vowel.roman)
                        .foregroundStyle(Ink.muted)
                }
                .tag(Optional(vowel.id))
            }
            .frame(minWidth: 240, idealWidth: 300, maxWidth: 360)

            if let vowel = vowels.first(where: { $0.id == selectedID }) ?? vowels.first {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(vowel.symbols)
                            .font(.system(size: 56, design: .serif))
                        Text("\(vowel.lengthLabel)元音 · \(vowel.roman)")
                            .font(.title3)
                        Text(vowel.soundHint)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(vowel.exampleThai)
                            .font(.system(size: 36, design: .serif))
                        Text("\(vowel.exampleRoman)  ·  \(vowel.exampleMeaning)")
                            .font(.title3)
                        PlayButton(text: vowel.exampleThai, title: "听例子")
                        if let note = vowel.note {
                            Text(note)
                                .foregroundStyle(Ink.muted)
                        }
                        Text("◌ 的位置放辅音。同一个元音，开元音和闭音节的写法常常不一样。")
                            .font(.callout)
                            .foregroundStyle(Ink.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(28)
                    .frame(maxWidth: 640, alignment: .leading)
                }
            }
        }
    }
}

private struct ToneHelper: View {
    @Environment(AppModel.self) private var model
    @State private var klass = ConsonantClass.mid
    @State private var mark = ToneMark.none
    @State private var ending = SyllableEnding.live
    @State private var length = SyllableLength.long

    var body: some View {
        let ruling = ToneEngine.ruling(
            consonantClass: klass,
            toneMark: mark,
            ending: ending,
            length: length
        )
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("选四个条件，看声调")
                    .font(.title2.bold())
                Text("有声调符号以后，不再看音节是活是死。长短只在「低辅音、没有符号、死音节」时有用。")
                    .foregroundStyle(Ink.muted)
                    .fixedSize(horizontal: false, vertical: true)

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                    GridRow {
                        Text("辅音类")
                        Picker("辅音类", selection: $klass) {
                            ForEach(ConsonantClass.allCases, id: \.self) { item in
                                Text(item.chinese).tag(item)
                            }
                        }
                        .labelsHidden()
                    }
                    GridRow {
                        Text("声调符号")
                        Picker("声调符号", selection: $mark) {
                            ForEach(ToneMark.allCases, id: \.self) { item in
                                Text(item.chinese).tag(item)
                            }
                        }
                        .labelsHidden()
                    }
                    GridRow {
                        Text("音节")
                        Picker("音节", selection: $ending) {
                            ForEach(SyllableEnding.allCases, id: \.self) { item in
                                Text(item.chinese).tag(item)
                            }
                        }
                        .labelsHidden()
                    }
                    GridRow {
                        Text("元音")
                        Picker("元音", selection: $length) {
                            ForEach(SyllableLength.allCases, id: \.self) { item in
                                Text(item.chinese).tag(item)
                            }
                        }
                        .labelsHidden()
                    }
                }
                .pickerStyle(.menu)

                CardShell {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(ruling.headline)
                            .font(.system(size: 36, weight: .semibold, design: .serif))
                        Text(ruling.tone.markSample + "  " + ruling.tone.mandarinHint)
                            .foregroundStyle(Ink.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(ruling.detail)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                let examples = model.catalog?.toneExamples(
                    consonantClass: klass,
                    toneMark: mark,
                    ending: ending,
                    length: length
                ) ?? []
                Text(examples.isEmpty ? "课里暂时没有正好这个组合的词。规则仍然可以用。" : "课里的例子")
                    .font(.headline)
                ForEach(Array(examples.enumerated()), id: \.offset) { _, example in
                    HStack {
                        Text(example.syllableThai)
                            .font(.system(size: 24, design: .serif))
                            .frame(width: 120, alignment: .leading)
                        VStack(alignment: .leading) {
                            Text(example.roman)
                            Text(example.phraseThai + "  ·  " + example.meaning)
                                .font(.callout)
                                .foregroundStyle(Ink.muted)
                        }
                        Spacer()
                        PlayButton(text: example.syllableThai, title: "听")
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .leading)
        }
    }
}
