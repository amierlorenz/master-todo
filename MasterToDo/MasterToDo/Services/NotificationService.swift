import Foundation
import SwiftData
import TodoKit
import UserNotifications

/// Replaces pending notifications with the planner's current set.
@MainActor
enum NotificationService {
    static let summaryHourKey = "summaryHour"
    static let summaryMinuteKey = "summaryMinute"

    static func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    static func replan(context: ModelContext) async {
        let tasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        let tracked = Set(((try? context.fetch(FetchDescriptor<TrackedCourse>())) ?? []).filter(\.isTracked).map(\.canvasCourseID))
        let defaults = UserDefaults.standard
        let summaryTime = DateComponents(
            hour: defaults.object(forKey: summaryHourKey) as? Int ?? 8,
            minute: defaults.object(forKey: summaryMinuteKey) as? Int ?? 0
        )
        let calendar = Calendar.current
        let planned = NotificationPlanner.plan(tasks: tasks, trackedCourseIDs: tracked, summaryTime: summaryTime, now: .now, calendar: calendar)

        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        for notification in planned {
            let content = UNMutableNotificationContent()
            content.title = notification.title
            content.body = notification.body
            content.sound = .default
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: notification.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: notification.id, content: content, trigger: trigger))
        }
    }
}
