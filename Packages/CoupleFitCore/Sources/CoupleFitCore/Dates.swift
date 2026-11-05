import Foundation

/// Local calendar dates as "YYYY-MM-DD" strings, weeks that start on Monday, and weekday numbers where 0 = Sunday (as stored in plans).
public enum Dates {
    public static func localDate(_ d: Date, _ cal: Calendar = .current) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// 0 = Sunday ... 6 = Saturday.
    public static func weekday(_ d: Date, _ cal: Calendar = .current) -> Int { cal.component(.weekday, from: d) - 1 }

    /// Position in a Monday-first week: Monday 0 ... Sunday 6.
    public static func mondayIndex(_ weekday: Int) -> Int { (weekday + 6) % 7 }

    /// The date (at the start of the day) of the Monday that begins the week containing `d`.
    public static func monday(of d: Date, _ cal: Calendar = .current) -> Date {
        let start = cal.startOfDay(for: d)
        return cal.date(byAdding: .day, value: -mondayIndex(weekday(d, cal)), to: start) ?? start
    }

    public static func weekStart(_ d: Date, _ cal: Calendar = .current) -> String { localDate(monday(of: d, cal), cal) }

    /// The seven dates, Monday to Sunday, of the week containing `d`.
    public static func weekDates(_ d: Date, _ cal: Calendar = .current) -> [Date] {
        let m = monday(of: d, cal)
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: m) }
    }

    /// A date from year, month, day (and noon, to stay clear of daylight-saving edges). For tests and parsing.
    public static func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12, _ cal: Calendar = .current) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: hour)) ?? Date()
    }

    /// Parses "YYYY-MM-DD" at noon in `cal`, or nil when it is not a real calendar date.
    public static func parse(_ s: String, _ cal: Calendar = .current) -> Date? {
        let parts = s.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, s.count == 10, let d = cal.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12)) else { return nil }
        return localDate(d, cal) == s ? d : nil
    }
}
