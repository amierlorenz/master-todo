import Foundation

public struct DueLabel: Sendable {
    public let value: String
    public let caption: String?

    @MainActor
    public init?(_ task: TaskItem, now: Date, calendar: Calendar) {
        guard let due = task.effectiveDue(calendar: calendar) else { return nil }
        switch TaskOrdering.bucket(of: task, now: now, calendar: calendar) {
        case .closing:
            (value, caption) = (Countdown.text(from: now, to: task.lockAt ?? now), "left")
        case .overdue:
            (value, caption) = (Countdown.text(from: due, to: now), "late")
        case .today:
            (value, caption) = (Countdown.text(from: now, to: due), "left")
        case .later:
            let style = Date.FormatStyle(locale: calendar.locale ?? .current, calendar: calendar, timeZone: calendar.timeZone)
            let withinWeek = due.timeIntervalSince(now) < 7 * 86_400
            value = due.formatted(withinWeek ? style.weekday(.abbreviated) : style.month(.twoDigits).day(.twoDigits))
            caption = nil
        case .noDate:
            return nil
        }
    }
}
