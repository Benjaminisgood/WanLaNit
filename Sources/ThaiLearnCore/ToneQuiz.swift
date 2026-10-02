import Foundation

public struct ToneQuestion: Equatable, Sendable {
    public var setID: String
    public var setTitle: String
    public var thai: String
    public var roman: String
    public var meaning: String
    public var answer: Tone
    /// 五个声调，固定顺序，方便界面排按钮。
    public var choices: [Tone]
}

public struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

public enum ToneQuiz {
    public static func question(
        in sets: [MinimalSet],
        rng: inout some RandomNumberGenerator
    ) -> ToneQuestion? {
        let pool = sets.filter { !$0.items.isEmpty }
        guard let set = pool.randomElement(using: &rng),
              let item = set.items.randomElement(using: &rng)
        else { return nil }
        return ToneQuestion(
            setID: set.id,
            setTitle: set.title,
            thai: item.thai,
            roman: item.roman,
            meaning: item.meaning,
            answer: item.tone,
            choices: Tone.allCases
        )
    }
}
