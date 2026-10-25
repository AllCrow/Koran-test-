import Foundation

/// A civil Gregorian day in the timezone in which the session was completed.
/// Storing the day rather than midnight preserves it when travelling.
public struct ReadingDay: Codable, Hashable, Comparable, Identifiable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int
    public var id: String { String(format: "%04d-%02d-%02d", year, month, day) }

    public init?(year: Int, month: Int, day: Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(year: year, month: month, day: day, hour: 12)
        guard (1...9999).contains(year), (1...12).contains(month), (1...31).contains(day),
              let date = calendar.date(from: components),
              calendar.component(.year, from: date) == year,
              calendar.component(.month, from: date) == month,
              calendar.component(.day, from: date) == day else { return nil }
        self.year = year
        self.month = month
        self.day = day
    }

    public init(date: Date, calendar: Calendar = .current) {
        let civil = Self.civilCalendar(calendar)
        self.year = civil.component(.year, from: date)
        self.month = civil.component(.month, from: date)
        self.day = civil.component(.day, from: date)
    }

    public func date(in calendar: Calendar = .current) -> Date? {
        Self.civilCalendar(calendar).date(from: DateComponents(year: year, month: month, day: day, hour: 12))
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        if lhs.month != rhs.month { return lhs.month < rhs.month }
        return lhs.day < rhs.day
    }

    fileprivate static func civilCalendar(_ source: Calendar) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = source.timeZone
        return calendar
    }

    private enum CodingKeys: String, CodingKey { case year, month, day }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let year = try container.decode(Int.self, forKey: .year)
        let month = try container.decode(Int.self, forKey: .month)
        let day = try container.decode(Int.self, forKey: .day)
        guard let readingDay = Self(year: year, month: month, day: day) else {
            throw DecodingError.dataCorruptedError(forKey: .day, in: container, debugDescription: "Invalid Gregorian reading day")
        }
        self = readingDay
    }
}

public struct StreakSummary: Hashable, Sendable {
    public let current: Int
    public let best: Int
    public let completedToday: Bool

    public init(current: Int, best: Int, completedToday: Bool) {
        self.current = current
        self.best = best
        self.completedToday = completedToday
    }
}

/// Records deliberate completed reading sessions. Opening the app never counts.
public struct StreakTracker: Codable, Hashable, Sendable {
    public private(set) var completionDays: [ReadingDay]

    public init(completionDays: [ReadingDay] = []) {
        self.completionDays = Array(Set(completionDays)).sorted()
    }

    /// Returns false when a completed session was already recorded on this day.
    @discardableResult
    public mutating func complete(on date: Date = Date(), calendar: Calendar = .current) -> Bool {
        let day = ReadingDay(date: date, calendar: calendar)
        guard !completionDays.contains(day) else { return false }
        completionDays.append(day)
        completionDays.sort()
        return true
    }

    public func isCompleted(on date: Date, calendar: Calendar = .current) -> Bool {
        completionDays.contains(ReadingDay(date: date, calendar: calendar))
    }

    public func summary(asOf date: Date = Date(), calendar: Calendar = .current) -> StreakSummary {
        let civil = ReadingDay.civilCalendar(calendar)
        let today = ReadingDay(date: date, calendar: civil)
        // A saved ReadingDay is a Gregorian date label, not an instant in the
        // current timezone. Some timezone changes skip an entire local date
        // (for example Apia on 2011-12-30). Do adjacency arithmetic in UTC so
        // travelling cannot reinterpret or normalize the stored date labels.
        var dayArithmetic = Calendar(identifier: .gregorian)
        dayArithmetic.timeZone = TimeZone(secondsFromGMT: 0)!
        // Future dates caused by clock changes or travel do not extend a streak.
        let days = completionDays.filter { $0 <= today }
        let completed = Set(days)
        let completedToday = completed.contains(today)
        var best = 0
        var run = 0
        var previous: ReadingDay?
        for day in days {
            if let previous,
               let previousDate = previous.date(in: dayArithmetic),
               let expected = dayArithmetic.date(byAdding: .day, value: 1, to: previousDate),
               ReadingDay(date: expected, calendar: dayArithmetic) == day {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = day
        }
        var current = 0
        if var cursor = today.date(in: dayArithmetic) {
            if !completedToday, let yesterday = dayArithmetic.date(byAdding: .day, value: -1, to: cursor) {
                cursor = yesterday
            }
            while completed.contains(ReadingDay(date: cursor, calendar: dayArithmetic)) {
                current += 1
                guard let prior = dayArithmetic.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = prior
            }
        }
        return StreakSummary(current: current, best: best, completedToday: completedToday)
    }

    private enum CodingKeys: String, CodingKey { case completionDays }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(completionDays: try container.decode([ReadingDay].self, forKey: .completionDays))
    }
}
