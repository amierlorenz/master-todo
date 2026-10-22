import SwiftData
import SwiftUI
import TodoKit

@main
struct MasterToDoApp: App {
    let container: ModelContainer

    init() {
        let localOnly = UserDefaults.standard.bool(forKey: "localStore")
        let configuration = ModelConfiguration(cloudKitDatabase: localOnly ? .none : .private("iCloud.com.mieracle.MasterToDo"))
        do {
            container = try ModelContainer(for: Schema(TodoSchema.models), configurations: configuration)
        } catch {
            fatalError("Could not open the task store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            TaskListView()
        }
        .modelContainer(container)
    }
}
