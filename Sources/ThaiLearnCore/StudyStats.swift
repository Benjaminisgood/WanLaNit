import Foundation

public struct DailyReviewCount: Equatable, Sendable {
    public var day: CivilDay
    public var reviews: Int
    public var newItems: Int
    public var remembered: Int

    public init(day: CivilDay, reviews: Int, newItems: Int, remembered: Int) {
        self.day = day
        self.reviews = reviews
        self.newItems = newItems
        self.remembered = remembered
    }
}

public struct ForecastDay: Equatable, Sendable {
    public var day: CivilDay
    public var dueCount: Int

    public init(day: CivilDay, dueCount: Int) {
        self.day = day
        self.dueCount = dueCount
    }
}

public struct StudyStats: Equatable, Sendable {
    public var days: [DailyReviewCount]
    public var retention: Double?
    public var forecast: [ForecastDay]
    public var learning: Int
    public var reviewing: Int

    public init(
        days: [DailyReviewCount],
        retention: Double?,
        forecast: [ForecastDay],
        learning: Int,
        reviewing: Int
    ) {
        self.days = days
        self.retention = retention
        self.forecast = forecast
        self.learning = learning
        self.reviewing = reviewing
    }

    public static func make(catalog: Catalog, progress: LearningProgress, today: CivilDay) -> StudyStats {
        let days = progress.dayLogs
            .sorted { $0.day < $1.day }
            .map {
                DailyReviewCount(day: $0.day, reviews: $0.reviews, newItems: $0.newItems, remembered: $0.remembered)
            }
        let reviews = days.reduce(0) { $0 + $1.reviews }
        let remembered = days.reduce(0) { $0 + $1.remembered }
        let retention: Double? = reviews > 0 ? Double(remembered) / Double(reviews) : nil

        var learning = 0
        var reviewing = 0
        var dueByDay: [CivilDay: Int] = [:]
        for card in progress.cards.values {
            switch card.stage {
            case .learning, .relearning, .new:
                learning += 1
            case .review:
                reviewing += 1
            }
            dueByDay[card.due, default: 0] += 1
        }
        let forecast = (0..<7).map { offset in
            let day = today.adding(days: offset)
            return ForecastDay(day: day, dueCount: dueByDay[day, default: 0])
        }
        _ = catalog
        return StudyStats(
            days: days,
            retention: retention,
            forecast: forecast,
            learning: learning,
            reviewing: reviewing
        )
    }
}
