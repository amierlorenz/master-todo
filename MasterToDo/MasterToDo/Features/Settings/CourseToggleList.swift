import SwiftData
import SwiftUI
import TodoKit

/// Turns Canvas courses on or off. Turning one off hides its tasks without deleting them.
struct CourseToggleList: View {
    @Environment(SyncService.self) private var sync
    @Query(sort: \TrackedCourse.name) private var courses: [TrackedCourse]

    var body: some View {
        Group {
            if courses.isEmpty {
                Text(sync.hasCanvasAccount ? "No active courses found." : "Add your Canvas token to choose courses.")
                    .foregroundStyle(.secondary)
            }
            ForEach(courses) { course in
                @Bindable var course = course
                Toggle(isOn: $course.isTracked) {
                    HStack {
                        Text(course.name)
                        if !course.hasBeenOffered {
                            Text("New").font(.caption2.bold()).foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
    }
}
