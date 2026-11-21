import Foundation
import SwiftData
@testable import TodoKit
import Testing

@MainActor
struct TaskIntentsTests {
    @Test func addTaskCreatesNewTask() throws {
        let container = try TestContainer.make()
        let context = container.mainContext

        let due = Date(timeIntervalSince1970: 1700000000)
        let result = try TaskIntents.addTask(
            title: "Submit report",
            source: "articulate",
            externalID: "task:100:10",
            dueAt: due,
            hasDueTime: true,
            notes: "Voice recording note",
            link: "obsidian://open?vault=Vault&file=Note",
            in: context
        )

        #expect(result.status == "created")
        #expect(result.created)
        #expect(!result.existing)
        #expect(!result.skipped)
        #expect(result.id != nil)
        #expect(result.state == "open")

        let tasks = try context.fetch(FetchDescriptor<TaskItem>())
        #expect(tasks.count == 1)
        let task = try #require(tasks.first)
        #expect(task.title == "Submit report")
        #expect(task.source == .articulate)
        #expect(task.externalID == "task:100:10")
        #expect(task.notes == "Voice recording note")
        #expect(task.link == "obsidian://open?vault=Vault&file=Note")
        #expect(task.dueAt == due)
        #expect(task.hasDueTime)

        let json = result.toJSON()
        #expect(json.contains("\"status\":\"created\""))
        #expect(json.contains("\"created\":true"))
        #expect(json.contains("\"id\":\"\(task.id.uuidString)\""))
    }

    @Test func addTaskIsIdempotent() throws {
        let container = try TestContainer.make()
        let context = container.mainContext

        let first = try TaskIntents.addTask(
            title: "Action item",
            source: "articulate",
            externalID: "task:1:2",
            notes: "First notes",
            in: context
        )
        #expect(first.status == "created")

        let second = try TaskIntents.addTask(
            title: "Modified title",
            source: "articulate",
            externalID: "task:1:2",
            notes: "Second notes",
            in: context
        )

        #expect(second.status == "existing")
        #expect(!second.created)
        #expect(second.existing)
        #expect(!second.skipped)
        #expect(second.id == first.id)
        #expect(second.state == "open")

        let tasks = try context.fetch(FetchDescriptor<TaskItem>())
        #expect(tasks.count == 1)
        #expect(tasks.first?.title == "Action item")
        #expect(tasks.first?.notes == "First notes")
    }

    @Test func addTaskSkipsTombstonedItem() throws {
        let container = try TestContainer.make()
        let context = container.mainContext

        let tombstone = RemovedExternalItem(source: .articulate, externalID: "task:200:20")
        context.insert(tombstone)
        try context.save()

        let result = try TaskIntents.addTask(
            title: "Deleted chore",
            source: "articulate",
            externalID: "task:200:20",
            in: context
        )

        #expect(result.status == "skipped")
        #expect(result.skipped)
        #expect(!result.created)
        #expect(!result.existing)
        #expect(result.id == nil)
        #expect(result.state == nil)

        #expect(try context.fetchCount(FetchDescriptor<TaskItem>()) == 0)

        let json = result.toJSON()
        #expect(json.contains("\"status\":\"skipped\""))
        #expect(json.contains("\"skipped\":true"))
    }

    @Test func addTaskSupportsNilExternalID() throws {
        let container = try TestContainer.make()
        let context = container.mainContext

        let first = try TaskIntents.addTask(title: "Task 1", source: "user", in: context)
        let second = try TaskIntents.addTask(title: "Task 2", source: "user", in: context)

        #expect(first.status == "created")
        #expect(second.status == "created")
        #expect(first.id != second.id)
        #expect(try context.fetchCount(FetchDescriptor<TaskItem>()) == 2)
    }

    @Test func addTaskParsesJSONPayload() throws {
        let container = try TestContainer.make()
        let context = container.mainContext

        let payload = """
        {
            "title": "Payload title",
            "source": "articulate",
            "external_id": "task:50:50",
            "due_at": "2026-11-25T14:30:00Z",
            "has_due_time": true,
            "notes": "Extracted from speech",
            "link": "obsidian://open?file=MyNote"
        }
        """

        let result = try TaskIntents.addTask(
            title: "",
            source: "",
            payload: payload,
            in: context
        )

        #expect(result.status == "created")
        let task = try #require(try context.fetch(FetchDescriptor<TaskItem>()).first)
        #expect(task.title == "Payload title")
        #expect(task.source == .articulate)
        #expect(task.externalID == "task:50:50")
        #expect(task.notes == "Extracted from speech")
        #expect(task.link == "obsidian://open?file=MyNote")
        #expect(task.hasDueTime)
    }

    @Test func addTaskParsesJSONInTitle() throws {
        let container = try TestContainer.make()
        let context = container.mainContext

        let jsonTitle = """
        {"title": "JSON title", "source": "articulate", "externalID": "task:99:99"}
        """

        let result = try TaskIntents.addTask(
            title: jsonTitle,
            source: "",
            in: context
        )

        #expect(result.status == "created")
        let task = try #require(try context.fetch(FetchDescriptor<TaskItem>()).first)
        #expect(task.title == "JSON title")
        #expect(task.source == .articulate)
        #expect(task.externalID == "task:99:99")
    }

    @Test func getTaskStateOpenAndDone() throws {
        let container = try TestContainer.make()
        let context = container.mainContext

        let task = TaskItem(title: "Do work", source: .articulate, externalID: "task:10:10")
        context.insert(task)
        try context.save()

        let openResult = try TaskIntents.getTaskState(source: "articulate", externalID: "task:10:10", in: context)
        #expect(openResult.state == "open")
        #expect(openResult.id == task.id.uuidString)

        task.state = .done
        try context.save()

        let doneResult = try TaskIntents.getTaskState(source: "articulate", externalID: "task:10:10", in: context)
        #expect(doneResult.state == "done")
        #expect(doneResult.id == task.id.uuidString)
    }

    @Test func getTaskStateRemoved() throws {
        let container = try TestContainer.make()
        let context = container.mainContext

        let tombstone = RemovedExternalItem(source: .articulate, externalID: "task:30:30")
        context.insert(tombstone)
        try context.save()

        let result = try TaskIntents.getTaskState(source: "articulate", externalID: "task:30:30", in: context)
        #expect(result.state == "removed")
        #expect(result.id == nil)
    }

    @Test func getTaskStateUnknown() throws {
        let container = try TestContainer.make()
        let context = container.mainContext

        let result = try TaskIntents.getTaskState(source: "articulate", externalID: "nonexistent", in: context)
        #expect(result.state == "unknown")
        #expect(result.id == nil)
    }

    @Test func getTaskStateParsesJSONPayload() throws {
        let container = try TestContainer.make()
        let context = container.mainContext

        let task = TaskItem(title: "Read notes", source: .articulate, externalID: "task:40:40")
        context.insert(task)
        try context.save()

        let payload = """
        {"source": "articulate", "external_id": "task:40:40"}
        """
        let result = try TaskIntents.getTaskState(source: "", externalID: "", payload: payload, in: context)
        #expect(result.state == "open")
        #expect(result.source == "articulate")
        #expect(result.externalID == "task:40:40")
    }

    @Test func addTaskRejectsEmptyTitle() throws {
        let container = try TestContainer.make()
        let context = container.mainContext

        #expect(throws: TaskIntentError.emptyTitle) {
            _ = try TaskIntents.addTask(title: "", source: "user", in: context)
        }

        #expect(throws: TaskIntentError.emptyTitle) {
            _ = try TaskIntents.addTask(title: "   \n\t  ", source: "articulate", in: context)
        }

        #expect(throws: TaskIntentError.emptyTitle) {
            _ = try TaskIntents.addTask(title: "", source: "articulate", payload: "{\"notes\":\"no title\"}", in: context)
        }

        let tasks = try context.fetch(FetchDescriptor<TaskItem>())
        #expect(tasks.isEmpty)
    }

    @Test func intentPerformReturnsJSON() async throws {
        let container = try TestContainer.make()
        TaskStore.setSharedContainer(container)
        defer { TaskStore.resetSharedContainer() }

        let addIntent = AddTaskIntent(
            title: "Shortcuts task",
            source: "articulate",
            externalID: "task:77:88",
            notes: "Via Shortcuts",
            link: "obsidian://open?file=Shortcuts"
        )
        let addResult = try await addIntent.perform()
        let addJSON = try #require(addResult.value)
        #expect(addJSON.contains("\"status\":\"created\""))
        #expect(addJSON.contains("\"created\":true"))
        #expect(addJSON.contains("\"state\":\"open\""))

        // Run again to verify idempotency through the intent
        let addAgainResult = try await addIntent.perform()
        let addAgainJSON = try #require(addAgainResult.value)
        #expect(addAgainJSON.contains("\"status\":\"existing\""))
        #expect(addAgainJSON.contains("\"existing\":true"))

        let stateIntent = GetTaskStateIntent(source: "articulate", externalID: "task:77:88")
        let stateResult = try await stateIntent.perform()
        let stateJSON = try #require(stateResult.value)
        #expect(stateJSON.contains("\"state\":\"open\""))
        #expect(stateJSON.contains("\"source\":\"articulate\""))
        #expect(stateJSON.contains("\"externalID\":\"task:77:88\""))
    }
}
