import Foundation
import KashTasksCore

func runRecurrenceTests(_ t: TestRunner) {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 9, _ min: Int = 30) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    t.expectTrue(Recurrence.nextDate(after: date(2026, 6, 14), rule: .none, calendar: cal) == nil, "none -> nil")

    t.expectEqual(Recurrence.nextDate(after: date(2026, 6, 14, 9, 30), rule: .daily, calendar: cal),
                  date(2026, 6, 15, 9, 30), "daily +1d")

    t.expectEqual(Recurrence.nextDate(after: date(2026, 6, 14), rule: .weekly, calendar: cal),
                  date(2026, 6, 21), "weekly +7d")

    t.expectEqual(Recurrence.nextDate(after: date(2026, 6, 14), rule: .monthly, calendar: cal),
                  date(2026, 7, 14), "monthly +1m")

    let jan31 = date(2026, 1, 31, 8, 0)
    let nextFromJan31 = Recurrence.nextDate(after: jan31, rule: .monthly, calendar: cal)!
    let comps = cal.dateComponents([.year, .month, .day], from: nextFromJan31)
    t.expectEqual(comps.month, 2, "monthly from Jan31 -> February")
    t.expectEqual(comps.day, 28, "monthly from Jan31 -> day 28")

    t.expectEqual(Recurrence.nextDate(after: date(2026, 6, 19), rule: .weekdays, calendar: cal),
                  date(2026, 6, 22), "weekdays Fri -> Mon")
    t.expectEqual(Recurrence.nextDate(after: date(2026, 6, 17), rule: .weekdays, calendar: cal),
                  date(2026, 6, 18), "weekdays Wed -> Thu")
    t.expectEqual(Recurrence.nextDate(after: date(2026, 6, 20), rule: .weekdays, calendar: cal),
                  date(2026, 6, 22), "weekdays Sat -> Mon")
}
