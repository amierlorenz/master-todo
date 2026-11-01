import Foundation

public enum TaskFilter: String, CaseIterable, Sendable {
    case closing, overdue, upcoming, undated, done
    case canvas, manual

    /// At most one filter per group is picked; picks in different groups combine.
    public static let groups: [[TaskFilter]] = [[.closing, .overdue, .upcoming, .undated, .done], [.canvas, .manual]]

    public var group: Int { Self.groups.firstIndex { $0.contains(self) }! }

    @MainActor
    public func matches(_ task: TaskItem, now: Date, calendar: Calendar) -> Bool {
        let isOpen = task.state != .done
        let bucket = { TaskOrdering.bucket(of: task, now: now, calendar: calendar) }
        return switch self {
        case .closing: isOpen && bucket() == .closing
        case .overdue: isOpen && bucket() == .overdue
        case .upcoming: isOpen && [.today, .later].contains(bucket())
        case .undated: isOpen && bucket() == .noDate
        case .done: !isOpen
        case .canvas: task.isCanvas
        case .manual: !task.isCanvas
        }
    }
}

public struct FilterSelection: Equatable, Sendable {
    public private(set) var picked: Set<TaskFilter> = []

    public init() {}

    public func pick(inGroup group: Int) -> TaskFilter? {
        TaskFilter.groups[group].first(where: picked.contains)
    }

    public mutating func toggle(_ filter: TaskFilter) {
        if picked.contains(filter) {
            picked.remove(filter)
        } else {
            picked.subtract(TaskFilter.groups[filter.group])
            picked.insert(filter)
        }
    }

    /// Done tasks only show when a due-state filter asks for them.
    @MainActor
    public func passes(_ task: TaskItem, now: Date, calendar: Calendar, ignoringGroup skipped: Int? = nil) -> Bool {
        TaskFilter.groups.indices.allSatisfy { group in
            guard group != skipped else { return true }
            if let pick = pick(inGroup: group) { return pick.matches(task, now: now, calendar: calendar) }
            return group != 0 || task.state != .done
        }
    }

    /// How many tasks the filter would show, given what's picked in the other groups.
    @MainActor
    public func count(_ filter: TaskFilter, in tasks: [TaskItem], now: Date, calendar: Calendar) -> Int {
        tasks.count { passes($0, now: now, calendar: calendar, ignoringGroup: filter.group) && filter.matches($0, now: now, calendar: calendar) }
    }
}
