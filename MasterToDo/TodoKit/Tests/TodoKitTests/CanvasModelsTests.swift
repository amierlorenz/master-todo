import Foundation
@testable import TodoKit
import Testing

struct CanvasModelsTests {
    func decode(_ json: String) throws -> CanvasAssignment {
        try CanvasClient.decoder.decode(CanvasAssignment.self, from: Data(json.utf8))
    }

    @Test(arguments: [
        ("submitted", false, true), ("graded", false, true), ("pending_review", false, true),
        ("unsubmitted", true, true), ("unsubmitted", false, false),
    ])
    func excusedAndGradedCountAsSubmitted(state: String, excused: Bool, expected: Bool) throws {
        let a = try decode(#"{"id":1,"name":"A","submission":{"workflow_state":"\#(state)","excused":\#(excused)}}"#)
        #expect(a.isSubmitted == expected)
    }

    @Test(arguments: [
        (["none"], false), (["on_paper"], false), (["not_graded"], false), (["external_tool"], false),
        (["online_quiz"], true), (["discussion_topic"], true), (["on_paper", "online_url"], true),
    ])
    func onlineSubmissionTypes(types: [String], expected: Bool) throws {
        let list = types.map { "\"\($0)\"" }.joined(separator: ",")
        let a = try decode(#"{"id":1,"name":"A","submission_types":[\#(list)]}"#)
        #expect(a.hasOnlineSubmission == expected)
    }

    @Test func closedOnlyAfterLockAt() throws {
        let now = ISO8601DateFormatter().date(from: "2026-10-21T12:00:00Z")!
        #expect(try !decode(#"{"id":1,"name":"A"}"#).isClosed(now: now))
        #expect(try decode(#"{"id":1,"name":"A","lock_at":"2026-10-21T11:00:00Z"}"#).isClosed(now: now))
        #expect(try !decode(#"{"id":1,"name":"A","lock_at":"2026-10-21T13:00:00Z"}"#).isClosed(now: now))
    }
}
