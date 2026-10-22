import Foundation
import SwiftData

/// An active Canvas course and whether the user syncs it.
@Model
public final class TrackedCourse {
    /// Breaks ties when merging duplicates, so every device keeps the same record.
    public var id: UUID = UUID()
    public var canvasCourseID: Int = 0
    public var name: String = ""
    public var isTracked: Bool = false
    /// Shown to the user at least once, so it no longer counts as new.
    public var hasBeenOffered: Bool = false
    /// Nil until the course's first sync, which imports only open work.
    public var firstSyncedAt: Date?

    public init(canvasCourseID: Int, name: String) {
        self.canvasCourseID = canvasCourseID
        self.name = name
    }
}
