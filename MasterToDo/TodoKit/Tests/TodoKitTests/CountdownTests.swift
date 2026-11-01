import Foundation
@testable import TodoKit
import Testing

struct CountdownTests {
    let now = Date(timeIntervalSince1970: 0)

    @Test(arguments: [
        (3 * 86_400 + 8 * 3_600, "3d"),
        (86_400 + 60, "1d"),
        (86_400, "24h"),
        (3_600, "1h"),
        (3_599, "59m"),
        (-5, "0m"),
    ] as [(TimeInterval, String)])
    func coarseUnits(seconds: TimeInterval, expected: String) {
        #expect(Countdown.text(from: now, to: now + seconds) == expected)
    }
}
