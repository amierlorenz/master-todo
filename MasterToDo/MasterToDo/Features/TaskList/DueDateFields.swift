import SwiftUI

/// Optional due date with an optional time, shared by adding and editing.
struct DueDateFields: View {
    @Binding var hasDate: Bool
    @Binding var date: Date
    @Binding var hasTime: Bool

    var body: some View {
        Toggle("Due date", isOn: $hasDate.animation())
        if hasDate {
            DatePicker("Due", selection: $date, displayedComponents: hasTime ? [.date, .hourAndMinute] : .date)
            Toggle("Time", isOn: $hasTime.animation())
        }
    }

    /// The stored due date: the chosen moment, or the start of the chosen day.
    static func dueAt(hasDate: Bool, date: Date, hasTime: Bool) -> Date? {
        guard hasDate else { return nil }
        return hasTime ? date : Calendar.current.startOfDay(for: date)
    }
}
