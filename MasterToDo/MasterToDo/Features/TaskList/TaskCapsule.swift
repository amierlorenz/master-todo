import SwiftData
import SwiftUI
import TodoKit

struct TaskCapsule: View {
    let task: TaskItem
    let now: Date
    let onEdit: () -> Void
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @AppStorage(CompleteControl.tapToCompleteKey) private var tapToComplete = false
    @State private var drag: CGFloat = 0
    @State private var rowWidth: CGFloat = 0
    @State private var isArmed = false
    @State private var isPastThreshold = false
    @State private var isCompleting = false
    @State private var confirmsDelete = false

    private var isDone: Bool { task.state == .done }
    private var canvasURL: URL? { task.htmlURL.flatMap(URL.init(string:)) }
    private var maxDrag: CGFloat { max(0, rowWidth - DateCircle.size - 10) }
    private var verb: String { task.isCanvas ? "Remove" : "Delete" }

    var body: some View {
        let status = task.status(now: now)
        HStack(spacing: 10) {
            Button {
                withAnimation { task.dueDateChanged = false }
            } label: {
                StatusIcon(status: status)
            }
            .buttonStyle(.plain)
            .disabled(status != .dateChanged)
            .help(status == .dateChanged ? "\(status.label). Tap to dismiss." : status.label)

            Menu {
                menuItems
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(task.title).font(.subheadline.weight(.medium)).lineLimit(1)
                        if let course = task.courseName {
                            Text(course).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .buttonStyle(.plain)

            Color.clear.frame(width: DateCircle.size, height: DateCircle.size)
        }
        .padding(.leading, 14)
        .padding(.trailing, 5)
        .padding(.vertical, 5)
        // Drawn over the text so the frosted track hides what the circle slides across.
        .overlay(alignment: .trailing) {
            ZStack(alignment: .trailing) {
                if drag < 0 { track }
                if isDone {
                    deleteButton.padding(.trailing, 5)
                } else {
                    DateCircle(
                        label: DueLabel(task, now: now, calendar: .current),
                        bucket: TaskOrdering.bucket(of: task, now: now, calendar: .current),
                        isArmed: isArmed || isCompleting,
                        undatedSymbol: tapToComplete ? "checkmark" : "chevron.left.2"
                    )
                    .offset(x: drag)
                    .padding(.trailing, 5)
                    .modifier(CompleteControl(
                        isEnabled: !isCompleting, maxDrag: maxDrag,
                        drag: $drag, isArmed: $isArmed, isPastThreshold: $isPastThreshold, complete: complete
                    ))
                }
            }
        }
        .glassEffect(glass, in: .capsule)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { rowWidth = $0 }
        .onChange(of: task.state) {
            drag = 0
            isArmed = false
            isCompleting = false
        }
        .sensoryFeedback(.success, trigger: isCompleting) { _, completing in completing }
        .sensoryFeedback(.impact(weight: .light), trigger: task.dueDateChanged) { wasChanged, isChanged in wasChanged && !isChanged }
        .accessibilityAction(named: isDone ? "Mark not done" : "Complete") {
            if isDone { TaskCompletion.uncheck(task) } else { complete() }
        }
    }

    private var glass: Glass {
        if isDone { return .regular.tint(.green.opacity(0.15)).interactive() }
        if isArmed || isCompleting { return .regular.tint(.green.opacity(0.12)).interactive() }
        return .regular.interactive()
    }

    @ViewBuilder
    private var menuItems: some View {
        if let canvasURL {
            Button("Open in Canvas", systemImage: "safari") {
                task.dueDateChanged = false
                openURL(canvasURL)
            }
        } else {
            Button("Edit", systemImage: "pencil", action: onEdit)
        }
        if task.state == .open {
            Button("Complete", systemImage: "checkmark.circle", action: complete)
        } else {
            Button("Mark not done", systemImage: "arrow.uturn.backward.circle") { TaskCompletion.uncheck(task) }
        }
        Button(verb, systemImage: "trash", role: .destructive) {
            withAnimation { task.remove(in: modelContext) }
        }
    }

    private var track: some View {
        Capsule()
            .fill(.green.opacity(isCompleting ? 0.3 : 0.15))
            .background(.thinMaterial, in: .capsule)
            .overlay(alignment: .trailing) {
                // Row-wide and pinned to the trailing edge, so the label stays put while the track reveals it.
                Label("Complete", systemImage: "checkmark")
                    .font(.subheadline.bold())
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: isPastThreshold)
                    .frame(width: rowWidth)
                    .scaleEffect(isPastThreshold || isCompleting ? 1 : 0.5)
                    .opacity(isPastThreshold || isCompleting ? 1 : 0)
                    .blur(radius: isPastThreshold || isCompleting ? 0 : 4)
                    .animation(.bouncy(duration: 0.3), value: isPastThreshold)
            }
            .frame(width: DateCircle.size + 10 - drag)
            .clipShape(.capsule)
    }

    private var deleteButton: some View {
        Button(verb, systemImage: "trash") { confirmsDelete = true }
            .labelStyle(.iconOnly)
            .buttonStyle(TrashButtonStyle(isActive: confirmsDelete))
            .confirmationDialog("\(verb) “\(task.title)”?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button(verb, role: .destructive) {
                    withAnimation { task.remove(in: modelContext) }
                }
            } message: {
                if task.isCanvas { Text("It won't come back on the next sync.") }
            }
    }

    private func complete() {
        withAnimation(.snappy) {
            if drag < 0 { drag = -maxDrag }
            isCompleting = true
        }
        Task {
            // Let the check land before the row changes state and moves.
            try? await Task.sleep(for: .milliseconds(450))
            await TaskCompletion.complete(task, fetch: CanvasConnection.fetchAssignment)
        }
    }
}

private struct TrashButtonStyle: ButtonStyle {
    /// Stays red while the confirmation dialog is open.
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        let isRed = configuration.isPressed || isActive
        configuration.label
            .font(.headline)
            .foregroundStyle(isRed ? .white : .gray)
            .frame(width: DateCircle.size, height: DateCircle.size)
            .background(isRed ? Color.red : .gray.opacity(0.15), in: .circle)
            .animation(.snappy, value: isRed)
    }
}

#Preview("Every state") {
    ScrollView {
        GlassEffectContainer(spacing: 8) {
            VStack(spacing: 8) {
                ForEach(PreviewTasks.all) { TaskCapsule(task: $0, now: .now) {} }
            }
        }
        .padding()
    }
    .background(.background.secondary)
    .modelContainer(PreviewTasks.container)
}
