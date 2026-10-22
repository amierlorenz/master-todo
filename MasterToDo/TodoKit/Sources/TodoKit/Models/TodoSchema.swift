import SwiftData

public enum TodoSchema {
    public static let models: [any PersistentModel.Type] = [TaskItem.self, TrackedCourse.self, RemovedCanvasItem.self]
}
