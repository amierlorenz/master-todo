import Foundation

/// Sorts the list: overdue, due today, later, then undated.
public enum TaskOrdering {
    public enum Bucket: Int, Comparable, Sendable {
        case overdue, today, later, noDate

        public static func < (lhs: Bucket, rhs: Bucket) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    @MainActor
    public static func bucket(of task: TaskItem, now: Date, calendar: Calendar) -> Bucket {
        guard let due = task.effectiveDue(calendar: calendar) else { return .noDate }
        if due < now { return .overdue }
        return calendar.isDate(due, inSameDayAs: now) ? .today : .later
    }

    @MainActor
    public static func sorted(_ tasks: [TaskItem], now: Date, calendar: Calendar) -> [TaskItem] {
        tasks.sorted { a, b in
            let (ba, bb) = (bucket(of: a, now: now, calendar: calendar), bucket(of: b, now: now, calendar: calendar))
            if ba != bb { return ba < bb }
            let (da, db) = (a.effectiveDue(calendar: calendar), b.effectiveDue(calendar: calendar))
            if da != db, let da, let db { return da < db }
            return a.createdAt < b.createdAt
        }
    }
}
