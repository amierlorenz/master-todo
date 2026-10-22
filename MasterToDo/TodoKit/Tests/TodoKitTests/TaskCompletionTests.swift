import Foundation
@testable import TodoKit
import Testing

@MainActor
struct TaskCompletionTests {
    @MainActor final class Fetcher {
        var calls = 0
        let result: Result<CanvasAssignment, any Error>

        init(_ result: Result<CanvasAssignment, any Error>) { self.result = result }

        func fetch(courseID: Int, assignmentID: Int) async throws -> CanvasAssignment {
            calls += 1
            return try result.get()
        }
    }

    static let submitted = assignment(#"{"id":1,"name":"A","submission_types":["online_upload"],"submission":{"workflow_state":"submitted"}}"#)
    static let unsubmitted = assignment(#"{"id":1,"name":"A","submission_types":["online_upload"],"submission":{"workflow_state":"unsubmitted"}}"#)

    func onlineTask() -> TaskItem {
        let task = TaskItem.canvas("A", assignmentID: 1)
        task.submissionTypes = ["online_upload"]
        return task
    }

    @Test func ownTaskDismissesWithoutFetch() async {
        let fetcher = Fetcher(.success(Self.unsubmitted))
        let task = TaskItem(title: "Mine")
        #expect(await TaskCompletion.complete(task, fetch: fetcher.fetch) == .done)
        #expect(task.state == .done)
        #expect(fetcher.calls == 0)
    }

    @Test func offlineTypeDismissesWithoutFetch() async {
        let fetcher = Fetcher(.success(Self.unsubmitted))
        let task = TaskItem.canvas("A", assignmentID: 1)
        task.submissionTypesRaw = "on_paper"
        #expect(await TaskCompletion.complete(task, fetch: fetcher.fetch) == .done)
        #expect(fetcher.calls == 0)
    }

    @Test func onlineSubmittedDismisses() async {
        let fetcher = Fetcher(.success(Self.submitted))
        let task = onlineTask()
        #expect(await TaskCompletion.complete(task, fetch: fetcher.fetch) == .done)
        #expect(task.isSubmittedOnCanvas)
        #expect(fetcher.calls == 1)
    }

    @Test func onlineNotSubmittedStaysPending() async {
        let task = onlineTask()
        #expect(await TaskCompletion.complete(task, fetch: Fetcher(.success(Self.unsubmitted)).fetch) == .pendingVerification)
        #expect(task.state == .pendingVerification)
    }

    @Test func fetchErrorStaysPending() async {
        let task = onlineTask()
        #expect(await TaskCompletion.complete(task, fetch: Fetcher(.failure(CanvasClient.ClientError.unauthorized)).fetch) == .pendingVerification)
    }

    @Test func uncheckReturnsToOpen() {
        let task = onlineTask()
        task.state = .pendingVerification
        TaskCompletion.uncheck(task)
        #expect(task.state == .open)
    }
}
