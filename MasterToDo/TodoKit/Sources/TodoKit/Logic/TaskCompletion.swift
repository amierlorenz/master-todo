import Foundation

/// Checks tasks off, asking Canvas first when it can confirm the submission.
@MainActor
public enum TaskCompletion {
    /// Marks the task done, or pending when Canvas hasn't recorded an online
    /// submission (or can't be reached). Returns the new state.
    @discardableResult
    public static func complete(
        _ task: TaskItem,
        fetch: (_ courseID: Int, _ assignmentID: Int) async throws -> CanvasAssignment
    ) async -> TaskState {
        guard let assignmentID = task.canvasAssignmentID, let courseID = task.canvasCourseID, task.hasOnlineSubmission else {
            task.state = .done
            return .done
        }
        let submitted = (try? await fetch(courseID, assignmentID))?.isSubmitted
        if let submitted { task.isSubmittedOnCanvas = submitted }
        task.state = submitted == true ? .done : .pendingVerification
        return task.state
    }

    public static func uncheck(_ task: TaskItem) {
        task.state = .open
    }
}
