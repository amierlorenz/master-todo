import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
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
