import AppIntents
import Foundation
import SwiftData

public struct AddTaskIntent: AppIntent {
    public static let title: LocalizedStringResource = "Add Task"
    public static let description = IntentDescription("Adds a task to MasterToDo.")
    public static let openAppWhenRun: Bool = false

    @Parameter(title: "Title")
    public var title: String

    @Parameter(title: "Source", default: "user")
    public var source: String

    @Parameter(title: "External ID")
    public var externalID: String?

    @Parameter(title: "Due Date")
    public var dueAt: Date?

    @Parameter(title: "Has Due Time")
    public var hasDueTime: Bool?

    @Parameter(title: "Notes")
    public var notes: String?

    @Parameter(title: "Link")
    public var link: String?

    @Parameter(title: "JSON Payload")
    public var payload: String?

    public init() {
        self.title = ""
        self.source = "user"
    }

    public init(
        title: String,
        source: String = "user",
        externalID: String? = nil,
        dueAt: Date? = nil,
        hasDueTime: Bool? = nil,
        notes: String? = nil,
        link: String? = nil,
        payload: String? = nil
    ) {
        self.title = title
        self.source = source
        self.externalID = externalID
        self.dueAt = dueAt
        self.hasDueTime = hasDueTime
        self.notes = notes
        self.link = link
        self.payload = payload
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$title) from \(\.$source)") {
            \.$externalID
            \.$dueAt
            \.$hasDueTime
            \.$notes
            \.$link
            \.$payload
        }
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let context = try TaskStore.mainContext()
        let result = try TaskIntents.addTask(
            title: title,
            source: source,
            externalID: externalID,
            dueAt: dueAt,
            hasDueTime: hasDueTime,
            notes: notes,
            link: link,
            payload: payload,
            in: context
        )

        let json = result.toJSON()
        let dialogMessage: LocalizedStringResource = switch result.status {
        case "created": "Added task: \(title)"
        case "existing": "Task already exists."
        case "skipped": "Task was previously removed."
        default: "Task processed."
        }
        return .result(value: json, dialog: IntentDialog(dialogMessage))
    }
}
