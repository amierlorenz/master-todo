import Foundation

public enum TaskSource: String, Codable, Sendable, CaseIterable {
    case canvas
    case google
    case articulate
    case user
}
