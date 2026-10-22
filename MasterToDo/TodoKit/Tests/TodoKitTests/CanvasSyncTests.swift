import Foundation
import SwiftData
@testable import TodoKit
import Testing

@MainActor
struct CanvasSyncTests {
    let base = URL(string: "https://school.instructure.com")!
    let now = ISO8601DateFormatter().date(from: "2026-10-21T12:00:00Z")!

    @Test func failedCourseSkippedOthersSynced() async throws {
        let container = try TestContainer.make()
        let context = container.mainContext
        for (id, name) in [(7, "DS"), (8, "Dropped")] {
            let course = TrackedCourse(canvasCourseID: id, name: name)
            course.isTracked = true
            course.firstSyncedAt = now
            context.insert(course)
        }
        let essay = TaskItem.canvas("Essay", assignmentID: 1, courseID: 7, dueAt: Date(timeIntervalSince1970: 0))
        let lab = TaskItem.canvas("Lab", assignmentID: 2, courseID: 8, dueAt: Date(timeIntervalSince1970: 0))
        context.insert(essay)
        context.insert(lab)
        let stub = StubURLProtocol.stub([
            "/api/v1/courses/7/assignments": .init(body: "[\(assignmentJSON(id: 1, due: "2026-10-30T03:59:00Z"))]"),
            "/api/v1/courses/8/assignments": .init(status: 401, body: "{}"),
        ])
        let sync = CanvasSync(context: context, client: CanvasClient(baseURL: base, token: "t", session: stub.session))

        let result = try await sync.run(now: now)

        #expect(result.failedCourses == ["Dropped"])
        #expect(essay.dueAt == ISO8601DateFormatter().date(from: "2026-10-30T03:59:00Z"))
        #expect(!lab.isGoneFromCanvas)
        #expect(lab.dueAt == Date(timeIntervalSince1970: 0))
    }

    @Test func everyCourseFailingThrows() async throws {
        let container = try TestContainer.make()
        let context = container.mainContext
        let course = TrackedCourse(canvasCourseID: 7, name: "DS")
        course.isTracked = true
        context.insert(course)
        let existing = TaskItem.canvas("Essay", assignmentID: 1, courseID: 7)
        context.insert(existing)
        let stub = StubURLProtocol.stub(["/api/v1/courses/7/assignments": .init(status: 401, body: "{}")])
        let sync = CanvasSync(context: context, client: CanvasClient(baseURL: base, token: "bad", session: stub.session))

        await #expect(throws: CanvasClient.ClientError.unauthorized) { try await sync.run(now: now) }
        #expect(!existing.isGoneFromCanvas)
    }

    @Test func runReconcilesTrackedCoursesOnly() async throws {
        let container = try TestContainer.make()
        let context = container.mainContext
        let tracked = TrackedCourse(canvasCourseID: 7, name: "DS")
        tracked.isTracked = true
        context.insert(tracked)
        context.insert(TrackedCourse(canvasCourseID: 8, name: "Club"))
        let stub = StubURLProtocol.stub([
            "/api/v1/courses/7/assignments": .init(body: "[\(assignmentJSON(id: 1))]"),
            "/api/v1/courses/8/assignments": .init(body: "[\(assignmentJSON(id: 2))]"),
        ])
        let result = try await CanvasSync(context: context, client: CanvasClient(baseURL: base, token: "t", session: stub.session)).run(now: now)

        #expect(result.added == 1)
        #expect(try context.fetch(FetchDescriptor<TaskItem>()).compactMap(\.canvasAssignmentID) == [1])
        #expect(stub.requests.allSatisfy { $0.url?.path().contains("/8/") == false })
    }

    @Test func refreshCoursesAddsUntrackedAndCountsNew() async throws {
        let container = try TestContainer.make()
        let context = container.mainContext
        let known = TrackedCourse(canvasCourseID: 7, name: "Old name")
        known.isTracked = true
        known.hasBeenOffered = true
        context.insert(known)
        let stub = StubURLProtocol.stub([
            "/api/v1/courses": .init(body: #"[{"id":7,"name":"Data Structures"},{"id":8,"name":"Orientation"}]"#),
        ])

        let newCount = try await CanvasSync(context: context, client: CanvasClient(baseURL: base, token: "t", session: stub.session)).refreshCourses()

        #expect(newCount == 1)
        let courses = try context.fetch(FetchDescriptor<TrackedCourse>(sortBy: [SortDescriptor(\.canvasCourseID)]))
        #expect(courses.map(\.name) == ["Data Structures", "Orientation"])
        #expect(courses.map(\.isTracked) == [true, false])
    }
}
