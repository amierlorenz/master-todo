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
        let active = TaskOrdering.sorted(visibleTasks.filter { $0.state != .done }, now: .now, calendar: .current)
        let done = visibleTasks.filter { $0.state == .done }.sorted { $0.title < $1.title }

        NavigationStack {
            List {
                if let error = sync.lastError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
                if !trackedCourses.isEmpty, !newCourses.isEmpty {
                    Button("\(newCourses.count) new Canvas \(newCourses.count == 1 ? "course" : "courses") — choose in Settings", systemImage: "sparkles") {
                        showsSettings = true
                    }
                }
                if active.isEmpty {
                    ContentUnavailableView("All clear", systemImage: "checkmark.circle", description: Text("Nothing left to do."))
                }
                ForEach(active) { task in
                    TaskRow(task: task) { editing = task }
                }
                if !done.isEmpty {
                    Section {
                        if showsDone {
                            ForEach(done) { task in
                                TaskRow(task: task) { editing = task }
                            }
                        }
                    } header: {
                        Button(showsDone ? "Hide Done (\(done.count))" : "Show Done (\(done.count))") {
                            withAnimation { showsDone.toggle() }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .animation(.default, value: tasks.map(\.stateRaw))
            .animation(.default, value: tasks.count)
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
}
