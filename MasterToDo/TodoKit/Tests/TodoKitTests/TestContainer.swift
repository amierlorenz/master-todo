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
