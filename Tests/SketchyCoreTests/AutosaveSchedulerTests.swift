import XCTest
@testable import SketchyCore

final class AutosaveSchedulerTests: XCTestCase {
    func testDebounceCoalescesRapidChanges() {
        let scheduler = AutosaveScheduler(interval: 0.2)
        var fireCount = 0

        scheduler.schedule { fireCount += 1 }
        scheduler.schedule { fireCount += 1 }
        scheduler.flush()

        XCTAssertEqual(fireCount, 1)
    }
}
