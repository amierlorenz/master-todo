import Foundation
import SwiftData

/// An external item the user removed, so sync/intake never brings it back.
@Model
public final class RemovedExternalItem {
    /// Breaks ties when merging duplicates, so every device keeps the same record.
    public var id: UUID = UUID()
    public var sourceRaw: String = TaskSource.canvas.rawValue
    public var externalID: String = ""
    public var removedAt: Date = Date.now

    public init(source: TaskSource, externalID: String, removedAt: Date = Date.now) {
        self.sourceRaw = source.rawValue
        self.externalID = externalID
        self.removedAt = removedAt
    }

    public var source: TaskSource {
        get { TaskSource(rawValue: sourceRaw) ?? .canvas }
        set { sourceRaw = newValue.rawValue }
    }
}
