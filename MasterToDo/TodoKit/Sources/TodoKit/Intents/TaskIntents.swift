import Foundation
import SwiftData

@MainActor
public enum TaskIntents {
    public struct AddTaskResult: Codable, Equatable, Sendable {
        public let id: String?
        public let state: String?
        public let status: String
        public let created: Bool
        public let existing: Bool
        public let skipped: Bool

        public init(id: String?, state: String?, status: String) {
            self.id = id
            self.state = state
            self.status = status
            self.created = (status == "created")
            self.existing = (status == "existing")
            self.skipped = (status == "skipped")
        }

        public func toJSON() -> String {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            guard let data = try? encoder.encode(self), let str = String(data: data, encoding: .utf8) else {
                return "{}"
            }
            return str
        }
    }

    public struct TaskStateResult: Codable, Equatable, Sendable {
        public let source: String
        public let externalID: String
        public let state: String
        public let id: String?

        public init(source: String, externalID: String, state: String, id: String? = nil) {
            self.source = source
            self.externalID = externalID
            self.state = state
            self.id = id
        }

        public func toJSON() -> String {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            guard let data = try? encoder.encode(self), let str = String(data: data, encoding: .utf8) else {
                return "{}"
            }
            return str
        }
    }

    public static func addTask(
        title: String,
        source: String,
        externalID: String? = nil,
        dueAt: Date? = nil,
        hasDueTime: Bool? = nil,
        notes: String? = nil,
        link: String? = nil,
        payload: String? = nil,
        in context: ModelContext
    ) throws -> AddTaskResult {
        var resolvedTitle = title
        var resolvedSource = source
        var resolvedExternalID = externalID
        var resolvedDueAt = dueAt
        var resolvedHasDueTime = hasDueTime
        var resolvedNotes = notes
        var resolvedLink = link

        if let payloadString = payload?.trimmingCharacters(in: .whitespacesAndNewlines), !payloadString.isEmpty {
            parsePayload(payloadString, title: &resolvedTitle, source: &resolvedSource, externalID: &resolvedExternalID, dueAt: &resolvedDueAt, hasDueTime: &resolvedHasDueTime, notes: &resolvedNotes, link: &resolvedLink)
        } else if title.trimmingCharacters(in: .whitespacesAndNewlines).starts(with: "{") {
            parsePayload(title, title: &resolvedTitle, source: &resolvedSource, externalID: &resolvedExternalID, dueAt: &resolvedDueAt, hasDueTime: &resolvedHasDueTime, notes: &resolvedNotes, link: &resolvedLink)
        }

        let cleanTitle = resolvedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSource = resolvedSource.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let taskSource = TaskSource(rawValue: cleanSource) ?? .user
        let cleanExtID = resolvedExternalID?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty

        // 1. Idempotency check: if task with same source + externalID exists, return it and create nothing
        if let cleanExtID {
            let tasks = try context.fetch(FetchDescriptor<TaskItem>())
            if let existing = tasks.first(where: {
                $0.source == taskSource && ($0.externalID == cleanExtID || ($0.isCanvas && $0.canvasAssignmentID.map(String.init) == cleanExtID))
            }) {
                return AddTaskResult(
                    id: existing.id.uuidString,
                    state: existing.state.rawValue,
                    status: "existing"
                )
            }

            // 2. Tombstone check: if a RemovedExternalItem matches, return "skipped"
            let externalTombstones = try context.fetch(FetchDescriptor<RemovedExternalItem>())
            let legacyTombstones = try context.fetch(FetchDescriptor<RemovedCanvasItem>())
            let isTombstoned = externalTombstones.contains(where: { $0.source == taskSource && $0.externalID == cleanExtID })
                || (taskSource == .canvas && legacyTombstones.contains(where: { String($0.canvasAssignmentID) == cleanExtID }))

            if isTombstoned {
                return AddTaskResult(
                    id: nil,
                    state: nil,
                    status: "skipped"
                )
            }
        }

        // 3. Otherwise create the task and return its state
        let effectiveHasDueTime = resolvedHasDueTime ?? (resolvedDueAt != nil)
        let newTask = TaskItem(
            title: cleanTitle,
            dueAt: resolvedDueAt,
            hasDueTime: effectiveHasDueTime,
            source: taskSource,
            externalID: cleanExtID,
            notes: resolvedNotes,
            link: resolvedLink
        )
        if taskSource == .canvas, let cleanExtID, let cid = Int(cleanExtID) {
            newTask.canvasAssignmentID = cid
        }
        context.insert(newTask)
        try context.save()

        return AddTaskResult(
            id: newTask.id.uuidString,
            state: newTask.state.rawValue,
            status: "created"
        )
    }

    public static func getTaskState(
        source: String,
        externalID: String,
        payload: String? = nil,
        in context: ModelContext
    ) throws -> TaskStateResult {
        var resolvedSource = source
        var resolvedExternalID = externalID

        if let payloadString = payload?.trimmingCharacters(in: .whitespacesAndNewlines), !payloadString.isEmpty {
            parseStatePayload(payloadString, source: &resolvedSource, externalID: &resolvedExternalID)
        } else if source.trimmingCharacters(in: .whitespacesAndNewlines).starts(with: "{") {
            parseStatePayload(source, source: &resolvedSource, externalID: &resolvedExternalID)
        }

        let cleanSource = resolvedSource.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanExtID = resolvedExternalID.trimmingCharacters(in: .whitespacesAndNewlines)
        let taskSource = TaskSource(rawValue: cleanSource) ?? .user

        // 1. Check existing tasks
        let tasks = try context.fetch(FetchDescriptor<TaskItem>())
        if let task = tasks.first(where: {
            $0.source == taskSource && ($0.externalID == cleanExtID || ($0.isCanvas && $0.canvasAssignmentID.map(String.init) == cleanExtID))
        }) {
            let stateString = (task.state == .done) ? "done" : "open"
            return TaskStateResult(
                source: cleanSource,
                externalID: cleanExtID,
                state: stateString,
                id: task.id.uuidString
            )
        }

        // 2. Check tombstones
        let externalTombstones = try context.fetch(FetchDescriptor<RemovedExternalItem>())
        let legacyTombstones = try context.fetch(FetchDescriptor<RemovedCanvasItem>())
        let isTombstoned = externalTombstones.contains(where: { $0.source == taskSource && $0.externalID == cleanExtID })
            || (taskSource == .canvas && legacyTombstones.contains(where: { String($0.canvasAssignmentID) == cleanExtID }))

        if isTombstoned {
            return TaskStateResult(
                source: cleanSource,
                externalID: cleanExtID,
                state: "removed",
                id: nil
            )
        }

        // 3. Unknown
        return TaskStateResult(
            source: cleanSource,
            externalID: cleanExtID,
            state: "unknown",
            id: nil
        )
    }

    private static func parsePayload(
        _ jsonString: String,
        title: inout String,
        source: inout String,
        externalID: inout String?,
        dueAt: inout Date?,
        hasDueTime: inout Bool?,
        notes: inout String?,
        link: inout String?
    ) {
        guard let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        if let t = dict["title"] as? String { title = t }
        if let s = dict["source"] as? String { source = s }
        if let ext = (dict["externalID"] ?? dict["external_id"]) as? String { externalID = ext }
        if let n = dict["notes"] as? String { notes = n }
        if let l = dict["link"] as? String { link = l }
        if let h = (dict["hasDueTime"] ?? dict["has_due_time"]) as? Bool { hasDueTime = h }

        if let due = dict["dueAt"] ?? dict["due_at"] {
            if let dateStr = due as? String {
                dueAt = parseDate(dateStr)
            } else if let num = due as? Double {
                dueAt = Date(timeIntervalSince1970: num)
            }
        }
    }

    private static func parseStatePayload(
        _ jsonString: String,
        source: inout String,
        externalID: inout String
    ) {
        guard let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        if let s = dict["source"] as? String { source = s }
        if let ext = (dict["externalID"] ?? dict["external_id"]) as? String { externalID = ext }
    }

    public static func parseDate(_ string: String) -> Date? {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: string) { return date }

        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: string) { return date }

        let customFormatters = [
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd"
        ].map { format -> DateFormatter in
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = TimeZone(secondsFromGMT: 0)
            df.dateFormat = format
            return df
        }

        for formatter in customFormatters {
            if let date = formatter.date(from: string) { return date }
        }
        return nil
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
