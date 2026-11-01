import Foundation
@testable import TodoKit
import Testing

@MainActor
struct DueLabelTests {
    let cal: Calendar = {
        var cal = Calendar.newYork
        cal.locale = Locale(identifier: "en_US")
        return cal
    }()

    private func label(due: Date?, lockAt: Date? = nil) -> String? {
        let task = TaskItem(title: "t", dueAt: due, hasDueTime: due != nil)
        task.lockAt = lockAt
        return DueLabel(task, now: cal.at(2026, 10, 21, 12), calendar: cal).map { [$0.value, $0.caption].compactMap(\.self).joined(separator: " ") }
    }

    @Test func closingCountsDownToClose() {
        #expect(label(due: cal.at(2026, 10, 20, 9), lockAt: cal.at(2026, 10, 24, 15)) == "3d left")
    }

    @Test func overdueCountsTimeLate() {
        #expect(label(due: cal.at(2026, 10, 19, 9)) == "2d late")
    }

    @Test func todayShowsHoursLeft() {
        #expect(label(due: cal.at(2026, 10, 21, 17)) == "5h left")
    }

    @Test func withinAWeekShowsWeekday() {
        #expect(label(due: cal.at(2026, 10, 27, 9)) == "Tue")
    }

    @Test func laterShowsMonthAndDay() {
        #expect(label(due: cal.at(2026, 11, 14, 9)) == "11/14")
    }

    @Test func undatedHasNoLabel() {
        #expect(label(due: nil) == nil)
    }
}

