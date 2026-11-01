import SwiftData
import SwiftUI
import TodoKit

struct TaskListView: View {
    @Environment(SyncService.self) private var sync
    @Query private var tasks: [TaskItem]
    @Query(filter: #Predicate<TrackedCourse> { $0.isTracked }) private var trackedCourses: [TrackedCourse]
    @Query(filter: #Predicate<TrackedCourse> { !$0.hasBeenOffered }) private var newCourses: [TrackedCourse]
    @State private var filters = FilterSelection()
    @State private var isScrolled = false
    @State private var showsSettings = false
    @State private var showsGuide = false
    @AppStorage(GuideSheet.hasSeenKey) private var hasSeenGuide = false
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
        let all = active + done
        let shown = all.filter { filters.passes($0, now: now, calendar: .current) }

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
                    if !all.isEmpty {
                        FilterBar(selection: $filters, tasks: all, now: now, isCompact: false)
                    }
                    if shown.isEmpty {
                        if filters.picked.isEmpty {
                            ContentUnavailableView("All clear", systemImage: "checkmark.circle", description: Text("Nothing left to do."))
                        } else {
                            ContentUnavailableView("Nothing here", systemImage: "line.3.horizontal.decrease.circle", description: Text("No tasks match these filters."))
                        }
                    }
                    rows(shown, now: now)
                }
                .padding(.horizontal)
                .animation(.default, value: tasks.map(\.stateRaw))
                .animation(.default, value: tasks.count)
                .animation(.snappy, value: filters)
            }
            .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y + $0.contentInsets.top > 90 } action: { _, scrolled in
                withAnimation(.snappy) { isScrolled = scrolled }
            }
            .safeAreaInset(edge: .bottom) {
                if isScrolled, !all.isEmpty {
                    FilterBar(selection: $filters, tasks: all, now: now, isCompact: true)
                        .padding(.bottom, 6)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
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
                    Button("How it works", systemImage: "questionmark.circle") { showsGuide = true }
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
            .sheet(isPresented: $showsGuide) {
                GuideSheet()
            }
            .onAppear {
                if !hasSeenGuide {
                    showsGuide = true
                    hasSeenGuide = true
                }
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
