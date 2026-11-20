import Foundation
import SwiftData
@testable import TodoKit
import Testing

@MainActor
struct TaskMigrationTests {
    @Test func migratesExistingCanvasTasks() throws {
        let container = try TestContainer.make()
        let context = container.mainContext

        let legacyTask = TaskItem(title: "CS Assignment")
        legacyTask.canvasAssignmentID = 1234
        legacyTask.canvasCourseID = 7
        legacyTask.htmlURL = "https://canvas.instructure.com/courses/7/assignments/1234"
        legacyTask.sourceRaw = TaskSource.user.rawValue
        legacyTask.externalID = nil
        context.insert(legacyTask)

        let ownTask = TaskItem(title: "Own task")
        context.insert(ownTask)

        let migratedCount = try TaskMigration.migrate(in: context)
        #expect(migratedCount == 1)

        #expect(legacyTask.source == .canvas)
        #expect(legacyTask.externalID == "1234")
        #expect(legacyTask.link == "https://canvas.instructure.com/courses/7/assignments/1234")

        #expect(ownTask.source == .user)
        #expect(ownTask.externalID == nil)
    }

    @Test func migratesLegacyCanvasTombstones() throws {
        let container = try TestContainer.make()
        let context = container.mainContext

        let legacyTombstone = RemovedCanvasItem(canvasAssignmentID: 5678)
        context.insert(legacyTombstone)

        let migratedCount = try TaskMigration.migrate(in: context)
        #expect(migratedCount == 1)

        let externalTombstones = try context.fetch(FetchDescriptor<RemovedExternalItem>())
        #expect(externalTombstones.count == 1)
        #expect(externalTombstones.first?.source == .canvas)
        #expect(externalTombstones.first?.externalID == "5678")
    }

    @Test func migrationIsIdempotent() throws {
        let container = try TestContainer.make()
        let context = container.mainContext

        let legacyTask = TaskItem(title: "CS Assignment")
        legacyTask.canvasAssignmentID = 1234
        legacyTask.htmlURL = "https://canvas.instructure.com/courses/7/assignments/1234"
        context.insert(legacyTask)

        let legacyTombstone = RemovedCanvasItem(canvasAssignmentID: 5678)
        context.insert(legacyTombstone)

        let firstRun = try TaskMigration.migrate(in: context)
        #expect(firstRun == 2)

        let secondRun = try TaskMigration.migrate(in: context)
        #expect(secondRun == 0)

        #expect(try context.fetchCount(FetchDescriptor<RemovedExternalItem>()) == 1)
    }
}
