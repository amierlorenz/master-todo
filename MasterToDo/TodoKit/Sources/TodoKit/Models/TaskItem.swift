import Foundation
import SwiftData

public enum TaskState: String, Codable, Sendable {
    case open
    /// Checked off in the app, but Canvas hasn't confirmed the submission yet.
    case pendingVerification
    case done

    /// Higher means further along; duplicate merging keeps the highest.
    public var rank: Int {
        switch self {
        case .open: 0
        case .pendingVerification: 1
        case .done: 2
        }
    }
}

/// Why a Canvas task needs the user's attention before they remove it.
public enum CanvasFlag: Sendable {
    case submitted
    case closed
    case removedFromCanvas
}

/// One entry in the list: either the user's own task or a Canvas assignment.
@Model
public final class TaskItem {
    public var id: UUID = UUID()
    public var title: String = ""
    public var dueAt: Date?
    /// When false, only the day of `dueAt` matters.
    public var hasDueTime: Bool = false
    public var createdAt: Date = Date.now
    public var stateRaw: String = TaskState.open.rawValue

    public var canvasAssignmentID: Int?
    public var canvasCourseID: Int?
    public var courseName: String?
    public var htmlURL: String?
    public var lockAt: Date?
    /// Canvas `submission_types`, comma-joined.
    public var submissionTypesRaw: String = ""
    public var isSubmittedOnCanvas: Bool = false
    public var isGoneFromCanvas: Bool = false
    /// Canvas moved the due date since the user last looked at the task.
    public var dueDateChanged: Bool = false
    public var lastSyncedAt: Date?

    public init(title: String, dueAt: Date? = nil, hasDueTime: Bool = false) {
        self.title = title
        self.dueAt = dueAt
        self.hasDueTime = hasDueTime
    }

    public var state: TaskState {
        get { TaskState(rawValue: stateRaw) ?? .open }
        set { stateRaw = newValue.rawValue }
    }

    public var isCanvas: Bool { canvasAssignmentID != nil }

    public var submissionTypes: [String] {
        get { submissionTypesRaw.split(separator: ",").map(String.init) }
        set { submissionTypesRaw = newValue.joined(separator: ",") }
    }

    public var hasOnlineSubmission: Bool {
        submissionTypes.contains(where: CanvasAssignment.onlineSubmissionTypes.contains)
    }

    /// The moment the task is due; a date-only task is due at 11:59 PM that day.
    public func effectiveDue(calendar: Calendar) -> Date? {
        guard let dueAt else { return nil }
        if hasDueTime { return dueAt }
        return calendar.date(bySettingHour: 23, minute: 59, second: 0, of: dueAt)
    }

    public func canvasFlag(now: Date) -> CanvasFlag? {
        guard isCanvas, state != .done else { return nil }
        if isGoneFromCanvas { return .removedFromCanvas }
        if isSubmittedOnCanvas { return .submitted }
        if let lockAt, lockAt <= now { return .closed }
        return nil
    }

    /// Own tasks always show; Canvas tasks only while their course is tracked.
    public func isVisible(trackedCourseIDs: Set<Int>) -> Bool {
        guard let canvasCourseID else { return true }
        return trackedCourseIDs.contains(canvasCourseID)
    }

    /// Deletes the task; a Canvas task leaves a tombstone so sync never re-adds it.
    public func remove(in context: ModelContext) {
        if let canvasAssignmentID {
            context.insert(RemovedCanvasItem(canvasAssignmentID: canvasAssignmentID))
        }
        context.delete(self)
    }
}
