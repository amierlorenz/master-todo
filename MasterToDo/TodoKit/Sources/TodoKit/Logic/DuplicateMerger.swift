import Foundation
import SwiftData

/// Folds records that share a Canvas id into one.
///
/// CloudKit can't enforce uniqueness, so two devices syncing Canvas before
/// they see each other's data both insert the same assignment. Every device
/// must pick the same keeper, or each deletes the other's copy and both are
/// lost once CloudKit syncs the deletions; keepers are chosen by a total order
/// that ends in the record's UUID.
@MainActor
public enum DuplicateMerger {
    /// Merges every duplicate group and saves. Returns the number of records removed.
    @discardableResult
    public static func mergeAll(in context: ModelContext) throws -> Int {
        var removed = 0

        let canvasTombstones = Dictionary(grouping: try context.fetch(FetchDescriptor<RemovedCanvasItem>()), by: \.canvasAssignmentID)
        for group in canvasTombstones.values where group.count > 1 {
            let keeper = group.min { $0.id.uuidString < $1.id.uuidString }!
            for duplicate in group where duplicate !== keeper {
                context.delete(duplicate)
                removed += 1
            }
        }

        let externalTombstones = Dictionary(grouping: try context.fetch(FetchDescriptor<RemovedExternalItem>()), by: { "\($0.sourceRaw):\($0.externalID)" })
        for group in externalTombstones.values where group.count > 1 {
            let keeper = group.min { $0.id.uuidString < $1.id.uuidString }!
            for duplicate in group where duplicate !== keeper {
                context.delete(duplicate)
                removed += 1
            }
        }

        let allTasks = try context.fetch(FetchDescriptor<TaskItem>())
        let externalTasks = allTasks.filter { $0.externalID != nil || $0.canvasAssignmentID != nil }
        let tasks = Dictionary(grouping: externalTasks, by: { task -> String in
            let extID = task.externalID ?? task.canvasAssignmentID.map(String.init) ?? ""
            return "\(task.sourceRaw):\(extID)"
        })
        for (groupKey, group) in tasks {
            let isTombstoned: Bool = {
                if externalTombstones[groupKey] != nil { return true }
                if let first = group.first, first.isCanvas {
                    if let cid = first.canvasAssignmentID, canvasTombstones[cid] != nil { return true }
                    if let extID = first.externalID, let cid = Int(extID), canvasTombstones[cid] != nil { return true }
                }
                return false
            }()

            if isTombstoned {
                group.forEach(context.delete)
                removed += group.count
                continue
            }
            guard group.count > 1 else { continue }
            let keeper = group.min { a, b in
                if a.state.rank != b.state.rank { return a.state.rank > b.state.rank }
                if a.createdAt != b.createdAt { return a.createdAt < b.createdAt }
                return a.id.uuidString < b.id.uuidString
            }!
            let newest = group.max { ($0.lastSyncedAt ?? .distantPast) < ($1.lastSyncedAt ?? .distantPast) }!
            if newest !== keeper { copyCanvasFields(from: newest, to: keeper) }
            if keeper.notes == nil { keeper.notes = group.compactMap(\.notes).first }
            if keeper.link == nil { keeper.link = group.compactMap(\.link).first }
            if keeper.externalID == nil { keeper.externalID = group.compactMap(\.externalID).first }
            keeper.submittedDismissed = group.contains(where: \.submittedDismissed)
            for duplicate in group where duplicate !== keeper {
                context.delete(duplicate)
                removed += 1
            }
        }

        let courses = Dictionary(grouping: try context.fetch(FetchDescriptor<TrackedCourse>()), by: \.canvasCourseID)
        for group in courses.values where group.count > 1 {
            let keeper = group.min { $0.id.uuidString < $1.id.uuidString }!
            keeper.isTracked = group.contains(where: \.isTracked)
            keeper.hasBeenOffered = group.contains(where: \.hasBeenOffered)
            keeper.firstSyncedAt = group.compactMap(\.firstSyncedAt).min()
            for duplicate in group where duplicate !== keeper {
                context.delete(duplicate)
                removed += 1
            }
        }

        if removed > 0 { try context.save() }
        return removed
    }

    private static func copyCanvasFields(from source: TaskItem, to keeper: TaskItem) {
        keeper.title = source.title
        keeper.dueAt = source.dueAt
        keeper.hasDueTime = source.hasDueTime
        keeper.courseName = source.courseName
        keeper.htmlURL = source.htmlURL
        keeper.lockAt = source.lockAt
        keeper.submissionTypesRaw = source.submissionTypesRaw
        keeper.isSubmittedOnCanvas = source.isSubmittedOnCanvas
        keeper.isGoneFromCanvas = source.isGoneFromCanvas
        keeper.lastSyncedAt = source.lastSyncedAt
        if keeper.notes == nil { keeper.notes = source.notes }
        if keeper.link == nil { keeper.link = source.link }
        if keeper.externalID == nil { keeper.externalID = source.externalID }
    }
}
