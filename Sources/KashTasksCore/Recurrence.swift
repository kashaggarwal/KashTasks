import Foundation

public enum Recurrence: String, Codable, CaseIterable, Sendable {
    case none, daily, weekdays, weekly, monthly

    public var label: String {
        switch self {
        case .none:     return "None"
        case .daily:    return "Daily"
        case .weekdays: return "Weekdays"
        case .weekly:   return "Weekly"
        case .monthly:  return "Monthly"
        }
    }

    /// The next occurrence after `date`, preserving the original clock time.
    /// Returns nil for `.none`.
    public static func nextDate(after date: Date, rule: Recurrence, calendar: Calendar = .current) -> Date? {
        switch rule {
        case .none:
            return nil
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date)
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date)
        case .weekdays:
            var next = date
            repeat {
                guard let advanced = calendar.date(byAdding: .day, value: 1, to: next) else { return nil }
                next = advanced
            } while calendar.isDateInWeekend(next)
            return next
        }
    }
}
