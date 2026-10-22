import Foundation
import SwiftData
@testable import TodoKit
import Testing

@MainActor
struct TaskItemTests {
    let cal = Calendar.newYork

    @Test func effectiveDueDateOnlyIsEndOfDay() {
        let task = TaskItem(title: "Read", dueAt: cal.at(2026, 10, 21, 0, 0), hasDueTime: false)
        #expect(task.effectiveDue(calendar: cal) == cal.at(2026, 10, 21, 23, 59))
    }

    @Test func effectiveDueWithTimeIsDueAt() {
        let task = TaskItem(title: "Read", dueAt: cal.at(2026, 10, 21, 15, 0), hasDueTime: true)
        #expect(task.effectiveDue(calendar: cal) == cal.at(2026, 10, 21, 15, 0))
    }

    @Test func canvasFlagPriority() {
        let now = cal.at(2026, 10, 21, 12)
        let gone = TaskItem.canvas("A", assignmentID: 1)
        gone.isGoneFromCanvas = true
        gone.isSubmittedOnCanvas = true
        #expect(gone.canvasFlag(now: now) == .removedFromCanvas)

        let submitted = TaskItem.canvas("B", assignmentID: 2)
        submitted.isSubmittedOnCanvas = true
        submitted.lockAt = cal.at(2026, 10, 20)
        #expect(submitted.canvasFlag(now: now) == .submitted)

        let closed = TaskItem.canvas("C", assignmentID: 3)
        closed.lockAt = cal.at(2026, 10, 20)
        #expect(closed.canvasFlag(now: now) == .closed)

        closed.state = .done
        #expect(closed.canvasFlag(now: now) == nil)

        let own = TaskItem(title: "Mine")
        own.lockAt = cal.at(2026, 10, 20)
        #expect(own.canvasFlag(now: now) == nil)
        #expect(TaskItem.canvas("D", assignmentID: 4).canvasFlag(now: now) == nil)
    }

    @Test func removeLeavesTombstoneForCanvasOnly() throws {
        let container = try TestContainer.make()
        let context = container.mainContext
        let canvas = TaskItem.canvas("A", assignmentID: 42)
        let own = TaskItem(title: "Mine")
        context.insert(canvas)
        context.insert(own)

        canvas.remove(in: context)
        own.remove(in: context)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<TaskItem>()) == 0)
        #expect(try context.fetch(FetchDescriptor<RemovedCanvasItem>()).map(\.canvasAssignmentID) == [42])
    }

    @Test func submissionTypesRoundTrip() {
        let task = TaskItem.canvas("A", assignmentID: 1)
        #expect(!task.hasOnlineSubmission)
        task.submissionTypes = ["on_paper", "online_upload"]
        #expect(task.submissionTypesRaw == "on_paper,online_upload")
        #expect(task.hasOnlineSubmission)
    }

    @Test func visibilityFollowsTrackedCourses() {
        #expect(TaskItem(title: "Mine").isVisible(trackedCourseIDs: []))
        #expect(TaskItem.canvas("A", assignmentID: 1, courseID: 7).isVisible(trackedCourseIDs: [7]))
        #expect(!TaskItem.canvas("A", assignmentID: 1, courseID: 8).isVisible(trackedCourseIDs: [7]))
    }
}
