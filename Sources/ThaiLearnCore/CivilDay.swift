import Foundation

/// 公历日期，不带时区。进度和复习到期日都用它，避免夏令时把“明天”算错。
public struct CivilDay: Hashable, Comparable, Sendable {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        do {
            self = try CivilDay.validate(year: year, month: month, day: day)
        } catch {
            preconditionFailure("不是合法公历日期：\(year)-\(month)-\(day)")
        }
    }

    public init(iso: String) throws {
        let parts = iso.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]),
              parts[0].count == 4
        else {
            throw CivilDayError.invalidISO(iso)
        }
        self = try CivilDay.validate(year: year, month: month, day: day)
    }

    public var iso: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public func adding(days: Int) -> CivilDay {
        let calendar = CivilDay.gregorianUTC
        let date = calendar.date(from: DateComponents(year: year, month: month, day: day))!
        let shifted = calendar.date(byAdding: .day, value: days, to: date)!
        let parts = calendar.dateComponents([.year, .month, .day], from: shifted)
        return CivilDay(year: parts.year!, month: parts.month!, day: parts.day!)
    }

    /// 从 `earlier` 到自己隔了多少天。同一天是 0。
    public func daysSince(_ earlier: CivilDay) -> Int {
        let calendar = CivilDay.gregorianUTC
        let start = calendar.date(from: DateComponents(year: earlier.year, month: earlier.month, day: earlier.day))!
        let end = calendar.date(from: DateComponents(year: year, month: month, day: day))!
        return calendar.dateComponents([.day], from: start, to: end).day!
    }

    public static func < (lhs: CivilDay, rhs: CivilDay) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        if lhs.month != rhs.month { return lhs.month < rhs.month }
        return lhs.day < rhs.day
    }

    private static func validate(year: Int, month: Int, day: Int) throws -> CivilDay {
        let calendar = gregorianUTC
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: components) else {
            throw CivilDayError.invalid(year: year, month: month, day: day)
        }
        let back = calendar.dateComponents([.year, .month, .day], from: date)
        guard back.year == year, back.month == month, back.day == day else {
            throw CivilDayError.invalid(year: year, month: month, day: day)
        }
        return CivilDay(uncheckedYear: year, month: month, day: day)
    }

    private init(uncheckedYear year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    private static var gregorianUTC: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}

public enum CivilDayError: Error, Equatable {
    case invalidISO(String)
    case invalid(year: Int, month: Int, day: Int)
}

extension CivilDay: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let iso = try container.decode(String.self)
        self = try CivilDay(iso: iso)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(iso)
    }
}
