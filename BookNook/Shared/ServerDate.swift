import Foundation

/// The server stores timestamps as SQLite UTC strings ("2026-11-25 18:04:11").
enum ServerDate {
    private static let parser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    static func parse(_ value: String?) -> Date? {
        guard let value else { return nil }
        return parser.date(from: value)
    }

    /// Time of day only; chat shows the date in day separators.
    static func shortLabel(_ value: String?) -> String {
        guard let date = parse(value) else { return "" }
        return date.formatted(date: .omitted, time: .shortened)
    }

    static func isSameDay(_ a: String?, _ b: String?) -> Bool {
        guard let first = parse(a), let second = parse(b) else { return false }
        return Calendar.current.isDate(first, inSameDayAs: second)
    }

    /// "Hoy", "Ayer" or a date such as "lunes, 24 de noviembre".
    static func dayLabel(_ value: String?) -> String {
        guard let date = parse(value) else { return "" }
        if Calendar.current.isDateInToday(date) { return "Hoy" }
        if Calendar.current.isDateInYesterday(date) { return "Ayer" }
        let sameYear = Calendar.current.isDate(date, equalTo: .now, toGranularity: .year)
        let style: Date.FormatStyle = sameYear
            ? .dateTime.weekday(.wide).day().month(.wide)
            : .dateTime.day().month(.wide).year()
        return date.formatted(style.locale(Locale(identifier: "es")))
    }

    static func relative(_ value: String?) -> String {
        guard let date = parse(value) else { return "" }
        return date.formatted(.relative(presentation: .named).locale(Locale(identifier: "es")))
    }
}
