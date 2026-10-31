import XCTest
@testable import MonkeyTools

final class UpdateCheckServiceTests: XCTestCase {
    func testThrottlingLogic() {
        let service = UpdateCheckService()
        let now = Date()

        // No previous check -> should check
        XCTAssertTrue(service.shouldCheck(now: now, lastCheck: nil))

        // Checked 1 hour ago -> should NOT check
        let oneHourAgo = now.addingTimeInterval(-3600)
        XCTAssertFalse(service.shouldCheck(now: now, lastCheck: oneHourAgo))

        // Checked 23 hours ago -> should NOT check
        let twentyThreeHoursAgo = now.addingTimeInterval(-23 * 3600)
        XCTAssertFalse(service.shouldCheck(now: now, lastCheck: twentyThreeHoursAgo))

        // Checked 25 hours ago -> should check
        let twentyFiveHoursAgo = now.addingTimeInterval(-25 * 3600)
        XCTAssertTrue(service.shouldCheck(now: now, lastCheck: twentyFiveHoursAgo))
    }

    func testCurrentAppVersionNotEmpty() {
        let service = UpdateCheckService()
        XCTAssertFalse(service.currentAppVersion.isEmpty)
    }
}
