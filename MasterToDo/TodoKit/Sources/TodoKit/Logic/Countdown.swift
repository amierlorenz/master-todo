import Foundation

public enum Countdown {
    public static func text(from now: Date, to end: Date) -> String {
        let seconds = max(0, end.timeIntervalSince(now))
        if seconds > 86_400 { return "\(Int(seconds / 86_400))d" }
        if seconds >= 3_600 { return "\(Int(seconds / 3_600))h" }
        return "\(Int(seconds / 60))m"
    }
}
