import Foundation

/// SuperMemo SM-2。quality 0...5，3 分以下算没记住。
public enum SM2 {
    public struct State: Equatable, Sendable {
        public var repetitions: Int
        public var easeFactor: Double
        public var intervalDays: Int

        public init(repetitions: Int, easeFactor: Double, intervalDays: Int) {
            self.repetitions = repetitions
            self.easeFactor = easeFactor
            self.intervalDays = intervalDays
        }

        public static let new = State(repetitions: 0, easeFactor: 2.5, intervalDays: 0)
    }

    public static func review(quality: Int, state: State) -> State {
        let quality = min(5, max(0, quality))
        var repetitions = state.repetitions
        var ease = state.easeFactor
        var interval = state.intervalDays

        if quality < 3 {
            repetitions = 0
            interval = 1
        } else {
            if repetitions == 0 {
                interval = 1
            } else if repetitions == 1 {
                interval = 6
            } else {
                interval = Int((Double(interval) * ease).rounded(.toNearestOrAwayFromZero))
                if interval < 1 { interval = 1 }
            }
            repetitions += 1
        }

        let delta = 5 - quality
        ease += 0.1 - Double(delta) * (0.08 + Double(delta) * 0.02)
        if ease < 1.3 { ease = 1.3 }

        return State(repetitions: repetitions, easeFactor: ease, intervalDays: interval)
    }
}

public enum Grade: Int, Codable, CaseIterable, Sendable {
    case again = 1
    case hard = 3
    case good = 4
    case easy = 5

    public var quality: Int { rawValue }

    public var title: String {
        switch self {
        case .again: return "忘了"
        case .hard: return "模糊"
        case .good: return "记得"
        case .easy: return "简单"
        }
    }

    public var hint: String {
        switch self {
        case .again: return "这张马上再来一次"
        case .hard: return "想起来了，但很勉强"
        case .good: return "对了，按正常间隔"
        case .easy: return "太容易了"
        }
    }
}
