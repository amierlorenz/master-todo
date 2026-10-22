import SwiftData
import SwiftUI
import TodoKit

/// First-sync screen: pick which Canvas courses feed the list.
struct CoursePickerView: View {
    @Environment(SyncService.self) private var sync
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TrackedCourse.name) private var courses: [TrackedCourse]
    @State private var selected: Set<Int> = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            List {
                if isLoading && courses.isEmpty {
                    ProgressView("Loading courses…")
                } else if courses.isEmpty {
                    Text(sync.lastError ?? "No active courses found.").foregroundStyle(.secondary)
                }
                ForEach(courses) { course in
                    Toggle(course.name, isOn: Binding(
                        get: { selected.contains(course.canvasCourseID) },
                        set: { isOn in
                            if isOn { selected.insert(course.canvasCourseID) } else { selected.remove(course.canvasCourseID) }
                        }
                    ))
                }
            }
            .navigationTitle("Choose Courses")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not Now", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", role: .confirm, action: confirm)
                        .disabled(selected.isEmpty)
                }
            }
        }
        .task {
            await sync.refreshCourses()
            isLoading = false
        }
    }

    private func confirm() {
        for course in courses {
            course.isTracked = selected.contains(course.canvasCourseID)
            course.hasBeenOffered = true
        }
        try? modelContext.save()
        dismiss()
        Task { await sync.syncNow() }
    }
}
