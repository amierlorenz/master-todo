import SwiftData
import SwiftUI
import TodoKit

@main
struct MasterToDoApp: App {
    let container: ModelContainer
    @State private var sync: SyncService

    init() {
        do {
            container = try TaskStore.sharedContainer()
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
