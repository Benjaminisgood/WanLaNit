import SwiftUI
import ThaiLearnCore

struct DecksView: View {
    @Environment(AppModel.self) private var model
    @State private var deckID: String?

    private var decks: [Deck] {
        (model.catalog?.decks ?? []).sorted { $0.order < $1.order }
    }

    private var selected: Deck? {
        let id = deckID ?? decks.first?.id
        return decks.first { $0.id == id }
    }

    var body: some View {
        HStack(spacing: 0) {
            List(decks, selection: $deckID) { deck in
                VStack(alignment: .leading, spacing: 2) {
                    Text(deck.title)
                    Text(deck.phase.title)
                        .font(.caption)
                        .foregroundStyle(Ink.muted)
                }
                .tag(Optional(deck.id))
                .padding(.vertical, 4)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 200, idealWidth: 230, maxWidth: 280)

            if let deck = selected, let catalog = model.catalog {
                DeckDetail(
                    deck: deck,
                    catalog: catalog,
                    phrases: catalog.phrases.filter { $0.deck == deck.id }.sorted { $0.order < $1.order }
                )
            } else {
                ContentUnavailableView("没有词组", systemImage: "text.bubble")
            }
        }
        .navigationTitle("句子")
        .onAppear {
            if deckID == nil { deckID = decks.first?.id }
        }
    }
}

private struct DeckDetail: View {
    @Environment(AppModel.self) private var model
    var deck: Deck
    var catalog: Catalog
    var phrases: [Phrase]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(deck.title)
                    .font(.title.bold())
                VoiceSourceBar()
                Text(deck.blurb)
                    .foregroundStyle(Ink.muted)
                Text("\(deck.phase.title) · \(deck.phase.daySpan)")
                    .font(.callout)
                    .foregroundStyle(Ink.muted)

                let plan = StudySession.planDeck(deckID: deck.id, catalog: catalog, progress: model.progress, today: model.today)
                if plan.items.isEmpty {
                    Text("这组今天没有新的，也没有到期的。下面可以随时翻。")
                        .font(.callout)
                        .foregroundStyle(Ink.muted)
                } else {
                    Button("练习这组（\(plan.items.count) 张）") {
                        model.beginDeck(deck.id)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Ink.lacquer)
                }

                ForEach(phrases) { phrase in
                    CardShell {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(phrase.kind.chinese)
                                    .font(.caption)
                                    .foregroundStyle(Ink.muted)
                                Spacer()
                                PlayButton(text: phrase.spoken, title: "听")
                            }
                            Text(phrase.thai)
                                .font(.system(size: 26, design: .serif))
                            Text(phrase.romanization)
                            Text(phrase.meaning)
                            if let note = phrase.note {
                                Text(note)
                                    .font(.callout)
                                    .foregroundStyle(Ink.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .leading)
        }
    }
}
