import SwiftData
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
    @Environment(\.modelContext) private var modelContext
    @State private var confirmsRemoveAll = false

    private let mainGroups = [0, 1]

    // One fixed layout per bar: swapping layouts (e.g. ViewThatFits) while a group collapses breaks the glass morph.
    var body: some View {
        if isCompact {
            ViewThatFits(in: .horizontal) {
                groups
                ScrollView(.horizontal, showsIndicators: false) { groups }.scrollClipDisabled()
            }
        } else {
            VStack(spacing: 8) {
                if hasNotices {
                    notices.transition(.move(edge: .top).combined(with: .opacity))
                }
                ScrollView(.horizontal, showsIndicators: false) { groups }.scrollClipDisabled()
            }
        }
    }

    private var groups: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                ForEach(mainGroups, id: \.self) { index in
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

    private var noticePick: TaskFilter? { selection.pick(inGroup: TaskFilter.noticeGroup) }

    private var hasNotices: Bool {
        noticePick != nil || TaskFilter.groups[TaskFilter.noticeGroup].contains { count($0) > 0 }
    }

    private var notices: some View {
        let pick = noticePick
        return VStack(spacing: 8) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(TaskFilter.groups[TaskFilter.noticeGroup].filter { pick == nil ? count($0) > 0 : $0 == pick }, id: \.self) { filter in
                        chip(filter, isOn: filter == pick, fillsWidth: true)
                            .glassEffect(filter == pick ? .regular.tint(filter.color).interactive() : .regular.interactive(), in: .capsule)
                            .glassEffectID(filter, in: glassSpace)
                    }
                }
            }
            if let pick {
                bulkActions(for: pick)
                    .font(.footnote.weight(.semibold))
                    .buttonStyle(.glass)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    @ViewBuilder
    private func bulkActions(for pick: TaskFilter) -> some View {
        let matching = tasks.filter { selection.passes($0, now: now, calendar: .current) }
        HStack(spacing: 8) {
            switch pick {
            case .closed:
                // Closed can't be dismissed: it's still overdue, so the only way out is removing it.
                Button("Remove all \(matching.count)", systemImage: "trash", role: .destructive) { confirmsRemoveAll = true }
                    .frame(maxWidth: .infinity)
                    .confirmationDialog("Remove \(matching.count) closed assignments?", isPresented: $confirmsRemoveAll, titleVisibility: .visible) {
                        Button("Remove", role: .destructive) {
                            finish(pick) { matching.forEach { $0.remove(in: modelContext) } }
                        }
                    } message: {
                        Text("They won't come back on the next sync.")
                    }
            case .submitted:
                Button("Dismiss all \(matching.count)", systemImage: "eye.slash") {
                    finish(pick) { matching.forEach { $0.submittedDismissed = true } }
                }
                .frame(maxWidth: .infinity)
                Button("Mark all done", systemImage: "checkmark.circle") {
                    finish(pick) { matching.forEach { $0.state = .done } }
                }
                .frame(maxWidth: .infinity)
            default:
                Button("Dismiss all \(matching.count)", systemImage: "eye.slash") {
                    finish(pick) { matching.forEach { $0.dueDateChanged = false } }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func finish(_ pick: TaskFilter, _ change: () -> Void) {
        withAnimation(.snappy) {
            change()
            selection.toggle(pick)
        }
    }

    private func count(_ filter: TaskFilter) -> Int {
        selection.count(filter, in: tasks, now: now, calendar: .current)
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

    private func chip(_ filter: TaskFilter, isOn: Bool, fillsWidth: Bool = false) -> some View {
        let count = count(filter)
        let showsCount = !isCompact || filter.group != 1
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
            // Fixed first so a wide chip keeps its full title and only the spare room is shared out.
            .fixedSize()
            .frame(maxWidth: fillsWidth ? .infinity : nil)
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
    var title: String { self == .dateChanged ? "Date changed" : rawValue.capitalized }

    var color: Color {
        switch self {
        case .closing: .red
        case .overdue: .orange
        case .upcoming: .blue
        case .undated: .gray
        case .done: .green
        case .canvas: .indigo
        case .manual: .teal
        case .submitted: .green
        case .dateChanged: .blue
        case .closed: .gray
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
        case .submitted: Image(systemName: "checkmark.seal.fill")
        case .dateChanged: Image(systemName: "calendar.badge.clock")
        case .closed: Image(systemName: "lock.fill")
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
