import Foundation

public struct PlannedNotification: Equatable, Sendable {
    public var id: String
    public var fireDate: Date
    public var title: String
    public var body: String

    public init(id: String, fireDate: Date, title: String, body: String) {
        self.id = id
        self.fireDate = fireDate
        self.title = title
        self.body = body
    }
}

/// Works out every pending notification from the current tasks: a daily
/// "N things due today" summary and a reminder 3 hours before each due time.
///
/// Notification content is fixed once scheduled, so the app replaces the
/// whole set whenever tasks or settings change.
@MainActor
public enum NotificationPlanner {
    /// iOS keeps at most 64 pending local notifications per app.
    public static let limit = 64
    static let reminderLead: TimeInterval = 3 * 60 * 60
    static let summaryDays = 7

    public static func plan(tasks: [TaskItem], trackedCourseIDs: Set<Int>, summaryTime: DateComponents, now: Date, calendar: Calendar) -> [PlannedNotification] {
        let countable = tasks.filter { $0.state != .done && $0.isVisible(trackedCourseIDs: trackedCourseIDs) }
        var planned: [PlannedNotification] = []

        let today = calendar.startOfDay(for: now)
        for offset in 0..<summaryDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let fireDate = calendar.date(bySettingHour: summaryTime.hour ?? 8, minute: summaryTime.minute ?? 0, second: 0, of: day),
                  fireDate > now else { continue }
            let count = countable.count { $0.effectiveDue(calendar: calendar).map { calendar.isDate($0, inSameDayAs: day) } ?? false }
            guard count > 0 else { continue }
            let parts = calendar.dateComponents([.year, .month, .day], from: day)
            planned.append(PlannedNotification(
                id: String(format: "summary-%04d-%02d-%02d", parts.year!, parts.month!, parts.day!),
                fireDate: fireDate,
                title: "Due today",
                body: count == 1 ? "1 thing due today" : "\(count) things due today"
            ))
        }

        let timeStyle = Date.FormatStyle(date: .omitted, time: .shortened, timeZone: calendar.timeZone)
        for task in countable where task.hasDueTime {
            guard let dueAt = task.dueAt else { continue }
            let fireDate = dueAt.addingTimeInterval(-reminderLead)
            guard fireDate > now else { continue }
            planned.append(PlannedNotification(
                id: "due-\(task.id)",
                fireDate: fireDate,
                title: "Due in 3 hours",
                body: "\(task.title) is due at \(dueAt.formatted(timeStyle))"
            ))
        }

        return Array(planned.sorted { $0.fireDate < $1.fireDate }.prefix(limit))
    }
}
