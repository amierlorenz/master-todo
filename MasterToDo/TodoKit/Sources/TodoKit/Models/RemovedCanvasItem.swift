import Foundation
import SwiftData

/// A Canvas assignment the user removed, so sync never brings it back.
@Model
public final class RemovedCanvasItem {
    public var canvasAssignmentID: Int = 0
    public var removedAt: Date = Date.now

    public init(canvasAssignmentID: Int) {
        self.canvasAssignmentID = canvasAssignmentID
    }
}
