import Foundation
@testable import TodoKit
import Testing

@MainActor
struct TaskFilterTests {
    let cal = Calendar.newYork
    let now = Calendar.newYork.at(2026, 10, 21, 12)

    var tasks: [TaskItem] {
        let closing = TaskItem.canvas("closing", assignmentID: 1, dueAt: cal.at(2026, 10, 20))
        closing.lockAt = cal.at(2026, 10, 23)
        let overdue = TaskItem.canvas("overdue", assignmentID: 2, dueAt: cal.at(2026, 10, 19))
        let upcoming = TaskItem(title: "upcoming", dueAt: cal.at(2026, 10, 25), hasDueTime: true)
        let undated = TaskItem(title: "undated")
        let done = TaskItem.canvas("done", assignmentID: 3, dueAt: cal.at(2026, 10, 25))
        done.state = .done
        return [closing, overdue, upcoming, undated, done]
    }

    private func shown(_ selection: FilterSelection) -> [String] {
        tasks.filter { selection.passes($0, now: now, calendar: cal) }.map(\.title)
    }

    @Test func nothingPickedHidesDone() {
        #expect(shown(FilterSelection()) == ["closing", "overdue", "upcoming", "undated"])
    }

    @Test func pickingReplacesWithinGroupAndCombinesAcross() {
        var selection = FilterSelection()
        selection.toggle(.overdue)
        selection.toggle(.done)
        #expect(selection.picked == [.done])
        #expect(shown(selection) == ["done"])

        selection.toggle(.manual)
        #expect(shown(selection).isEmpty)
        selection.toggle(.done)
        #expect(shown(selection) == ["upcoming", "undated"])
    }

    @Test func noticesMatchUndismissedOnly() {
        let submitted = TaskItem.canvas("submitted", assignmentID: 4)
        submitted.isSubmittedOnCanvas = true
        let closed = TaskItem.canvas("closed", assignmentID: 5, dueAt: cal.at(2026, 10, 19))
        closed.lockAt = cal.at(2026, 10, 20)
        let moved = TaskItem(title: "moved")
        moved.dueDateChanged = true

        #expect(TaskFilter.submitted.matches(submitted, now: now, calendar: cal))
        #expect(TaskFilter.closed.matches(closed, now: now, calendar: cal))
        #expect(TaskFilter.dateChanged.matches(moved, now: now, calendar: cal))
        submitted.submittedDismissed = true
        #expect(!TaskFilter.submitted.matches(submitted, now: now, calendar: cal))
    }

    @Test func countsRespectOtherGroups() {
        var selection = FilterSelection()
        selection.toggle(.canvas)
        #expect(selection.count(.upcoming, in: tasks, now: now, calendar: cal) == 0)
        #expect(selection.count(.closing, in: tasks, now: now, calendar: cal) == 1)
        selection.toggle(.closing)
        #expect(selection.count(.manual, in: tasks, now: now, calendar: cal) == 0)
        #expect(selection.count(.canvas, in: tasks, now: now, calendar: cal) == 1)
    }
}
