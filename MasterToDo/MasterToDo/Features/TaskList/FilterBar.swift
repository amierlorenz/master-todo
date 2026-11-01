import SwiftUI
import TodoKit

/// The full bar collapses a group to its pick with a glass morph; the compact bar (shown once the
/// list scrolls) is one glass capsule per group, like a segmented control.
struct FilterBar: View {
    @Binding var selection: FilterSelection
    let tasks: [TaskItem]
    let now: Date
    let isCompact: Bool
    @Namespace private var glassSpace

    // One fixed layout per bar: swapping layouts (e.g. ViewThatFits) while a group collapses breaks the glass morph.
    var body: some View {
        if isCompact {
            ViewThatFits(in: .horizontal) {
                groups
                ScrollView(.horizontal, showsIndicators: false) { groups }.scrollClipDisabled()
            }
        } else {
            ScrollView(.horizontal, showsIndicators: false) { groups }.scrollClipDisabled()
        }
    }

    private var groups: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                ForEach(TaskFilter.groups.indices, id: \.self) { index in
                    if index > 0, !isCompact {
                        Capsule().fill(.separator).frame(width: 1.5, height: 22)
                    }
                    if isCompact { segmented(index) } else { collapsing(index) }
                }
            }
        }
    }

    private func collapsing(_ group: Int) -> some View {
        let pick = selection.pick(inGroup: group)
        return GlassEffectContainer(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(TaskFilter.groups[group].filter { pick == nil || $0 == pick }, id: \.self) { filter in
                    chip(filter, isOn: filter == pick)
                        .glassEffect(filter == pick ? .regular.tint(filter.color).interactive() : .regular.interactive(), in: .capsule)
                        .glassEffectID(filter, in: glassSpace)
                }
            }
        }
    }

    private func segmented(_ group: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(TaskFilter.groups[group], id: \.self) { filter in
                let isOn = selection.picked.contains(filter)
                chip(filter, isOn: isOn)
                    .background(filter.color.opacity(isOn ? 1 : 0), in: .capsule)
            }
        }
        .padding(3)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    private func chip(_ filter: TaskFilter, isOn: Bool) -> some View {
        let count = selection.count(filter, in: tasks, now: now, calendar: .current)
        let showsCount = !isCompact || filter.group == 0
        return Button {
            withAnimation(.snappy) { selection.toggle(filter) }
        } label: {
            HStack(spacing: 5) {
                filter.icon(size: isCompact ? 13 : 15)
                if !isCompact { Text(filter.title) }
                if showsCount { Text("\(count)").monospacedDigit() }
                if isOn, !isCompact { Image(systemName: "xmark").font(.caption2.bold()) }
            }
            .font((isCompact ? Font.caption : .footnote).weight(.semibold))
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(isOn ? .white : filter.color)
            .padding(.horizontal, isCompact ? 8 : 11)
            .padding(.vertical, 8)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(filter.title), \(count)")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

extension TaskFilter {
    var title: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .closing: .red
        case .overdue: .orange
        case .upcoming: .blue
        case .undated: .gray
        case .done: .green
        case .canvas: .indigo
        case .manual: .teal
        }
    }

    @ViewBuilder
    func icon(size: CGFloat) -> some View {
        switch self {
        case .closing: Image(systemName: "hourglass")
        case .overdue: Image(systemName: "exclamationmark.circle")
        case .upcoming: Image(systemName: "calendar")
        case .undated: Image(systemName: "tray")
        case .done: Image(systemName: "checkmark.circle")
        case .canvas: CanvasLogo(size: size)
        case .manual: Image(systemName: "person.fill")
        }
    }
}

#Preview {
    @Previewable @State var selection = FilterSelection()
    VStack(spacing: 20) {
        FilterBar(selection: $selection, tasks: PreviewTasks.all, now: .now, isCompact: false)
        FilterBar(selection: $selection, tasks: PreviewTasks.all, now: .now, isCompact: true)
    }
    .padding()
}
