import SwiftUI
import TodoKit

struct DateCircle: View {
    static let size: CGFloat = 46

    let label: DueLabel?
    let bucket: TaskOrdering.Bucket
    /// About to complete: hovered on Mac, mid-slide or tapped once on iOS.
    let isArmed: Bool
    let undatedSymbol: String

    var body: some View {
        let tint = label == nil ? Color.gray : bucket.tint
        let isSolid = isArmed || bucket == .closing
        VStack(spacing: -2) {
            if isArmed {
                Image(systemName: "checkmark").font(.headline)
                    .transition(.scale(0.3).combined(with: .opacity))
            } else if let label {
                Group {
                    Text(label.value).font(.subheadline.bold().monospacedDigit()).minimumScaleFactor(0.7)
                    if let caption = label.caption { Text(caption).font(.system(size: 9).weight(.semibold)) }
                }
                .transition(.scale(0.6).combined(with: .opacity))
            } else {
                Image(systemName: undatedSymbol).font(.caption.bold())
            }
        }
        .lineLimit(1)
        .foregroundStyle(isSolid ? .white : tint)
        .frame(width: Self.size, height: Self.size)
        .background((isArmed ? .green : tint).opacity(isSolid ? 1 : 0.15), in: .circle)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label.map { [$0.value, $0.caption].compactMap(\.self).joined(separator: " ") } ?? "No due date")
    }
}

extension TaskOrdering.Bucket {
    var tint: Color {
        switch self {
        case .closing: .red
        case .overdue: .orange
        case .today, .later: .blue
        case .noDate: .gray
        }
    }
}
