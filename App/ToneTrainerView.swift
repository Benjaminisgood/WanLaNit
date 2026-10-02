import SwiftUI
import ThaiLearnCore

struct ToneTrainerView: View {
    @Environment(AppModel.self) private var model
    @Environment(SpeechService.self) private var speech
    @State private var random = QuizRandom()
    @State private var question: ToneQuestion?
    @State private var picked: Tone?
    @State private var revealed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("五个声调")
                        .font(.title.bold())
                    Text("先跟普通话对照着听。系统语音只能给一个大致的高低，符号以罗马音为准。")
                        .foregroundStyle(Ink.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VoiceBanner()

                if let catalog = model.catalog {
                    ForEach(catalog.tones) { lesson in
                        ToneLessonCard(lesson: lesson)
                    }

                    Text("最小对立")
                        .font(.title2.bold())
                        .padding(.top, 8)
                    ForEach(catalog.minimalSets) { set in
                        MinimalSetCard(set: set)
                    }

                    quiz(catalog)

                    Text("中文母语容易混的音")
                        .font(.title2.bold())
                        .padding(.top, 8)
                    ForEach(catalog.sounds) { lesson in
                        SoundLessonCard(lesson: lesson)
                    }

                    Text(RomanizationLegend.summary)
                        .font(.callout)
                        .foregroundStyle(Ink.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                }
            }
            .padding(28)
            .frame(maxWidth: 820, alignment: .leading)
        }
        .navigationTitle("声调")
    }

    @ViewBuilder
    private func quiz(_ catalog: Catalog) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("听，然后选声调")
                .font(.title2.bold())
            if let question {
                CardShell {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(question.setTitle)
                            .font(.caption)
                            .foregroundStyle(Ink.muted)
                        if speech.hasThaiVoice && !revealed {
                            Text("先听，先别看字。")
                                .font(.title3)
                            PlayButton(text: question.thai, title: "再听一次")
                        } else if !speech.hasThaiVoice && !revealed {
                            Text("还没有泰语语音，这题改成看字选调。")
                                .foregroundStyle(Ink.muted)
                            ThaiLine(text: question.thai, size: 56)
                        }
                        if revealed {
                            ThaiLine(text: question.thai, size: 56)
                            Text(question.roman)
                                .font(.title3)
                            Text(question.meaning)
                            if let picked {
                                Text(picked == question.answer ? "对。这是\(question.answer.chinese)。" : "这是\(question.answer.chinese)，你选了\(picked.chinese)。")
                                    .font(.headline)
                                    .foregroundStyle(picked == question.answer ? Ink.leaf : Ink.lacquer)
                            }
                        }
                        if !revealed {
                            HStack {
                                ForEach(question.choices, id: \.self) { tone in
                                    Button(tone.chinese) {
                                        picked = tone
                                        revealed = true
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        } else {
                            Button("下一题") { nextQuestion() }
                                .buttonStyle(.borderedProminent)
                                .tint(Ink.lacquer)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Button("开始听辨") { nextQuestion() }
                    .buttonStyle(.borderedProminent)
                    .tint(Ink.lacquer)
            }
        }
    }

    private func nextQuestion() {
        guard let sets = model.catalog?.minimalSets else { return }
        question = ToneQuiz.question(in: sets, rng: &random.rng)
        picked = nil
        revealed = false
        if let thai = question?.thai {
            speech.speak(thai)
        }
    }
}

private final class QuizRandom {
    var rng = SplitMix64(seed: UInt64(Date().timeIntervalSince1970))
}

private struct ToneLessonCard: View {
    var lesson: ToneLesson

    var body: some View {
        CardShell {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(lesson.tone.chinese)
                        .font(.headline)
                    Text(lesson.tone.markSample)
                        .font(.title3)
                        .foregroundStyle(Ink.lacquer)
                    Spacer()
                    PlayButton(text: lesson.exampleThai)
                }
                Text(lesson.pitch)
                Text(lesson.mandarin)
                    .foregroundStyle(Ink.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(lesson.exampleThai)  \(lesson.exampleRoman)  \(lesson.exampleMeaning)")
                    .font(.title3)
            }
        }
    }
}

private struct MinimalSetCard: View {
    var set: MinimalSet

    var body: some View {
        CardShell {
            VStack(alignment: .leading, spacing: 10) {
                Text(set.title).font(.headline)
                Text(set.hint)
                    .font(.callout)
                    .foregroundStyle(Ink.muted)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(set.items) { item in
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.thai)
                            .font(.system(size: 28, design: .serif))
                            .frame(width: 88, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(item.roman)  ·  \(item.tone.chinese)")
                            Text(item.meaning)
                                .font(.callout)
                                .foregroundStyle(Ink.muted)
                        }
                        Spacer()
                        PlayButton(text: item.thai, title: "听")
                    }
                }
            }
        }
    }
}

private struct SoundLessonCard: View {
    var lesson: SoundLesson

    var body: some View {
        CardShell {
            VStack(alignment: .leading, spacing: 8) {
                Text(lesson.title).font(.headline)
                Text(lesson.problem)
                    .fixedSize(horizontal: false, vertical: true)
                Text(lesson.howTo)
                    .foregroundStyle(Ink.muted)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(lesson.pairs) { pair in
                    HStack {
                        Text(pair.thai)
                            .font(.system(size: 24, design: .serif))
                            .frame(width: 88, alignment: .leading)
                        Text("\(pair.roman)  \(pair.meaning)")
                        Spacer()
                        PlayButton(text: pair.thai, title: "听")
                    }
                }
            }
        }
    }
}
