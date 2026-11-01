#if DEBUG
import SwiftData
import SwiftUI
import TodoKit

@MainActor
enum PreviewTasks {
    static let container: ModelContainer = {
        let container = try! ModelContainer(for: Schema(TodoSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        for task in make(now: .now) { container.mainContext.insert(task) }
        let course = TrackedCourse(canvasCourseID: 1, name: "Intro to Info Assurance")
        course.isTracked = true
        course.hasBeenOffered = true
        container.mainContext.insert(course)
        return container
    }()

    static var all: [TaskItem] {
        (try? container.mainContext.fetch(FetchDescriptor<TaskItem>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
    }

    private static func make(now: Date) -> [TaskItem] {
        let hour: TimeInterval = 3_600, day = 24 * hour
        var created = now.addingTimeInterval(-100)

        func task(_ title: String, due: TimeInterval?, canvas: Bool = true, configure: (TaskItem) -> Void = { _ in }) -> TaskItem {
            let task = TaskItem(title: title, dueAt: due.map { now + $0 }, hasDueTime: due != nil)
            if canvas {
                task.canvasAssignmentID = Int.random(in: 1...999_999)
                task.canvasCourseID = 1
                task.courseName = "Intro to Info Assurance - CSC-382-01-Fall 2026"
                task.htmlURL = "https://canvas.instructure.com"
            }
            created += 1
            task.createdAt = created
            configure(task)
            return task
        }

        return [
            task("Discussion 2 - Cybersecurity, Ethical Obligation, Legal Requirement, or Both?", due: -day) { $0.lockAt = now + 3 * day },
            task("Lab 2 - Pen Testing Introduction", due: -2 * day),
            task("Quiz 1 - Closed", due: -3 * day) { $0.lockAt = now - day },
            task("Submitted essay", due: 5 * hour) { $0.isSubmittedOnCanvas = true },
            task("Date moved", due: 3 * day) { $0.dueDateChanged = true },
            task("Checked off here only", due: day) { $0.state = .pendingVerification },
            task("Removed from Canvas", due: 4 * day) { $0.isGoneFromCanvas = true },
            task("Final project", due: 20 * day),
            task("Physics practice questions", due: 2 * day, canvas: false),
            task("Call the bank", due: nil, canvas: false),
            task("Lab 1", due: -5 * day) { $0.state = .done },
        ]
    }
}
#endif
