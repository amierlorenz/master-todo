import SwiftUI
import TodoKit

struct EditTaskSheet: View {
    let task: TaskItem
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var hasDate = false
    @State private var date = Date.now
    @State private var hasTime = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                DueDateFields(hasDate: $hasDate, date: $date, hasTime: $hasTime)
            }
            .formStyle(.grouped)
            .navigationTitle("Edit Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", role: .confirm, action: save)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            title = task.title
            hasDate = task.dueAt != nil
            date = task.dueAt ?? .now
            hasTime = task.hasDueTime
        }
    }

    private func save() {
        task.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        task.dueAt = DueDateFields.dueAt(hasDate: hasDate, date: date, hasTime: hasTime)
        task.hasDueTime = hasDate && hasTime
        dismiss()
    }
}
