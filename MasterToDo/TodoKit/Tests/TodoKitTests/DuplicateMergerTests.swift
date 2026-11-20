import Foundation
import SwiftData
@testable import TodoKit
import Testing

@MainActor
struct DuplicateMergerTests {
    @Test func keepsMostAdvancedState() throws {
        let container = try TestContainer.make()
        let context = container.mainContext
        let open = TaskItem.canvas("A", assignmentID: 1)
        let done = TaskItem.canvas("A", assignmentID: 1)
        done.state = .done
        context.insert(open)
        context.insert(done)
        context.insert(TaskItem(title: "own 1"))
        context.insert(TaskItem(title: "own 2"))

        #expect(try DuplicateMerger.mergeAll(in: context) == 1)

        let canvas = try context.fetch(FetchDescriptor<TaskItem>()).filter(\.isCanvas)
        #expect(canvas.map(\.state) == [.done])
        #expect(try context.fetchCount(FetchDescriptor<TaskItem>()) == 3)
    }

    @Test func keeperTakesNewestCanvasFields() throws {
        let container = try TestContainer.make()
        let context = container.mainContext
        let stale = TaskItem.canvas("Old name", assignmentID: 1)
        stale.state = .done
        stale.lastSyncedAt = Date(timeIntervalSince1970: 100)
        let fresh = TaskItem.canvas("New name", assignmentID: 1, dueAt: Date(timeIntervalSince1970: 5000))
        fresh.lastSyncedAt = Date(timeIntervalSince1970: 200)
        context.insert(stale)
        context.insert(fresh)

        try DuplicateMerger.mergeAll(in: context)

        let kept = try #require(try context.fetch(FetchDescriptor<TaskItem>()).first)
        #expect(kept.state == .done)
        #expect(kept.title == "New name")
        #expect(kept.dueAt == Date(timeIntervalSince1970: 5000))
    }

    @Test func dismissalSurvivesMerge() throws {
        let container = try TestContainer.make()
        let context = container.mainContext
        let keeper = TaskItem.canvas("A", assignmentID: 1)
        keeper.state = .done
        let dismissed = TaskItem.canvas("A", assignmentID: 1)
        dismissed.submittedDismissed = true
        context.insert(keeper)
        context.insert(dismissed)

        try DuplicateMerger.mergeAll(in: context)

        let kept = try #require(try context.fetch(FetchDescriptor<TaskItem>()).first)
        #expect(kept.state == .done)
        #expect(kept.submittedDismissed)
    }

    @Test func tombstoneDeletesAllCopies() throws {
        let container = try TestContainer.make()
        let context = container.mainContext
        context.insert(TaskItem.canvas("A", assignmentID: 1))
        context.insert(TaskItem.canvas("A", assignmentID: 1))
        context.insert(RemovedCanvasItem(canvasAssignmentID: 1))
        context.insert(RemovedCanvasItem(canvasAssignmentID: 1))

        try DuplicateMerger.mergeAll(in: context)

        #expect(try context.fetchCount(FetchDescriptor<TaskItem>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<RemovedCanvasItem>()) == 1)
    }

    @Test func mergesCourses() throws {
        let container = try TestContainer.make()
        let context = container.mainContext
        let a = TrackedCourse(canvasCourseID: 7, name: "DS")
        let b = TrackedCourse(canvasCourseID: 7, name: "DS")
        b.isTracked = true
        b.firstSyncedAt = Date(timeIntervalSince1970: 100)
        context.insert(a)
        context.insert(b)

        try DuplicateMerger.mergeAll(in: context)

        let courses = try context.fetch(FetchDescriptor<TrackedCourse>())
        #expect(courses.count == 1)
        #expect(courses.first?.isTracked == true)
        #expect(courses.first?.firstSyncedAt == Date(timeIntervalSince1970: 100))
    }

    @Test(arguments: [false, true])
    func sameCourseSurvivesInEitherInsertOrder(reversed: Bool) throws {
        let container = try TestContainer.make()
        let context = container.mainContext
        let a = TrackedCourse(canvasCourseID: 7, name: "DS")
        a.id = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!
        let b = TrackedCourse(canvasCourseID: 7, name: "DS")
        b.id = UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!
        for course in reversed ? [b, a] : [a, b] { context.insert(course) }

        try DuplicateMerger.mergeAll(in: context)

        #expect(try context.fetch(FetchDescriptor<TrackedCourse>()).map(\.id) == [a.id])
    }

    @Test(arguments: [false, true])
    func sameTombstoneSurvivesInEitherInsertOrder(reversed: Bool) throws {
        let container = try TestContainer.make()
        let context = container.mainContext
        let a = RemovedCanvasItem(canvasAssignmentID: 1)
        a.id = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!
        let b = RemovedCanvasItem(canvasAssignmentID: 1)
        b.id = UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!
        for item in reversed ? [b, a] : [a, b] { context.insert(item) }

        try DuplicateMerger.mergeAll(in: context)

        #expect(try context.fetch(FetchDescriptor<RemovedCanvasItem>()).map(\.id) == [a.id])
    }

    @Test(arguments: [false, true])
    func sameTaskSurvivesFullTieInEitherInsertOrder(reversed: Bool) throws {
        let container = try TestContainer.make()
        let context = container.mainContext
        let created = Date(timeIntervalSince1970: 100)
        let a = TaskItem.canvas("A", assignmentID: 1)
        a.id = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!
        a.createdAt = created
        let b = TaskItem.canvas("A", assignmentID: 1)
        b.id = UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!
        b.createdAt = created
        for task in reversed ? [b, a] : [a, b] { context.insert(task) }

        try DuplicateMerger.mergeAll(in: context)

        #expect(try context.fetch(FetchDescriptor<TaskItem>()).map(\.id) == [a.id])
    }

    @Test func externalTombstoneDeletesAllCopies() throws {
        let container = try TestContainer.make()
        let context = container.mainContext
        let task1 = TaskItem(title: "Articulate 1", source: .articulate, externalID: "task:1:2")
        let task2 = TaskItem(title: "Articulate 2", source: .articulate, externalID: "task:1:2")
        let tombstone1 = RemovedExternalItem(source: .articulate, externalID: "task:1:2")
        let tombstone2 = RemovedExternalItem(source: .articulate, externalID: "task:1:2")
        context.insert(task1)
        context.insert(task2)
        context.insert(tombstone1)
        context.insert(tombstone2)

        try DuplicateMerger.mergeAll(in: context)

        #expect(try context.fetchCount(FetchDescriptor<TaskItem>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<RemovedExternalItem>()) == 1)
    }

    @Test func mergesExternalTasksAcrossDevices() throws {
        let container = try TestContainer.make()
        let context = container.mainContext
        let open = TaskItem(title: "Initial title", source: .articulate, externalID: "task:10:20")
        let done = TaskItem(title: "Updated title", source: .articulate, externalID: "task:10:20")
        done.state = .done
        done.notes = "Context notes"
        context.insert(open)
        context.insert(done)

        try DuplicateMerger.mergeAll(in: context)

        let items = try context.fetch(FetchDescriptor<TaskItem>())
        #expect(items.count == 1)
        let kept = try #require(items.first)
        #expect(kept.state == .done)
        #expect(kept.notes == "Context notes")
    }
}
