import SwiftUI
import ThaiLearnCore

struct CultureView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedID: String? = "culture-wai"

    private var notes: [CultureNote] {
        (model.catalog?.culture ?? []).sorted { $0.order < $1.order }
    }

    var body: some View {
        HStack(spacing: 0) {
            List(notes, selection: $selectedID) { note in
                Text(note.title)
                    .tag(Optional(note.id))
                    .padding(.vertical, 4)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 200, idealWidth: 240, maxWidth: 300)

            if let note = notes.first(where: { $0.id == selectedID }) ?? notes.first {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(note.title)
                            .font(.title.bold())
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
                    }
                    .padding(32)
                    .frame(maxWidth: 680, alignment: .leading)
                }
            }
        }
        .navigationTitle("文化")
    }
}
