import SwiftUI
import ThaiLearnCore

struct StatsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let stats = model.stats()
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("复习")
                    .font(.title.bold())
                Text("间隔用 FSRS-5。Again / Hard / Good / Easy 会改稳定性和难度，期望记住率默认 90%。")
                    .foregroundStyle(Ink.muted)
                    .fixedSize(horizontal: false, vertical: true)

                if let stats {
                    HStack(spacing: 12) {
                        stat(title: "记住率", value: retentionText(stats.retention))
                        stat(title: "学习中", value: "\(stats.learning)")
                        stat(title: "复习中", value: "\(stats.reviewing)")
                    }

                    CardShell {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("每天复习了多少")
                                .font(.headline)
                            if stats.days.isEmpty {
                                Text("还没有复习记录。")
                                    .foregroundStyle(Ink.muted)
                            } else {
                                let recent = Array(stats.days.suffix(14))
                                let peak = max(recent.map(\.reviews).max() ?? 1, 1)
                                HStack(alignment: .bottom, spacing: 6) {
                                    ForEach(recent, id: \.day) { day in
                                        VStack(spacing: 4) {
                                            Text("\(day.reviews)")
                                                .font(.caption2.monospacedDigit())
                                                .foregroundStyle(Ink.muted)
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(Ink.leaf)
                                                .frame(height: max(4, 72 * Double(day.reviews) / Double(peak)))
                                            Text(shortDay(day.day))
                                                .font(.caption2)
                                                .foregroundStyle(Ink.muted)
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                }
                            }
                        }
                    }

                    CardShell {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("未来七天到期")
                                .font(.headline)
                            ForEach(stats.forecast, id: \.day) { day in
                                HStack {
                                    Text(day.day == model.today ? "今天" : day.day.iso)
                                    Spacer()
                                    Text("\(day.dueCount) 张")
                                        .monospacedDigit()
                                        .foregroundStyle(Ink.muted)
                                }
                                .font(.callout)
                            }
                        }
                    }
                }

                settings
            }
            .padding(28)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .navigationTitle("统计")
        .toolbarBackground(Ink.paper, for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
    }

    @ViewBuilder
    private var settings: some View {
        CardShell {
            VStack(alignment: .leading, spacing: 14) {
                Text("复习设置")
                    .font(.headline)
                VStack(alignment: .leading, spacing: 4) {
                    Text("期望记住率 \(percent(model.progress.desiredRetention))")
                    Slider(
                        value: Binding(
                            get: { model.progress.desiredRetention },
                            set: { model.setDesiredRetention($0) }
                        ),
                        in: 0.80...0.97,
                        step: 0.01
                    )
                    Text("越高，卡片回来得越勤。")
                        .font(.caption)
                        .foregroundStyle(Ink.muted)
                }
                Stepper(
                    "每天新卡片 \(model.progress.newCardLimit)",
                    value: Binding(
                        get: { model.progress.newCardLimit },
                        set: { model.setNewCardLimit($0) }
                    ),
                    in: 0...60
                )
                Text("课程自己还有节奏：前两周大约 8 张新句子，认字阶段会换成字母和声调规则。这里是上限。")
                    .font(.caption)
                    .foregroundStyle(Ink.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Toggle(
                    "全部解锁（自由模式）",
                    isOn: Binding(
                        get: { model.progress.unlockAll },
                        set: { model.setUnlockAll($0) }
                    )
                )
                Text("打开后，声调、词汇和阅读都会出现在侧栏，不再等前面的进度。今天页上的路线仍按实际进度显示。")
                    .font(.caption)
                    .foregroundStyle(Ink.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        AISettingsView()
    }

    private func stat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Ink.muted)
            Text(value)
                .font(.title3.weight(.semibold))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ink.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Ink.line, lineWidth: 1))
    }

    private func retentionText(_ value: Double?) -> String {
        guard let value else { return "—" }
        return percent(value)
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func shortDay(_ day: CivilDay) -> String {
        "\(day.month)/\(day.day)"
    }
}
