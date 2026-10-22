import Foundation
import SwiftData
@testable import TodoKit

enum TestContainer {
    @MainActor static func make() throws -> ModelContainer {
        try ModelContainer(for: Schema(TodoSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
}

extension Calendar {
    static let newYork: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    func at(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}

extension TaskItem {
    static func canvas(_ title: String, assignmentID: Int, courseID: Int = 7, dueAt: Date? = nil) -> TaskItem {
        let task = TaskItem(title: title, dueAt: dueAt, hasDueTime: dueAt != nil)
        task.canvasAssignmentID = assignmentID
        task.canvasCourseID = courseID
        return task
    }
}

func assignment(_ json: String) -> CanvasAssignment {
    try! CanvasClient.decoder.decode(CanvasAssignment.self, from: Data(json.utf8))
}

/// Builds Canvas assignment JSON with only the fields a test cares about.
func assignmentJSON(id: Int, name: String = "A", due: String? = nil, lock: String? = nil, state: String = "unsubmitted", excused: Bool = false, types: [String] = ["online_upload"]) -> String {
    let typeList = types.map { "\"\($0)\"" }.joined(separator: ",")
    let due = due.map { "\"\($0)\"" } ?? "null"
    let lock = lock.map { "\"\($0)\"" } ?? "null"
    return #"{"id":\#(id),"name":"\#(name)","due_at":\#(due),"lock_at":\#(lock),"submission_types":[\#(typeList)],"submission":{"workflow_state":"\#(state)","excused":\#(excused)}}"#
}

func makeAssignment(id: Int, name: String = "A", due: String? = nil, lock: String? = nil, state: String = "unsubmitted", excused: Bool = false) -> CanvasAssignment {
    assignment(assignmentJSON(id: id, name: name, due: due, lock: lock, state: state, excused: excused))
}
