import Foundation
@testable import TodoKit
import Testing

struct CanvasClientTests {
    let base = URL(string: "https://school.instructure.com")!

    @Test func followsPaginationAndSendsToken() async throws {
        let page2 = "https://school.instructure.com/api/v1/courses/7/assignments?page=2&per_page=100"
        let stub = StubURLProtocol.stub([
            "/api/v1/courses/7/assignments": .init(
                body: #"[{"id": 1, "name": "Midterm 1", "due_at": "2026-10-20T15:00:00Z"}]"#,
                headers: ["Link": "<\(page2)>; rel=\"next\", <https://school.instructure.com/x?page=1>; rel=\"first\""]
            ),
            "/api/v1/courses/7/assignments?page=2&per_page=100": .init(body: #"[{"id": 2, "name": "Lab 3", "due_at": null}]"#),
        ])
        let client = CanvasClient(baseURL: base, token: "fake-token-for-tests", session: stub.session)

        let assignments = try await client.assignments(courseID: 7)

        #expect(assignments.map(\.name) == ["Midterm 1", "Lab 3"])
        #expect(assignments[0].dueAt == ISO8601DateFormatter().date(from: "2026-10-20T15:00:00Z"))
        #expect(assignments[1].dueAt == nil)
        let requests = stub.requests
        #expect(requests.count == 2)
        #expect(requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == "Bearer fake-token-for-tests" })
        #expect(requests.first?.url?.query()?.contains("submission") == true)
    }

    @Test func decodesCourses() async throws {
        let stub = StubURLProtocol.stub([
            "/api/v1/courses": .init(body: #"[{"id": 7, "name": "Data Structures", "course_code": "CS 201"}]"#),
        ])
        let client = CanvasClient(baseURL: base, token: "t", session: stub.session)
        #expect(try await client.activeCourses() == [CanvasCourse(id: 7, name: "Data Structures", courseCode: "CS 201")])
    }

    @Test func unauthorizedIsDistinct() async throws {
        let stub = StubURLProtocol.stub(["/api/v1/courses": .init(status: 401, body: "{}")])
        await #expect(throws: CanvasClient.ClientError.unauthorized) {
            try await CanvasClient(baseURL: base, token: "bad", session: stub.session).activeCourses()
        }
    }

    @Test(arguments: [
        (#"<https://a.edu/p2>; rel="next""#, "https://a.edu/p2"),
        (#"<https://a.edu/p1>; rel="current", <https://a.edu/p3>; rel="last""#, nil),
        (nil, nil),
    ] as [(String?, String?)])
    func parsesLinkHeader(header: String?, expected: String?) {
        #expect(CanvasClient.nextPage(from: header)?.absoluteString == expected)
    }

    @Test func decodesNewAssignmentFields() async throws {
        let stub = StubURLProtocol.stub(["/api/v1/courses/7/assignments": .init(body: #"""
          [{"id":1,"name":"Essay","due_at":"2026-10-20T15:00:00Z","lock_at":"2026-10-22T05:00:00Z",
            "submission_types":["online_upload"],"submission":{"workflow_state":"unsubmitted","excused":false}}]
          """#)])
        let a = try await CanvasClient(baseURL: base, token: "t", session: stub.session).assignments(courseID: 7)[0]
        #expect(a.lockAt == ISO8601DateFormatter().date(from: "2026-10-22T05:00:00Z"))
        #expect(a.submissionTypes == ["online_upload"])
        #expect(a.hasOnlineSubmission)
        #expect(!a.isSubmitted)
    }

    @Test func fetchesSingleAssignmentWithSubmission() async throws {
        let stub = StubURLProtocol.stub(["/api/v1/courses/7/assignments/1": .init(body: #"{"id":1,"name":"Essay","submission":{"workflow_state":"submitted"}}"#)])
        let a = try await CanvasClient(baseURL: base, token: "t", session: stub.session).assignment(courseID: 7, id: 1)
        #expect(a.isSubmitted)
        #expect(a.submissionTypes == [])
        #expect(stub.requests.first?.url?.query()?.contains("submission") == true)
    }

    @Test func singleAssignmentUnauthorized() async throws {
        let stub = StubURLProtocol.stub(["/api/v1/courses/7/assignments/1": .init(status: 401, body: "{}")])
        await #expect(throws: CanvasClient.ClientError.unauthorized) {
            try await CanvasClient(baseURL: base, token: "bad", session: stub.session).assignment(courseID: 7, id: 1)
        }
    }

}
