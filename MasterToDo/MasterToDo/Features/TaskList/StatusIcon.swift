import SwiftUI
import TodoKit

struct StatusIcon: View {
    let status: TaskStatus

    var body: some View {
        Group {
            if let symbol = status.symbol {
                Image(systemName: symbol).contentTransition(.symbolEffect(.replace))
            } else {
                CanvasLogo(size: 20)
            }
        }
        .font(.title3)
        .foregroundStyle(status.color)
        .frame(width: 26)
        .accessibilityLabel(status.label)
    }
}

extension TaskStatus {
    var label: String {
        switch self {
        case .done: "Done"
        case .dateChanged: "Canvas changed the due date"
        case .notTurnedIn: "Completed in-app, not turned in on Canvas"
        case .removedFromCanvas: "Removed from Canvas"
        case .closed: "Closed in Canvas"
        case .submitted: "Submitted on Canvas"
        case .canvas: "Canvas assignment"
        case .userCreated: "User-created task"
        }
    }

    /// nil means the Canvas logo, which isn't an SF Symbol.
    var symbol: String? {
        switch self {
        case .done: "checkmark.circle.fill"
        case .dateChanged: "calendar.badge.clock"
        case .notTurnedIn: "exclamationmark.triangle.fill"
        case .removedFromCanvas: "trash.fill"
        case .closed: "lock.fill"
        case .submitted: "checkmark.seal.fill"
        case .canvas: nil
        case .userCreated: "person.fill"
        }
    }

    var color: Color {
        switch self {
        case .done, .submitted: .green
        case .dateChanged: .blue
        case .notTurnedIn: .orange
        case .removedFromCanvas: .red
        case .closed: .gray
        case .canvas, .userCreated: .secondary
        }
    }
}
