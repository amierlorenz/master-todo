import Foundation
import SwiftData

@MainActor
public enum TaskMigration {
    /// Migrates existing Canvas tasks and tombstones to generalized source and externalID fields.
    @discardableResult
    public static func migrate(in context: ModelContext) throws -> Int {
        var migrated = 0

        let tasks = try context.fetch(FetchDescriptor<TaskItem>())
        for task in tasks where task.canvasAssignmentID != nil {
            var changed = false
            if task.sourceRaw != TaskSource.canvas.rawValue {
                task.source = .canvas
                changed = true
            }
            if task.externalID == nil, let assignmentID = task.canvasAssignmentID {
                task.externalID = String(assignmentID)
                changed = true
            }
            if task.link == nil, let htmlURL = task.htmlURL {
                task.link = htmlURL
                changed = true
            }
            if changed {
                migrated += 1
            }
        }

        let legacyTombstones = try context.fetch(FetchDescriptor<RemovedCanvasItem>())
        if !legacyTombstones.isEmpty {
            let existingExternal = try context.fetch(FetchDescriptor<RemovedExternalItem>())
            let existingKeys = Set(existingExternal.map { "\($0.sourceRaw):\($0.externalID)" })

            for legacy in legacyTombstones {
                let key = "\(TaskSource.canvas.rawValue):\(legacy.canvasAssignmentID)"
                if !existingKeys.contains(key) {
                    let external = RemovedExternalItem(
                        source: .canvas,
                        externalID: String(legacy.canvasAssignmentID),
                        removedAt: legacy.removedAt
                    )
                    context.insert(external)
                    migrated += 1
                }
            }
        }

        if migrated > 0 {
            try context.save()
        }
        return migrated
    }
}
