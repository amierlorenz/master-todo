import SwiftUI
import TodoKit

/// Status chips explaining why a task needs attention.
struct TaskBadges: View {
    let task: TaskItem

    var body: some View {
        let badges = items
        if !badges.isEmpty {
            HStack(spacing: 6) {
                ForEach(badges, id: \.text) { badge in
                    Text(badge.text)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .foregroundStyle(badge.color)
                        .background(badge.color.opacity(0.15), in: .capsule)
                }
            }
            .transition(.opacity.combined(with: .scale(0.9, anchor: .leading)))
        }
    }

    private var items: [(text: String, color: Color)] {
        var items: [(text: String, color: Color)] = []
        switch task.canvasFlag(now: .now) {
        case .submitted: items.append(("Submitted on Canvas", .green))
        case .closed: items.append(("Closed", .gray))
        case .removedFromCanvas: items.append(("Removed from Canvas", .red))
        case nil: break
        }
        if task.state == .pendingVerification { items.append(("Not turned in on Canvas", .orange)) }
        if task.dueDateChanged { items.append(("Date changed", .blue)) }
        return items
    }
}
