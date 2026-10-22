import Foundation
import SwiftData
@testable import TodoKit
import Testing

@MainActor
struct CanvasReconcilerTests {
    let container: ModelContainer
    let context: ModelContext
    let course: TrackedCourse
    let now = ISO8601DateFormatter().date(from: "2026-10-21T12:00:00Z")!

    init() throws {
        container = try TestContainer.make()
        context = container.mainContext
        course = TrackedCourse(canvasCourseID: 7, name: "Data Structures")
        course.isTracked = true
        context.insert(course)
    }

    func tasks() throws -> [TaskItem] {
        try context.fetch(FetchDescriptor<TaskItem>(sortBy: [SortDescriptor(\.title)]))
    }

    func task(_ assignmentID: Int) throws -> TaskItem? {
        try tasks().first { $0.canvasAssignmentID == assignmentID }
    }

    func sync(_ assignments: [CanvasAssignment]) throws -> CanvasReconciler.Result {
        try CanvasReconciler.reconcile(course: course, assignments: assignments, in: context, now: now)
    }

    @Test func firstSyncFilters() throws {
        let result = try sync([
            makeAssignment(id: 1, name: "open", due: "2026-10-25T03:59:00Z"),
            makeAssignment(id: 2, name: "submitted", state: "submitted"),
            makeAssignment(id: 3, name: "excused", excused: true),
            makeAssignment(id: 4, name: "gradedNoSubmission", state: "graded"),
            makeAssignment(id: 5, name: "locked", due: "2026-10-19T03:59:00Z", lock: "2026-10-20T03:59:00Z"),
            makeAssignment(id: 6, name: "pastDueUnlocked", due: "2026-10-19T03:59:00Z", lock: "2026-10-30T03:59:00Z"),
            makeAssignment(id: 7, name: "noDueDate"),
        ])
        #expect(try tasks().map(\.title) == ["noDueDate", "open", "pastDueUnlocked"])
        #expect(result.added == 3)
        #expect(course.firstSyncedAt == now)
        let open = try #require(try task(1))
        #expect(open.courseName == "Data Structures")
        #expect(open.hasDueTime)
        #expect(open.hasOnlineSubmission)
        #expect(try task(7)?.hasDueTime == false)
    }

    @Test func laterSyncAddsNewOpenOnly() throws {
        _ = try sync([makeAssignment(id: 1)])
        let result = try sync([makeAssignment(id: 1), makeAssignment(id: 2, name: "new"), makeAssignment(id: 3, name: "done", state: "submitted")])
        #expect(result.added == 1)
        #expect(try tasks().compactMap(\.canvasAssignmentID).sorted() == [1, 2])
    }

    @Test func dueDateMoveUpdatesAndBadges() throws {
        _ = try sync([makeAssignment(id: 1, due: "2026-10-25T03:59:00Z")])
        let result = try sync([makeAssignment(id: 1, name: "Renamed", due: "2026-10-27T03:59:00Z")])
        let moved = try #require(try task(1))
        #expect(moved.dueAt == ISO8601DateFormatter().date(from: "2026-10-27T03:59:00Z"))
        #expect(moved.title == "Renamed")
        #expect(moved.dueDateChanged)
        #expect(result.updated == 1)
    }

    @Test func unchangedDateDoesNotBadge() throws {
        _ = try sync([makeAssignment(id: 1, due: "2026-10-25T03:59:00Z")])
        _ = try sync([makeAssignment(id: 1, due: "2026-10-25T03:59:00Z")])
        #expect(try task(1)?.dueDateChanged == false)
    }

    @Test func doneTaskDateMoveStaysDone() throws {
        _ = try sync([makeAssignment(id: 1, due: "2026-10-25T03:59:00Z")])
        try task(1)?.state = .done
        _ = try sync([makeAssignment(id: 1, due: "2026-10-27T03:59:00Z")])
        let done = try #require(try task(1))
        #expect(done.state == .done)
        #expect(!done.dueDateChanged)
        #expect(done.dueAt == ISO8601DateFormatter().date(from: "2026-10-27T03:59:00Z"))
    }

    @Test func submittedFlagsNotRemoves() throws {
        _ = try sync([makeAssignment(id: 1)])
        _ = try sync([makeAssignment(id: 1, state: "submitted")])
        #expect(try task(1)?.canvasFlag(now: now) == .submitted)
        #expect(try task(1)?.state == .open)
    }

    @Test func missingFlagsGone() throws {
        _ = try sync([makeAssignment(id: 1), makeAssignment(id: 2)])
        let result = try sync([makeAssignment(id: 2)])
        #expect(try task(1)?.canvasFlag(now: now) == .removedFromCanvas)
        #expect(result.flaggedGone == 1)
    }

    @Test func reappearingClearsGone() throws {
        _ = try sync([makeAssignment(id: 1)])
        _ = try sync([])
        _ = try sync([makeAssignment(id: 1)])
        #expect(try task(1)?.isGoneFromCanvas == false)
    }

    @Test func tombstonedNotReAdded() throws {
        _ = try sync([makeAssignment(id: 1, due: "2026-10-25T03:59:00Z")])
        try task(1)?.remove(in: context)
        try context.save()
        _ = try sync([makeAssignment(id: 1, due: "2026-10-27T03:59:00Z")])
        #expect(try tasks().isEmpty)
    }

    @Test func pendingBecomesDoneWhenSubmitted() throws {
        _ = try sync([makeAssignment(id: 1)])
        try task(1)?.state = .pendingVerification
        let result = try sync([makeAssignment(id: 1, state: "submitted")])
        #expect(try task(1)?.state == .done)
        #expect(result.autoDismissed == 1)
    }

    @Test func pendingStaysPendingWhileUnsubmitted() throws {
        _ = try sync([makeAssignment(id: 1)])
        try task(1)?.state = .pendingVerification
        _ = try sync([makeAssignment(id: 1)])
        #expect(try task(1)?.state == .pendingVerification)
    }

    @Test func untrackedCourseTasksUntouched() throws {
        let other = TaskItem.canvas("other course", assignmentID: 99, courseID: 8)
        context.insert(other)
        _ = try sync([makeAssignment(id: 1)])
        #expect(!other.isGoneFromCanvas)
    }
}
