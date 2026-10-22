import Foundation
import SwiftData

/// Folds one course's fetched assignments into the task list.
///
/// Sync never deletes a Canvas task: submitted, closed, and vanished
/// assignments are flagged for the user to remove. Removed ones are
/// tombstoned and never come back.
@MainActor
public enum CanvasReconciler {
    public struct Result: Equatable, Sendable {
        public var added = 0
        public var updated = 0
        public var flaggedGone = 0
        /// Pending tasks that Canvas now confirms as submitted.
        public var autoDismissed = 0
        /// Courses Canvas wouldn't return (dropped, unpublished, or unreachable); their tasks were left as they were.
        public var failedCourses: [String] = []

        public init() {}

        static func + (lhs: Result, rhs: Result) -> Result {
            var sum = lhs
            sum.added += rhs.added
            sum.updated += rhs.updated
            sum.flaggedGone += rhs.flaggedGone
            sum.autoDismissed += rhs.autoDismissed
            sum.failedCourses += rhs.failedCourses
            return sum
        }
    }

    @discardableResult
    public static func reconcile(course: TrackedCourse, assignments: [CanvasAssignment], in context: ModelContext, now: Date) throws -> Result {
        let courseID = course.canvasCourseID
        let tombstoned = Set(try context.fetch(FetchDescriptor<RemovedCanvasItem>()).map(\.canvasAssignmentID))
        let existing = try context.fetch(FetchDescriptor<TaskItem>()).filter { $0.canvasCourseID == courseID && $0.isCanvas }
        let byID = Dictionary(existing.map { ($0.canvasAssignmentID!, $0) }, uniquingKeysWith: { first, _ in first })
        var result = Result()

        for assignment in assignments where !tombstoned.contains(assignment.id) {
            if let task = byID[assignment.id] {
                if update(task, from: assignment, courseName: course.name, now: now) { result.updated += 1 }
                if task.state == .pendingVerification, assignment.isSubmitted {
                    task.state = .done
                    result.autoDismissed += 1
                }
            } else if !assignment.isSubmitted, !assignment.isClosed(now: now) {
                let task = TaskItem(title: assignment.name, dueAt: assignment.dueAt, hasDueTime: assignment.dueAt != nil)
                task.canvasAssignmentID = assignment.id
                task.canvasCourseID = courseID
                update(task, from: assignment, courseName: course.name, now: now)
                context.insert(task)
                result.added += 1
            }
        }

        let fetchedIDs = Set(assignments.map(\.id))
        for task in existing where !fetchedIDs.contains(task.canvasAssignmentID!) && !task.isGoneFromCanvas {
            task.isGoneFromCanvas = true
            result.flaggedGone += 1
        }

        if course.firstSyncedAt == nil { course.firstSyncedAt = now }
        return result
    }

    /// Copies Canvas fields onto the task. Returns whether anything visible changed.
    @discardableResult
    private static func update(_ task: TaskItem, from assignment: CanvasAssignment, courseName: String, now: Date) -> Bool {
        let changed = task.title != assignment.name || task.dueAt != assignment.dueAt || task.lockAt != assignment.lockAt
            || task.isSubmittedOnCanvas != assignment.isSubmitted || task.isGoneFromCanvas
        if task.dueAt != assignment.dueAt {
            task.dueAt = assignment.dueAt
            task.hasDueTime = assignment.dueAt != nil
            if task.state != .done { task.dueDateChanged = true }
        }
        task.title = assignment.name
        task.lockAt = assignment.lockAt
        task.submissionTypes = assignment.submissionTypes
        task.isSubmittedOnCanvas = assignment.isSubmitted
        task.isGoneFromCanvas = false
        task.courseName = courseName
        task.htmlURL = assignment.htmlURL?.absoluteString ?? task.htmlURL
        task.lastSyncedAt = now
        return changed
    }
}
