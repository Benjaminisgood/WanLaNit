import Foundation

/// FSRS-5，按公开的遗忘曲线和默认参数实现。
/// 参数是 open-spaced-repetition 公布的 FSRS-5 默认值（参考实现为 MIT）。
/// 这里只按公式写，没有搬那些仓库里的代码。
public enum FSRS {
    public static let defaultDesiredRetention = 0.9

    /// w0...w18。前四个是 Again/Hard/Good/Easy 的初始稳定性。
    public static let defaultParameters: [Double] = [
        0.40255, 1.18385, 3.173, 15.69105,
        7.1949, 0.5345, 1.4604, 0.0046,
        1.54575, 0.1192, 1.01925,
        1.9395, 0.11, 0.29605, 2.2698,
        0.2315, 2.9898,
        0.51655, 0.6621
    ]

    public static let decay = -0.5
    /// 让「过了 S 天，记住率正好是 0.9」。
    public static let factor = 19.0 / 81.0

    public struct Memory: Equatable, Sendable {
        public var stability: Double
        public var difficulty: Double

        public init(stability: Double, difficulty: Double) {
            self.stability = stability
            self.difficulty = difficulty
        }
    }

    public static func initial(rating: Int) -> Memory {
        let rating = clampRating(rating)
        let weights = defaultParameters
        let stability = weights[rating - 1]
        let difficulty = clampDifficulty(weights[4] - exp(weights[5] * Double(rating - 1)) + 1)
        return Memory(stability: stability, difficulty: difficulty)
    }

    /// 已经有稳定性之后的一次复习。同一天（elapsedDays < 1）走短期记忆公式。
    public static func next(
        stability: Double,
        difficulty: Double,
        rating: Int,
        elapsedDays: Double,
        desiredRetention: Double = defaultDesiredRetention
    ) -> Memory {
        let rating = clampRating(rating)
        let weights = defaultParameters
        let stability = max(stability, 0.01)
        let difficulty = clampDifficulty(difficulty)
        let nextDifficulty = updatedDifficulty(difficulty, rating: rating, weights: weights)
        let nextStability: Double
        if elapsedDays < 1 {
            nextStability = stability * exp(weights[17] * (Double(rating - 3) + weights[18]))
        } else if rating == 1 {
            let retrievability = recallProbability(elapsedDays: elapsedDays, stability: stability)
            nextStability = weights[11]
                * pow(nextDifficulty, -weights[12])
                * (pow(stability + 1, weights[13]) - 1)
                * exp(weights[14] * (1 - retrievability))
        } else {
            let retrievability = recallProbability(elapsedDays: elapsedDays, stability: stability)
            let hardPenalty = rating == 2 ? weights[15] : 1
            let easyBonus = rating == 4 ? weights[16] : 1
            let gain = exp(weights[8])
                * (11 - nextDifficulty)
                * pow(stability, -weights[9])
                * (exp(weights[10] * (1 - retrievability)) - 1)
                * hardPenalty
                * easyBonus
            nextStability = stability * (gain + 1)
        }
        return Memory(stability: max(nextStability, 0.01), difficulty: nextDifficulty)
    }

    public static func recallProbability(elapsedDays: Double, stability: Double) -> Double {
        let stability = max(stability, 0.01)
        let elapsed = max(0, elapsedDays)
        return pow(1 + factor * elapsed / stability, decay)
    }

    /// 期望记住率下的间隔，单位是天，至少 1 天。
    public static func intervalDays(stability: Double, desiredRetention: Double = defaultDesiredRetention) -> Int {
        let retention = min(0.99, max(0.7, desiredRetention))
        let stability = max(stability, 0.01)
        let days = (stability / factor) * (pow(retention, 1 / decay) - 1)
        guard days.isFinite else { return 1 }
        return max(1, Int(days.rounded(.toNearestOrAwayFromZero)))
    }

    private static func updatedDifficulty(_ difficulty: Double, rating: Int, weights: [Double]) -> Double {
        let delta = -weights[6] * Double(rating - 3)
        let adjusted = difficulty + delta * (10 - difficulty) / 9
        let easyInitial = weights[4] - exp(weights[5] * 3) + 1
        let reverted = weights[7] * easyInitial + (1 - weights[7]) * adjusted
        return clampDifficulty(reverted)
    }

    private static func clampRating(_ rating: Int) -> Int {
        min(4, max(1, rating))
    }

    private static func clampDifficulty(_ difficulty: Double) -> Double {
        min(10, max(1, difficulty))
    }
}
