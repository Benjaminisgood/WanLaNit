import Foundation

public enum Phase: String, Codable, CaseIterable, Sendable {
    case pronunciation
    case script
    case grammar

    public var title: String {
        switch self {
        case .pronunciation: return "发音和生存句"
        case .script: return "泰文"
        case .grammar: return "语法和词汇"
        }
    }

    public var daySpan: String {
        switch self {
        case .pronunciation: return "第 1–14 天"
        case .script: return "第 15–45 天"
        case .grammar: return "第 46 天起"
        }
    }

    public var summary: String {
        switch self {
        case .pronunciation:
            return "先把五个声调听稳，记住见面、吃饭、自我介绍。每天大约八个新句子，其余时间复习。"
        case .script:
            return "辅音按中、高、低三类认，加上元音和声调规则。对话句子继续复习，不会停。"
        case .grammar:
            return "虚词、家人、颜色和更长的句子。文字课没认完的字母还会零星出现。"
        }
    }
}

public enum ItemKind: String, Codable, Sendable {
    case phrase
    case word
    case pattern

    public var chinese: String {
        switch self {
        case .phrase: return "句子"
        case .word: return "词"
        case .pattern: return "句式"
        }
    }
}

public enum StudyKind: String, Codable, Sendable {
    case phrase
    case consonant
    case vowel
    case tone
    case word

    public var chinese: String {
        switch self {
        case .phrase: return "句子"
        case .consonant: return "辅音"
        case .vowel: return "元音"
        case .tone: return "声调规则"
        case .word: return "词"
        }
    }
}

public enum CardTemplate: String, Codable, CaseIterable, Sendable {
    case recognition
    case production
    case consonantClass
    case vowelForm
    case toneRule

    public var chinese: String {
        switch self {
        case .recognition: return "认出"
        case .production: return "中文写出泰文"
        case .consonantClass: return "字母的类和读音"
        case .vowelForm: return "元音写法"
        case .toneRule: return "声调规则"
        }
    }

    public static func legacyDefault(for kind: StudyKind) -> CardTemplate {
        switch kind {
        case .phrase, .word: return .recognition
        case .consonant: return .consonantClass
        case .vowel: return .vowelForm
        case .tone: return .toneRule
        }
    }
}

public struct Syllable: Codable, Equatable, Sendable {
    public var thai: String
    public var roman: String
    /// 同一个词里的音节共用一个 word 序号，词和词之间用空格。
    public var word: Int
    /// 决定声调的类。ห นำ 或词典里不写出来的 หฺ，这里记生效后的类。
    public var consonantClass: ConsonantClass
    public var toneMark: ToneMark
    public var ending: SyllableEnding
    public var length: SyllableLength
    /// 实际读音和规则不一致时写原因。空着就表示规则算出来的调必须和罗马音一致。
    public var exception: String?
    public var note: String?
}

public struct Deck: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var blurb: String
    public var phase: Phase
    public var order: Int
}

public struct Phrase: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var deck: String
    public var phase: Phase
    public var order: Int
    public var kind: ItemKind
    public var thai: String
    public var romanization: String
    public var meaning: String
    public var note: String?
    /// 给语音用。มี ๆ 时写成展开后的句子，因为系统语音不一定会重复。
    public var speech: String?
    public var syllables: [Syllable]

    public var spoken: String { speech ?? thai }
}

public struct Consonant: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var symbol: String
    public var order: Int
    public var consonantClass: ConsonantClass
    public var obsolete: Bool
    public var nameThai: String
    public var nameRoman: String
    public var meaning: String
    public var initial: String
    public var final: String?
    public var finalNote: String?
    public var exampleThai: String
    public var exampleRoman: String
    public var exampleMeaning: String
    public var note: String?
    public var syllables: [Syllable]

    public var spoken: String { nameThai }
}

public struct Vowel: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var symbols: String
    public var roman: String
    public var lengthLabel: String
    public var soundHint: String
    public var exampleThai: String
    public var exampleRoman: String
    public var exampleMeaning: String
    public var order: Int
    public var note: String?
    public var syllables: [Syllable]
}

public struct ToneLesson: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var tone: Tone
    public var mandarin: String
    public var pitch: String
    public var exampleThai: String
    public var exampleRoman: String
    public var exampleMeaning: String
}

public struct MinimalItem: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var thai: String
    public var roman: String
    public var meaning: String
    public var tone: Tone
    public var syllable: Syllable
}

public struct MinimalSet: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var hint: String
    public var items: [MinimalItem]
}

public struct SoundPair: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var thai: String
    public var roman: String
    public var meaning: String
    public var note: String?
}

public struct SoundLesson: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var problem: String
    public var howTo: String
    public var pairs: [SoundPair]
}

public struct VocabWord: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var thai: String
    public var romanization: String
    public var meaning: String
    public var band: Int
    public var topic: String
    public var order: Int

    public var spoken: String { thai }
}

public struct CultureNote: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var thai: String?
    public var roman: String?
    public var body: String
    public var order: Int
}

public struct Catalog: Equatable, Sendable {
    public var decks: [Deck]
    public var phrases: [Phrase]
    public var consonants: [Consonant]
    public var vowels: [Vowel]
    public var tones: [ToneLesson]
    public var minimalSets: [MinimalSet]
    public var sounds: [SoundLesson]
    public var culture: [CultureNote]
    public var words: [VocabWord]

    public init(
        decks: [Deck],
        phrases: [Phrase],
        consonants: [Consonant],
        vowels: [Vowel],
        tones: [ToneLesson],
        minimalSets: [MinimalSet],
        sounds: [SoundLesson],
        culture: [CultureNote],
        words: [VocabWord] = []
    ) {
        self.decks = decks
        self.phrases = phrases
        self.consonants = consonants
        self.vowels = vowels
        self.tones = tones
        self.minimalSets = minimalSets
        self.sounds = sounds
        self.culture = culture
        self.words = words
    }

    public func deck(_ id: String) -> Deck? {
        decks.first { $0.id == id }
    }

    public func phrase(_ id: String) -> Phrase? {
        phrases.first { $0.id == id }
    }

    public func consonant(_ id: String) -> Consonant? {
        consonants.first { $0.id == id }
    }

    public func vowel(_ id: String) -> Vowel? {
        vowels.first { $0.id == id }
    }

    public func word(_ id: String) -> VocabWord? {
        words.first { $0.id == id }
    }

    public func word(thai: String) -> VocabWord? {
        words.first { $0.thai == thai }
    }

    public struct ToneExample: Equatable, Sendable {
        public var syllableThai: String
        public var roman: String
        public var phraseThai: String
        public var meaning: String
    }

    public func toneExamples(
        consonantClass: ConsonantClass,
        toneMark: ToneMark,
        ending: SyllableEnding,
        length: SyllableLength,
        limit: Int = 6
    ) -> [ToneExample] {
        var found: [ToneExample] = []
        for phrase in phrases {
            for syllable in phrase.syllables where syllable.matches(
                consonantClass: consonantClass,
                toneMark: toneMark,
                ending: ending,
                length: length
            ) {
                found.append(ToneExample(
                    syllableThai: syllable.thai,
                    roman: syllable.roman,
                    phraseThai: phrase.thai,
                    meaning: phrase.meaning
                ))
                if found.count == limit { return found }
            }
        }
        return found
    }
}

extension Syllable {
    func matches(
        consonantClass: ConsonantClass,
        toneMark: ToneMark,
        ending: SyllableEnding,
        length: SyllableLength
    ) -> Bool {
        self.consonantClass == consonantClass
            && self.toneMark == toneMark
            && self.ending == ending
            && self.length == length
            && exception == nil
    }

    public var expectedTone: Tone {
        ToneEngine.tone(
            consonantClass: consonantClass,
            toneMark: toneMark,
            ending: ending,
            length: length
        )
    }
}

public enum RomanizationJoiner {
    public static func join(_ syllables: [Syllable]) -> String {
        var order: [Int] = []
        var groups: [Int: [String]] = [:]
        for syllable in syllables {
            if groups[syllable.word] == nil {
                order.append(syllable.word)
            }
            groups[syllable.word, default: []].append(syllable.roman)
        }
        return order.map { groups[$0, default: []].joined(separator: "-") }.joined(separator: " ")
    }
}
