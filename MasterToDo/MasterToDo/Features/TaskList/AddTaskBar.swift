import SwiftData
import SwiftUI
import TodoKit

struct AddTaskBar: View {
    @Environment(\.modelContext) private var modelContext
    @State private var title = ""
    @State private var showsDate = false
    @State private var hasDate = false
    @State private var date = Date.now
    @State private var hasTime = false

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("New task", text: $title)
                    .textFieldStyle(.plain)
                    .onSubmit(add)
                Button("Due date", systemImage: hasDate ? "calendar.badge.checkmark" : "calendar") {
                    withAnimation { showsDate.toggle() }
                }
                .labelStyle(.iconOnly)
                Button("Add task", systemImage: "plus.circle.fill", action: add)
                    .labelStyle(.iconOnly)
                    .font(.title2)
                    .disabled(trimmedTitle.isEmpty)
            }
            .buttonStyle(.plain)
            if showsDate {
                DueDateFields(hasDate: $hasDate, date: $date, hasTime: $hasTime)
            }
        }
        .padding(12)
        .glassEffect(in: .rect(cornerRadius: 20))
        .padding()
    }

    private func add() {
        guard !trimmedTitle.isEmpty else { return }
        let due = DueDateFields.dueAt(hasDate: hasDate, date: date, hasTime: hasTime)
        withAnimation {
            modelContext.insert(TaskItem(title: trimmedTitle, dueAt: due, hasDueTime: hasDate && hasTime))
        }
        title = ""
        hasDate = false
        hasTime = false
        showsDate = false
    }
}
