import Foundation
@testable import TodoKit
import Testing

@MainActor
struct NotificationPlannerTests {
    let cal = Calendar.newYork
    let eight = DateComponents(hour: 8, minute: 0)

    func plan(_ tasks: [TaskItem], tracked: Set<Int> = [7], now: Date) -> [PlannedNotification] {
        NotificationPlanner.plan(tasks: tasks, trackedCourseIDs: tracked, summaryTime: eight, now: now, calendar: cal)
    }

    func due(_ title: String, _ date: Date) -> TaskItem {
        TaskItem(title: title, dueAt: date, hasDueTime: true)
    }

    @Test func summaryCountsTodayIncludingPending() {
        let now = cal.at(2026, 10, 21, 7)
        let pending = due("pending", cal.at(2026, 10, 21, 9))
        pending.state = .pendingVerification
        let done = due("done", cal.at(2026, 10, 21, 9))
        done.state = .done
        let hidden = TaskItem.canvas("hidden", assignmentID: 1, courseID: 8, dueAt: cal.at(2026, 10, 21, 9))
        let tasks = [due("a", cal.at(2026, 10, 21, 9)), due("b", cal.at(2026, 10, 21, 23, 30)), pending, done, hidden]

        let summaries = plan(tasks, now: now).filter { $0.id.hasPrefix("summary-") }

        #expect(summaries == [PlannedNotification(id: "summary-2026-10-21", fireDate: cal.at(2026, 10, 21, 8), title: "Due today", body: "3 things due today")])
    }

    @Test func singularSummary() {
        let summaries = plan([due("a", cal.at(2026, 10, 21, 9))], now: cal.at(2026, 10, 21, 7)).filter { $0.id.hasPrefix("summary-") }
        #expect(summaries.map(\.body) == ["1 thing due today"])
    }

    @Test func noSummaryWhenZero() {
        #expect(plan([TaskItem(title: "undated")], now: cal.at(2026, 10, 21, 7)).isEmpty)
    }

    @Test func summaryAlreadyPassedSkipped() {
        let tasks = [due("today", cal.at(2026, 10, 21, 20)), due("tomorrow", cal.at(2026, 10, 22, 20))]
        let summaries = plan(tasks, now: cal.at(2026, 10, 21, 9)).filter { $0.id.hasPrefix("summary-") }
        #expect(summaries.map(\.id) == ["summary-2026-10-22"])
    }

    @Test func summaryCoversSevenDaysOnly() {
        let tasks = [due("day6", cal.at(2026, 10, 27, 12)), due("day7", cal.at(2026, 10, 28, 12))]
        let summaries = plan(tasks, now: cal.at(2026, 10, 21, 7)).filter { $0.id.hasPrefix("summary-") }
        #expect(summaries.map(\.id) == ["summary-2026-10-27"])
    }

    @Test func dateOnlyTaskCountsInSummary() {
        let task = TaskItem(title: "read", dueAt: cal.at(2026, 10, 21), hasDueTime: false)
        let all = plan([task], now: cal.at(2026, 10, 21, 7))
        #expect(all.map(\.id) == ["summary-2026-10-21"])
    }

    @Test func reminderThreeHoursBefore() {
        let task = due("Essay", cal.at(2026, 10, 21, 15))
        let reminder = plan([task], now: cal.at(2026, 10, 21, 7)).first { $0.id == "due-\(task.id)" }
        #expect(reminder?.fireDate == cal.at(2026, 10, 21, 12))
        #expect(reminder?.title == "Due in 3 hours")
        #expect(reminder?.body.hasPrefix("Essay is due at ") == true)
    }

    @Test func reminderSkippedInsideWindow() {
        let task = due("Soon", cal.at(2026, 10, 21, 9, 30))
        #expect(!plan([task], now: cal.at(2026, 10, 21, 7)).contains { $0.id.hasPrefix("due-") })
    }

    @Test func dateOnlyOwnTaskNoReminder() {
        let task = TaskItem(title: "read", dueAt: cal.at(2026, 10, 23), hasDueTime: false)
        #expect(!plan([task], now: cal.at(2026, 10, 21, 7)).contains { $0.id.hasPrefix("due-") })
    }

    @Test func hiddenTasksExcluded() {
        let hidden = TaskItem.canvas("hidden", assignmentID: 1, courseID: 8, dueAt: cal.at(2026, 10, 22, 15))
        #expect(plan([hidden], now: cal.at(2026, 10, 21, 7)).isEmpty)
    }

    @Test func capsAt64Earliest() {
        let tasks = (0..<100).map { due("t\($0)", cal.at(2026, 11, 1, 12).addingTimeInterval(Double($0) * 3600)) }
        let planned = plan(tasks, now: cal.at(2026, 10, 21, 7))
        #expect(planned.count == 64)
        #expect(planned.map(\.fireDate) == planned.map(\.fireDate).sorted())
        #expect(planned.first?.fireDate == cal.at(2026, 11, 1, 9))
    }

    @Test func summaryAcrossDSTStaysLocal() {
        let task = due("after DST", cal.at(2026, 11, 2, 15))
        let summary = plan([task], now: cal.at(2026, 10, 31, 9)).first { $0.id == "summary-2026-11-02" }
        #expect(summary?.fireDate == cal.at(2026, 11, 2, 8))
        #expect(cal.component(.hour, from: summary!.fireDate) == 8)
    }
}
