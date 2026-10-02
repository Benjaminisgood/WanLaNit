import SwiftUI
import ThaiLearnCore

struct TodayView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let phase = StudyPlan.phase(on: model.today, start: model.progress.startDate)
        let day = StudyPlan.dayNumber(on: model.today, start: model.progress.startDate)
        let plan = model.planToday()
        let report = model.report()

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("第 \(day) 天 · \(phase.title)")
                        .font(.title.bold())
                    Text(phase.daySpan)
                        .font(.subheadline)
                        .foregroundStyle(Ink.muted)
                    Text(phase.summary)
                        .font(.body)
                        .foregroundStyle(Ink.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VoiceBanner()

                if let report {
                    HStack(spacing: 12) {
                        StatPill(title: "连续", value: "\(report.streak) 天")
                        StatPill(title: "学过", value: "\(report.introduced)")
                        StatPill(title: "到期", value: "\(report.due)")
                        StatPill(title: "间隔超过三周", value: "\(report.mastered)")
                    }
                }

                CardShell {
                    VStack(alignment: .leading, spacing: 12) {
                        if let resume = model.progress.resume, resume.day == model.today, !resume.items.isEmpty {
                            Text("这一轮还没做完")
                                .font(.headline)
                            Text("剩下 \(max(resume.items.count - resume.index, 1)) 张。")
                                .foregroundStyle(Ink.muted)
                            Button("继续") { model.beginToday() }
                                .keyboardShortcut(.defaultAction)
                                .buttonStyle(.borderedProminent)
                                .tint(Ink.lacquer)
                        } else if let plan, !plan.items.isEmpty {
                            Text(plan.reviewCount == 0 ? "今天都是新的" : "先复习，再学新的")
                                .font(.headline)
                            Text("\(plan.reviewCount) 张复习，\(plan.newCount) 张新的。大约 \(plan.estimatedMinutes) 分钟。")
                                .foregroundStyle(Ink.muted)
                            Button("开始") { model.beginToday() }
                                .keyboardShortcut(.defaultAction)
                                .buttonStyle(.borderedProminent)
                                .tint(Ink.lacquer)
                        } else {
                            Text("今天没有要背的")
                                .font(.headline)
                            Text("新句子暂时没有了，到期的也复习完了。可以去「句子」里翻一翻，或者明天再来。文字和声调随时能看。")
                                .foregroundStyle(Ink.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                if let report, !report.decks.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("各组进度")
                            .font(.headline)
                        ForEach(report.decks, id: \.deckID) { deck in
                            DeckProgressRow(stat: deck)
                        }
                    }
                }

                Text("从 \(model.progress.startDate.iso) 开始。进度记在这台 Mac 上。")
                    .font(.footnote)
                    .foregroundStyle(Ink.muted)
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .navigationTitle("今天")
    }
}

private struct StatPill: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Ink.muted)
            Text(value)
                .font(.title3.weight(.semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ink.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Ink.line, lineWidth: 1))
    }
}

private struct DeckProgressRow: View {
    var stat: DeckStat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(stat.title)
                Spacer()
                Text("\(stat.introduced) / \(stat.total)")
                    .foregroundStyle(Ink.muted)
                    .monospacedDigit()
            }
            .font(.callout)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Ink.line)
                    Capsule()
                        .fill(Ink.leaf)
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 6)
        }
    }

    private var fraction: Double {
        guard stat.total > 0 else { return 0 }
        return Double(stat.introduced) / Double(stat.total)
    }
}
