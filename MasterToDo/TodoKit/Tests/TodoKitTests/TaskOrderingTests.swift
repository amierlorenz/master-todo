import Foundation
@testable import TodoKit
import Testing

@MainActor
struct TaskOrderingTests {
    let cal = Calendar.newYork

    @Test func orderingBuckets() {
        let now = cal.at(2026, 10, 21, 12)
        let noDate = TaskItem(title: "noDate")
        let later = TaskItem(title: "later", dueAt: cal.at(2026, 10, 25, 9), hasDueTime: true)
        let today = TaskItem(title: "today", dueAt: cal.at(2026, 10, 21, 18), hasDueTime: true)
        let overdue = TaskItem(title: "overdue", dueAt: cal.at(2026, 10, 20, 9), hasDueTime: true)
        let sorted = TaskOrdering.sorted([noDate, later, today, overdue], now: now, calendar: cal)
        #expect(sorted.map(\.title) == ["overdue", "today", "later", "noDate"])
    }

    @Test func tiesBrokenByCreation() {
        let now = cal.at(2026, 10, 21, 12)
        let second = TaskItem(title: "second")
        second.createdAt = cal.at(2026, 10, 2)
        let first = TaskItem(title: "first")
        first.createdAt = cal.at(2026, 10, 1)
        #expect(TaskOrdering.sorted([second, first], now: now, calendar: cal).map(\.title) == ["first", "second"])
    }

    @Test func lateNightCountsForOwnDay() {
        let now = cal.at(2026, 10, 21, 9)
        let lateTonight = TaskItem(title: "late", dueAt: cal.at(2026, 10, 21, 23, 30), hasDueTime: true)
        let tomorrow = TaskItem(title: "tomorrow", dueAt: cal.at(2026, 10, 22, 8), hasDueTime: true)
        #expect(TaskOrdering.bucket(of: lateTonight, now: now, calendar: cal) == .today)
        #expect(TaskOrdering.bucket(of: tomorrow, now: now, calendar: cal) == .later)
    }

    @Test func dateOnlyTodayIsNotOverdueAtNoon() {
        let now = cal.at(2026, 10, 21, 12)
        let task = TaskItem(title: "today", dueAt: cal.at(2026, 10, 21), hasDueTime: false)
        #expect(TaskOrdering.bucket(of: task, now: now, calendar: cal) == .today)
    }
}
