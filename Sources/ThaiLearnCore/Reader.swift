import Foundation
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

public struct StarterText: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var body: String
    public var level: Int

    public init(id: String, title: String, body: String, level: Int) {
        self.id = id
        self.title = title
        self.body = body
        self.level = level
    }
}

public struct ReaderDocument: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var body: String
    public var source: String

    public init(id: String, title: String, body: String, source: String) {
        self.id = id
        self.title = title
        self.body = body
        self.source = source
    }
}

public struct ReaderNote: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var thai: String
    public var romanization: String
    public var meaning: String
    public var context: String

    public init(id: String, thai: String, romanization: String, meaning: String, context: String) {
        self.id = id
        self.thai = thai
        self.romanization = romanization
        self.meaning = meaning
        self.context = context
    }
}

public enum WordMark: String, Codable, Sendable {
    case new
    case learning
    case known
    case ignored
}

public struct WordMemory: Codable, Equatable, Sendable {
    public var status: WordMark
    public var level: Int

    public init(status: WordMark, level: Int) {
        self.status = status
        self.level = level
    }
}

public struct ReaderToken: Equatable, Identifiable, Sendable {
    public var id: Int
    public var text: String
    public var isWord: Bool

    public init(id: Int, text: String, isWord: Bool) {
        self.id = id
        self.text = text
        self.isWord = isWord
    }
}

public struct ReaderCoverage: Equatable, Sendable {
    public var uniqueWords: Int
    public var known: Int
    public var fraction: Double

    public init(uniqueWords: Int, known: Int, fraction: Double) {
        self.uniqueWords = uniqueWords
        self.known = known
        self.fraction = fraction
    }
}

public enum HTMLText {
    public static func plainText(from html: String) -> String {
        var text = html
        text = replacingBlocks(in: text, tag: "script")
        text = replacingBlocks(in: text, tag: "style")
        let breaks = ["br", "p", "div", "li", "h1", "h2", "h3", "tr", "section", "article"]
        for tag in breaks {
            text = text.replacingOccurrences(of: "<\(tag)", with: "\n<\(tag)", options: .caseInsensitive)
            text = text.replacingOccurrences(of: "</\(tag)>", with: "\n", options: .caseInsensitive)
        }
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let entities = [
            "&nbsp;": " ",
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&#39;": "'"
        ]
        for (entity, value) in entities {
            text = text.replacingOccurrences(of: entity, with: value, options: .caseInsensitive)
        }
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return lines.joined(separator: "\n")
    }

    public static func title(from html: String) -> String? {
        guard let start = html.range(of: "<title>", options: .caseInsensitive),
              let end = html.range(of: "</title>", options: .caseInsensitive, range: start.upperBound..<html.endIndex)
        else { return nil }
        let raw = String(html[start.upperBound..<end.lowerBound])
        let cleaned = plainText(from: raw).trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func replacingBlocks(in html: String, tag: String) -> String {
        html.replacingOccurrences(
            of: "<\(tag)\\b[^>]*>[\\s\\S]*?</\(tag)>",
            with: " ",
            options: [.regularExpression, .caseInsensitive]
        )
    }
}

public enum ThaiSegmenter {
    public static func tokens(in text: String, dictionary: [String] = []) -> [ReaderToken] {
        #if canImport(NaturalLanguage)
        return naturalLanguageTokens(in: text)
        #else
        return dictionaryTokens(in: text, dictionary: dictionary)
        #endif
    }

    public static func dictionaryTokens(in text: String, dictionary: [String]) -> [ReaderToken] {
        let words = dictionary
            .filter { !$0.isEmpty }
            .sorted { $0.count > $1.count }
        var tokens: [ReaderToken] = []
        var index = text.startIndex
        var buffer = ""
        func flushBuffer() {
            guard !buffer.isEmpty else { return }
            tokens.append(ReaderToken(id: tokens.count, text: buffer, isWord: false))
            buffer = ""
        }
        while index < text.endIndex {
            let rest = text[index...]
            if let match = words.first(where: { rest.hasPrefix($0) }) {
                flushBuffer()
                tokens.append(ReaderToken(id: tokens.count, text: match, isWord: true))
                index = text.index(index, offsetBy: match.count)
                continue
            }
            let character = text[index]
            if isThai(character) {
                flushBuffer()
                let cluster = String(character)
                tokens.append(ReaderToken(id: tokens.count, text: cluster, isWord: true))
            } else if character.isWhitespace || character.isNewline {
                flushBuffer()
            } else {
                buffer.append(character)
            }
            index = text.index(after: index)
        }
        flushBuffer()
        return tokens
    }

    #if canImport(NaturalLanguage)
    private static func naturalLanguageTokens(in text: String) -> [ReaderToken] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        tokenizer.setLanguage(.thai)
        var tokens: [ReaderToken] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let slice = String(text[range])
            let word = slice.contains { isThai($0) }
            tokens.append(ReaderToken(id: tokens.count, text: slice, isWord: word))
            return true
        }
        if tokens.isEmpty, !text.isEmpty {
            return dictionaryTokens(in: text, dictionary: [])
        }
        return tokens
    }
    #endif

    private static func isThai(_ character: Character) -> Bool {
        character.unicodeScalars.contains { (0x0E00...0x0E7F).contains($0.value) }
    }
}

public enum ReaderState {
    public static func cardKey(for thai: String, catalog: Catalog) -> String {
        if let word = catalog.word(thai: thai) {
            return word.id
        }
        return "reader:\(thai)"
    }

    public static func display(thai: String, catalog: Catalog, progress: LearningProgress) -> (status: WordMark, level: Int) {
        if let memory = progress.wordMemory[thai], memory.status == .ignored {
            return (.ignored, 0)
        }
        if let memory = progress.wordMemory[thai], memory.status == .known {
            return (.known, 5)
        }
        let key = cardKey(for: thai, catalog: catalog)
        if let card = progress.cards[key] {
            return mark(for: card)
        }
        if let memory = progress.wordMemory[thai] {
            return (memory.status, memory.level)
        }
        return (.new, 0)
    }

    public static func setMark(_ status: WordMark, level: Int, thai: String, progress: inout LearningProgress) {
        let clamped = status == .learning ? min(5, max(1, level)) : (status == .known ? 5 : 0)
        progress.wordMemory[thai] = WordMemory(status: status, level: clamped)
    }

    public static func addToReview(
        thai: String,
        sentence: String,
        catalog: Catalog,
        progress: inout LearningProgress,
        on day: CivilDay
    ) {
        let key = cardKey(for: thai, catalog: catalog)
        if progress.cards[key] == nil {
            var card = CardState.fresh(on: day)
            card.stage = .new
            card.due = day
            progress.cards[key] = card
        }
        let word = catalog.word(thai: thai)
        let note = ReaderNote(
            id: key,
            thai: thai,
            romanization: word?.romanization ?? "",
            meaning: word?.meaning ?? "",
            context: sentence
        )
        if let index = progress.readerNotes.firstIndex(where: { $0.id == key }) {
            progress.readerNotes[index] = note
        } else {
            progress.readerNotes.append(note)
        }
        if progress.wordMemory[thai]?.status != .ignored {
            progress.wordMemory[thai] = WordMemory(status: .learning, level: 1)
        }
    }

    public static func sync(_ ref: StudyRef, catalog: Catalog, progress: inout LearningProgress) {
        guard ref.kind == .word, let card = progress.cards[ref.cardKey] else { return }
        let thai = catalog.word(ref.id)?.thai ?? progress.readerNotes.first { $0.id == ref.cardKey }?.thai
        guard let thai else { return }
        if progress.wordMemory[thai]?.status == .ignored { return }
        let marked = mark(for: card)
        progress.wordMemory[thai] = WordMemory(status: marked.status, level: marked.level)
    }

    public static func coverage(in text: String, catalog: Catalog, progress: LearningProgress) -> ReaderCoverage {
        let dictionary = catalog.words.map(\.thai)
        let tokens = ThaiSegmenter.tokens(in: text, dictionary: dictionary)
        var unique: [String: WordMark] = [:]
        for token in tokens where token.isWord {
            let shown = display(thai: token.text, catalog: catalog, progress: progress)
            if shown.status == .ignored { continue }
            if unique[token.text] != .known {
                unique[token.text] = shown.status
            }
        }
        let known = unique.values.filter { $0 == .known }.count
        let total = unique.count
        let fraction = total == 0 ? 0 : Double(known) / Double(total)
        return ReaderCoverage(uniqueWords: total, known: known, fraction: fraction)
    }

    public static func sentence(around token: ReaderToken, in tokens: [ReaderToken]) -> String {
        var start = token.id
        var end = token.id
        while start > 0, !isBoundary(tokens[start - 1].text) { start -= 1 }
        while end + 1 < tokens.count, !isBoundary(tokens[end].text) { end += 1 }
        return tokens[start...end].map(\.text).joined()
    }

    private static func isBoundary(_ text: String) -> Bool {
        text.contains { character in
            character.isNewline || "。！？!?".contains(character)
        }
    }

    private static func mark(for card: CardState) -> (status: WordMark, level: Int) {
        switch card.stage {
        case .new:
            return (.learning, 1)
        case .learning:
            return (.learning, min(5, max(1, card.step + 1)))
        case .relearning:
            return (.learning, 2)
        case .review:
            if card.intervalDays >= 21 { return (.known, 5) }
            if card.intervalDays >= 10 { return (.learning, 5) }
            if card.intervalDays >= 4 { return (.learning, 4) }
            return (.learning, 3)
        }
    }
}
