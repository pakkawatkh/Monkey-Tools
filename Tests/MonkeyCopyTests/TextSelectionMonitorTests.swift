import XCTest
@testable import MonkeyCopy

final class TextSelectionMonitorTests: XCTestCase {
    func testValidSelectionTextFiltering() {
        let monitor = TextSelectionMonitor.shared

        // Whitespace & Empty
        XCTAssertFalse(monitor.isValidTranslatableText(""))
        XCTAssertFalse(monitor.isValidTranslatableText("   "))
        XCTAssertFalse(monitor.isValidTranslatableText("\n\t  \r"))

        // Pure punctuation & symbols
        XCTAssertFalse(monitor.isValidTranslatableText("."))
        XCTAssertFalse(monitor.isValidTranslatableText("..."))
        XCTAssertFalse(monitor.isValidTranslatableText(",,, --- === ///"))
        XCTAssertFalse(monitor.isValidTranslatableText("@#$%^&*()"))

        // Pure numbers
        XCTAssertFalse(monitor.isValidTranslatableText("12345"))
        XCTAssertFalse(monitor.isValidTranslatableText("100.50"))

        // Image filenames / URLs
        XCTAssertFalse(monitor.isValidTranslatableText("photo.png"))
        XCTAssertFalse(monitor.isValidTranslatableText("https://example.com/avatar.jpg"))
        XCTAssertFalse(monitor.isValidTranslatableText("banner.webp"))

        // Valid translatable text
        XCTAssertTrue(monitor.isValidTranslatableText("hello"))
        XCTAssertTrue(monitor.isValidTranslatableText("สวัสดี"))
        XCTAssertTrue(monitor.isValidTranslatableText("AI translation"))
        XCTAssertTrue(monitor.isValidTranslatableText("日本語のテキスト"))
        XCTAssertTrue(monitor.isValidTranslatableText("Good morning!"))
    }
}
