import Foundation

/// 今天这一页上的路线：文字，然后声调，然后词汇，最后才是阅读。
public struct PathStep: Equatable, Sendable, Identifiable {
    public enum Kind: String, CaseIterable, Sendable {
        case letters
        case tones
        case vocabulary
        case reading
    }

    public var kind: Kind
    public var title: String
    public var detail: String
    public var unlocked: Bool

    public var id: String { kind.rawValue }

    public init(kind: Kind, title: String, detail: String, unlocked: Bool) {
        self.kind = kind
        self.title = title
        self.detail = detail
        self.unlocked = unlocked
    }
}

public enum LearningPath {
    /// 认过这么多辅音以后，声调练习才打开。
    public static let consonantsBeforeTones = 8
    /// 做过这么多张声调规则卡以后，词汇才打开。
    public static let toneCardsBeforeVocabulary = 4
    /// 学过这么多个词以后，阅读才打开。
    public static let wordCardsBeforeReading = 10

    public static func isUnlocked(_ kind: PathStep.Kind, catalog: Catalog, progress: LearningProgress) -> Bool {
        switch kind {
        case .letters:
            return true
        case .tones:
            return consonantCount(catalog, progress) >= consonantsBeforeTones
        case .vocabulary:
            return isUnlocked(.tones, catalog: catalog, progress: progress)
                && toneCount(progress) >= toneCardsBeforeVocabulary
        case .reading:
            return isUnlocked(.vocabulary, catalog: catalog, progress: progress)
                && wordCount(catalog, progress) >= wordCardsBeforeReading
        }
    }

    public static func steps(catalog: Catalog, progress: LearningProgress) -> [PathStep] {
        let consonants = consonantCount(catalog, progress)
        let tones = toneCount(progress)
        let words = wordCount(catalog, progress)
        let vowels = catalog.vowels.filter { progress.cards[$0.id] != nil }.count
        return [
            PathStep(
                kind: .letters,
                title: "文字",
                detail: "辅音 \(consonants)/\(catalog.consonants.count)，元音 \(vowels)/\(catalog.vowels.count)。",
                unlocked: true
            ),
            PathStep(
                kind: .tones,
                title: "声调",
                detail: isUnlocked(.tones, catalog: catalog, progress: progress)
                    ? "声调规则 \(tones) 张。"
                    : "先认满 \(consonantsBeforeTones) 个辅音，现在 \(consonants) 个。",
                unlocked: isUnlocked(.tones, catalog: catalog, progress: progress)
            ),
            PathStep(
                kind: .vocabulary,
                title: "词汇",
                detail: isUnlocked(.vocabulary, catalog: catalog, progress: progress)
                    ? "学过 \(words) 个词。"
                    : "先做满 \(toneCardsBeforeVocabulary) 张声调规则，现在 \(tones) 张。",
                unlocked: isUnlocked(.vocabulary, catalog: catalog, progress: progress)
            ),
            PathStep(
                kind: .reading,
                title: "阅读",
                detail: isUnlocked(.reading, catalog: catalog, progress: progress)
                    ? "短文可以点开。生词会回到复习队列。"
                    : "先学满 \(wordCardsBeforeReading) 个词，现在 \(words) 个。",
                unlocked: isUnlocked(.reading, catalog: catalog, progress: progress)
            )
        ]
    }

    private static func consonantCount(_ catalog: Catalog, _ progress: LearningProgress) -> Int {
        catalog.consonants.filter { progress.cards[$0.id] != nil }.count
    }

    private static func toneCount(_ progress: LearningProgress) -> Int {
        progress.cards.keys.filter { $0.hasPrefix("tone-") }.count
    }

    private static func wordCount(_ catalog: Catalog, _ progress: LearningProgress) -> Int {
        catalog.words.filter { word in
            progress.cards[word.id] != nil || progress.cards["\(word.id)#production"] != nil
        }.count
    }
}
