import AppIntents
import Foundation
import SwiftData

public struct GetTaskStateIntent: AppIntent {
    public static let title: LocalizedStringResource = "Get Task State"
    public static let description = IntentDescription("Gets the current state of a task in MasterToDo.")
    public static let openAppWhenRun: Bool = false

    @Parameter(title: "Source", default: "")
    public var source: String

    @Parameter(title: "External ID", default: "")
    public var externalID: String

    @Parameter(title: "JSON Payload", inputConnectionBehavior: .connectToPreviousIntentResult)
    public var payload: String?

    public init() {
        self.source = ""
        self.externalID = ""
    }

    public init(source: String, externalID: String, payload: String? = nil) {
        self.source = source
        self.externalID = externalID
        self.payload = payload
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("Get state of \(\.$source) task \(\.$externalID)") {
            \.$payload
        }
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let context = try TaskStore.mainContext()
        let result = try TaskIntents.getTaskState(
            source: source,
            externalID: externalID,
            payload: payload,
            in: context
        )

        let json = result.toJSON()
        return .result(value: json)
    }
}
