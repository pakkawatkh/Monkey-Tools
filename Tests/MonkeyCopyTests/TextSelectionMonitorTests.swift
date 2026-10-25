import XCTest
@testable import MonkeyCopy

final class TextSelectionMonitorTests: XCTestCase {
    func testValidSelectionTextFiltering() {
        let monitor = TextSelectionMonitor.shared
        XCTAssertFalse(monitor.isValidSelectionText(""))
        XCTAssertFalse(monitor.isValidSelectionText("   "))
        XCTAssertFalse(monitor.isValidSelectionText("\n\t"))
        XCTAssertFalse(monitor.isValidSelectionText("."))
        XCTAssertFalse(monitor.isValidSelectionText(","))
        XCTAssertTrue(monitor.isValidSelectionText("hello"))
        XCTAssertTrue(monitor.isValidSelectionText("สวัสดี"))
        XCTAssertTrue(monitor.isValidSelectionText("AI translation"))
    }
}
