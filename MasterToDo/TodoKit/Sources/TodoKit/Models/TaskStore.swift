import Foundation
import SwiftData

@MainActor
public enum TaskStore {
    private static var _sharedContainer: ModelContainer?

    public static func makeConfiguration(localOnly: Bool = false) -> ModelConfiguration {
        ModelConfiguration(cloudKitDatabase: localOnly ? .none : .private("iCloud.com.mieracle.MasterToDo"))
    }

    public static func sharedContainer(localOnly: Bool? = nil) throws -> ModelContainer {
        if let _sharedContainer { return _sharedContainer }
        let isLocal = localOnly ?? UserDefaults.standard.bool(forKey: "localStore")
        let configuration = makeConfiguration(localOnly: isLocal)
        let container = try ModelContainer(for: Schema(TodoSchema.models), configurations: configuration)
        _ = try? TaskMigration.migrate(in: container.mainContext)
        _sharedContainer = container
        return container
    }

    public static func mainContext() throws -> ModelContext {
        try sharedContainer().mainContext
    }

    public static func resetSharedContainer() {
        _sharedContainer = nil
    }

    public static func setSharedContainer(_ container: ModelContainer?) {
        _sharedContainer = container
    }
}
