import SwiftData
import SwiftUI
import TodoKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncService.self) private var sync
    @Query private var courses: [TrackedCourse]
    @AppStorage(NotificationService.summaryHourKey) private var summaryHour = 8
    @AppStorage(NotificationService.summaryMinuteKey) private var summaryMinute = 0
    @State private var summaryTime = Date.now

    var body: some View {
        NavigationStack {
            Form {
                CanvasAccountSection()
                Section("Courses") {
                    CourseToggleList()
                }
                Section("Notifications") {
                    DatePicker("Daily summary", selection: $summaryTime, displayedComponents: .hourAndMinute)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", role: .confirm) { dismiss() }
                }
            }
        }
        .task { await sync.refreshCourses() }
        .onDisappear {
            for course in courses { course.hasBeenOffered = true }
            Task { await sync.syncNow() }
        }
        .onAppear {
            summaryTime = Calendar.current.date(bySettingHour: summaryHour, minute: summaryMinute, second: 0, of: .now) ?? .now
        }
        .onChange(of: summaryTime) {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: summaryTime)
            summaryHour = parts.hour ?? 8
            summaryMinute = parts.minute ?? 0
        }
    }
}
