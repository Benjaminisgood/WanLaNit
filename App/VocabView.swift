import SwiftUI
import ThaiLearnCore

struct VocabView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var topic = "全部"

    private var words: [VocabWord] {
        let all = (model.catalog?.words ?? []).sorted { lhs, rhs in
            if lhs.band != rhs.band { return lhs.band < rhs.band }
            return lhs.order < rhs.order
        }
        return all.filter { word in
            let topicMatches = topic == "全部" || word.topic == topic
            let trimmed = query.trimmingCharacters(in: .whitespaces)
            guard topicMatches else { return false }
            guard !trimmed.isEmpty else { return true }
            return word.thai.contains(trimmed)
                || word.meaning.contains(trimmed)
                || word.romanization.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var topics: [String] {
        var seen: [String] = ["全部"]
        for word in model.catalog?.words ?? [] where !seen.contains(word.topic) {
            seen.append(word.topic)
        }
        return seen
    }

    var body: some View {
        VStack(spacing: 0) {
            VoiceSourceBar()
                .padding(.horizontal, 16)
                .padding(.top, 12)
            HStack(spacing: 12) {
                TextField("搜泰文、罗马音或中文", text: $query)
                    .textFieldStyle(.roundedBorder)
                Picker("话题", selection: $topic) {
                    ForEach(topics, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .frame(maxWidth: 180)
            }
            .padding(16)
            List(words) { word in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(word.thai)
                        .font(.system(size: 22, design: .serif))
                        .frame(width: 140, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(word.meaning)
                        Text(word.romanization)
                            .font(.caption)
                            .foregroundStyle(Ink.muted)
                    }
                    Spacer()
                    Text("第 \(word.band) 档")
                        .font(.caption)
                        .foregroundStyle(Ink.muted)
                    PlayButton(text: word.spoken, title: "听")
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("词汇")
    }
}
