import SwiftData
import SwiftUI
import TodoKit

@main
struct MasterToDoApp: App {
    let container: ModelContainer
    @State private var sync: SyncService

    init() {
        let localOnly = UserDefaults.standard.bool(forKey: "localStore")
        let configuration = ModelConfiguration(cloudKitDatabase: localOnly ? .none : .private("iCloud.com.mieracle.MasterToDo"))
        do {
            container = try ModelContainer(for: Schema(TodoSchema.models), configurations: configuration)
        } catch {
            fatalError("Could not open the task store: \(error)")
        }
        _sync = State(initialValue: SyncService(context: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
        .environment(sync)
        #if os(iOS)
        .backgroundTask(.appRefresh(SyncService.backgroundTaskID)) {
            await sync.backgroundRefresh()
        }
        #endif
    }
}
