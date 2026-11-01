import SwiftData
import SwiftUI
import TodoKit

struct TaskListView: View {
    @Environment(SyncService.self) private var sync
    @Query private var tasks: [TaskItem]
    @Query(filter: #Predicate<TrackedCourse> { $0.isTracked }) private var trackedCourses: [TrackedCourse]
    @Query(filter: #Predicate<TrackedCourse> { !$0.hasBeenOffered }) private var newCourses: [TrackedCourse]
    @State private var showsDone = false
    @State private var showsSettings = false
    @State private var editing: TaskItem?

    private var visibleTasks: [TaskItem] {
        let tracked = Set(trackedCourses.map(\.canvasCourseID))
        return tasks.filter { $0.isVisible(trackedCourseIDs: tracked) }
    }

    var body: some View {
        // Re-renders every minute so countdowns tick and tasks move between groups on time.
        TimelineView(.everyMinute) { context in
            content(now: context.date)
        }
    }

    private func content(now: Date) -> some View {
        let active = TaskOrdering.sorted(visibleTasks.filter { $0.state != .done }, now: now, calendar: .current)
        let done = visibleTasks.filter { $0.state == .done }.sorted { $0.title < $1.title }

        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let error = sync.lastError {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                    if !trackedCourses.isEmpty, !newCourses.isEmpty {
                        Button("\(newCourses.count) new Canvas \(newCourses.count == 1 ? "course" : "courses") — choose in Settings", systemImage: "sparkles") {
                            showsSettings = true
                        }
                        .buttonStyle(.glass)
                    }
                    if active.isEmpty {
                        ContentUnavailableView("All clear", systemImage: "checkmark.circle", description: Text("Nothing left to do."))
                    }
                    rows(active, now: now)
                    if !done.isEmpty {
                        Button(showsDone ? "Hide Done (\(done.count))" : "Show Done (\(done.count))") {
                            withAnimation { showsDone.toggle() }
                        }
                        .buttonStyle(.glass)
                        if showsDone { rows(done, now: now) }
                    }
                }
                .padding(.horizontal)
                .animation(.default, value: tasks.map(\.stateRaw))
                .animation(.default, value: tasks.count)
            }
            .background(.background.secondary)
            .navigationTitle("To Do")
            .refreshable { await sync.syncNow() }
            .toolbar {
                ToolbarItemGroup {
                    if sync.isSyncing {
                        ProgressView()
                    } else {
                        Button("Refresh", systemImage: "arrow.clockwise") {
                            Task { await sync.syncNow() }
                        }
                        .keyboardShortcut("r")
                    }
                    Button("Settings", systemImage: "gear") { showsSettings = true }
                        .keyboardShortcut(",")
                }
            }
            .safeAreaInset(edge: .bottom) {
                AddTaskBar()
            }
            .sheet(item: $editing) { task in
                EditTaskSheet(task: task)
            }
            .sheet(isPresented: $showsSettings) {
                SettingsView()
            }
        }
    }

    private func rows(_ tasks: [TaskItem], now: Date) -> some View {
        GlassEffectContainer(spacing: 8) {
            LazyVStack(spacing: 8) {
                ForEach(tasks) { task in
                    TaskCapsule(task: task, now: now) { editing = task }
                }
            }
        }
    }
}
