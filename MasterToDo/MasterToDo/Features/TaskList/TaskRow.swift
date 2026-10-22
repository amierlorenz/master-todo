import SwiftData
import SwiftUI
import TodoKit

struct TaskRow: View {
    let task: TaskItem
    let onEdit: () -> Void
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    private var canvasURL: URL? { task.htmlURL.flatMap(URL.init(string:)) }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Button(task.state == .open ? "Mark done" : "Mark not done", systemImage: checkSymbol, action: toggle)
                .labelStyle(.iconOnly)
                .font(.title3)
                .foregroundStyle(task.state == .pendingVerification ? .orange : .accentColor)
                .contentTransition(.symbolEffect(.replace))
                .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .strikethrough(task.state == .done)
                    .foregroundStyle(task.state == .done ? .secondary : .primary)
                details
                TaskBadges(task: task)
            }

            Spacer(minLength: 0)

            if task.canvasFlag(now: .now) != nil {
                Button("Remove", role: .destructive) {
                    withAnimation { task.remove(in: modelContext) }
                }
                .buttonStyle(.bordered)
            }
        }
        .contentShape(.rect)
        .onTapGesture(perform: open)
        .contextMenu {
            if let canvasURL {
                Button("Open in Canvas", systemImage: "safari") { openURL(canvasURL) }
            }
            if !task.isCanvas {
                Button("Edit", systemImage: "pencil", action: onEdit)
            }
            Button(task.isCanvas ? "Remove" : "Delete", systemImage: "trash", role: .destructive) {
                withAnimation { task.remove(in: modelContext) }
            }
        }
        .swipeActions {
            Button(task.isCanvas ? "Remove" : "Delete", systemImage: "trash", role: .destructive) {
                withAnimation { task.remove(in: modelContext) }
            }
        }
    }

    private var checkSymbol: String {
        switch task.state {
        case .open: "circle"
        case .pendingVerification: "exclamationmark.circle"
        case .done: "checkmark.circle.fill"
        }
    }

    @ViewBuilder
    private var details: some View {
        let course = task.courseName
        let due = task.dueAt
        if course != nil || due != nil {
            HStack(spacing: 6) {
                if let course { Text(course) }
                if let due {
                    Text(due, format: task.hasDueTime ? .dateTime.weekday().month().day().hour().minute() : .dateTime.weekday().month().day())
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func toggle() {
        if task.state == .open {
            Task { await TaskCompletion.complete(task, fetch: CanvasConnection.fetchAssignment) }
        } else {
            TaskCompletion.uncheck(task)
        }
    }

    private func open() {
        guard task.isCanvas else { return onEdit() }
        task.dueDateChanged = false
        if let canvasURL { openURL(canvasURL) }
    }
}
