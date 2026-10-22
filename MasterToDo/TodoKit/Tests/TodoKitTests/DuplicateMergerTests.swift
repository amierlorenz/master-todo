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
}
