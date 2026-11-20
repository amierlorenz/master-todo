import AppIntents
import TodoKit

public struct MasterToDoShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTaskIntent(),
            phrases: [
                "Add task in \(.applicationName)",
                "Add task to \(.applicationName)",
                "Create task in \(.applicationName)"
            ],
            shortTitle: "Add Task",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: GetTaskStateIntent(),
            phrases: [
                "Get task state in \(.applicationName)",
                "Check task state in \(.applicationName)"
            ],
            shortTitle: "Get Task State",
            systemImageName: "questionmark.circle"
        )
    }
}
