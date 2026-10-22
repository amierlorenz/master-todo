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

    /// Reconciles only the courses whose every page arrived, so a failed
    /// course can't make its assignments look deleted, and one dropped course
    /// can't block the rest. Throws only when every tracked course failed.
    @discardableResult
    public func run(now: Date = .now) async throws -> CanvasReconciler.Result {
        let courses = try context.fetch(FetchDescriptor<TrackedCourse>()).filter(\.isTracked)
        var fetched: [(TrackedCourse, [CanvasAssignment])] = []
        var result = CanvasReconciler.Result()
        var firstError: (any Error)?
        for course in courses {
            do {
                fetched.append((course, try await client.assignments(courseID: course.canvasCourseID)))
            } catch {
                firstError = firstError ?? error
                result.failedCourses.append(course.name)
            }
        }
        if fetched.isEmpty, let firstError { throw firstError }
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
