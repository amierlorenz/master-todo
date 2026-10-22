import SwiftData
import SwiftUI
import TodoKit

/// Hosts the list and keeps sync, duplicates, and notifications current.
struct RootView: View {
    @Environment(SyncService.self) private var sync
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [TaskItem]
    @Query private var courses: [TrackedCourse]
    @AppStorage(NotificationService.summaryHourKey) private var summaryHour = 8
    @AppStorage(NotificationService.summaryMinuteKey) private var summaryMinute = 0
    @State private var showsCoursePicker = false
    @State private var dismissedCoursePicker = false

    /// Changes whenever anything that affects notifications changes, including CloudKit imports.
    private var notificationInputs: [String] {
        tasks.map { "\($0.id)|\($0.title)|\($0.stateRaw)|\($0.dueAt?.timeIntervalSince1970 ?? 0)|\($0.hasDueTime)|\($0.canvasCourseID ?? 0)" }
            + courses.map { "\($0.canvasCourseID)|\($0.isTracked)" }
            + ["\(summaryHour):\(summaryMinute)"]
    }

    private var needsCoursePick: Bool {
        sync.hasCanvasAccount && !courses.contains(where: \.isTracked) && !dismissedCoursePicker
    }

    var body: some View {
        TaskListView()
            .task {
                await NotificationService.requestAuthorization()
            }
            .onChange(of: scenePhase, initial: true) { _, phase in
                if phase == .active {
                    Task { await sync.syncIfStale() }
                }
                #if os(iOS)
                if phase == .background {
                    SyncService.scheduleBackgroundRefresh()
                }
                #endif
            }
            .task(id: notificationInputs) {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                _ = try? DuplicateMerger.mergeAll(in: modelContext)
                await NotificationService.replan(context: modelContext)
            }
            .onChange(of: needsCoursePick, initial: true) { _, needed in
                if needed { showsCoursePicker = true }
            }
            .sheet(isPresented: $showsCoursePicker, onDismiss: { dismissedCoursePicker = true }) {
                CoursePickerView()
            }
    }
}
