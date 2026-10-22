import SwiftData
import SwiftUI
import TodoKit

struct TaskListView: View {
    @Query private var tasks: [TaskItem]
    @Query(filter: #Predicate<TrackedCourse> { $0.isTracked }) private var trackedCourses: [TrackedCourse]
    @State private var showsDone = false
    @State private var editing: TaskItem?
    var onRefresh: () async -> Void = {}

    private var visibleTasks: [TaskItem] {
        let tracked = Set(trackedCourses.map(\.canvasCourseID))
        return tasks.filter { $0.isVisible(trackedCourseIDs: tracked) }
    }

    var body: some View {
        let active = TaskOrdering.sorted(visibleTasks.filter { $0.state != .done }, now: .now, calendar: .current)
        let done = visibleTasks.filter { $0.state == .done }.sorted { $0.title < $1.title }

        NavigationStack {
            List {
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
            .refreshable { await onRefresh() }
            .toolbar {
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task { await onRefresh() }
                }
                .keyboardShortcut("r")
            }
            .safeAreaInset(edge: .bottom) {
                AddTaskBar()
            }
            .sheet(item: $editing) { task in
                EditTaskSheet(task: task)
            }
        }
    }
}
