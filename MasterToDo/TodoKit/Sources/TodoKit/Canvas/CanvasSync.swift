import Foundation
import SwiftData

/// Pulls Canvas into the task list for every course the user tracks.
@MainActor
public struct CanvasSync {
    private let context: ModelContext
    private let client: CanvasClient

    public init(context: ModelContext, client: CanvasClient) {
        self.context = context
        self.client = client
    }

    /// Fetches every tracked course before touching any task, so one failed
    /// course can't make its assignments look deleted.
    @discardableResult
    public func run(now: Date = .now) async throws -> CanvasReconciler.Result {
        let courses = try context.fetch(FetchDescriptor<TrackedCourse>()).filter(\.isTracked)
        var fetched: [(TrackedCourse, [CanvasAssignment])] = []
        for course in courses {
            fetched.append((course, try await client.assignments(courseID: course.canvasCourseID)))
        }
        var result = CanvasReconciler.Result()
        for (course, assignments) in fetched {
            result = result + (try CanvasReconciler.reconcile(course: course, assignments: assignments, in: context, now: now))
        }
        try context.save()
        try DuplicateMerger.mergeAll(in: context)
        return result
    }

    /// Adds active courses not seen before (untracked) and refreshes names.
    /// Returns how many active courses the user hasn't been shown yet.
    @discardableResult
    public func refreshCourses() async throws -> Int {
        let active = try await client.activeCourses()
        let known = Dictionary(try context.fetch(FetchDescriptor<TrackedCourse>()).map { ($0.canvasCourseID, $0) }, uniquingKeysWith: { first, _ in first })
        var notOffered = 0
        for canvasCourse in active {
            let course = known[canvasCourse.id] ?? {
                let course = TrackedCourse(canvasCourseID: canvasCourse.id, name: canvasCourse.name)
                context.insert(course)
                return course
            }()
            course.name = canvasCourse.name
            if !course.hasBeenOffered { notOffered += 1 }
        }
        try context.save()
        return notOffered
    }
}
