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

    func testTextSelectionEventIsEditableFlag() {
        let defaultEvent = TextSelectionEvent(
            text: "Hello",
            screenRect: CGRect(x: 10, y: 20, width: 30, height: 40),
            sourceAppPID: 1234
        )
        XCTAssertFalse(defaultEvent.isEditable)

        let editableEvent = TextSelectionEvent(
            text: "Hello",
            screenRect: CGRect(x: 10, y: 20, width: 30, height: 40),
            sourceAppPID: 1234,
            isEditable: true
        )
        XCTAssertTrue(editableEvent.isEditable)

        let readOnlyEvent = TextSelectionEvent(
            text: "Hello",
            screenRect: CGRect(x: 10, y: 20, width: 30, height: 40),
            sourceAppPID: 1234,
            isEditable: false
        )
        XCTAssertFalse(readOnlyEvent.isEditable)
    }

    func testIsElementEditableForInvalidPID() {
        let monitor = TextSelectionMonitor.shared
        // Invalid PID should safely return false without crashing
        XCTAssertFalse(monitor.isElementEditable(pid: -1))
        XCTAssertFalse(monitor.isElementEditable(pid: 999999))
    }

    func testTranslationPopoverViewIsEditableInit() {
        let popoverEditable = TranslationPopoverView(
            originalText: "Hello",
            isEditable: true,
            onClose: {},
            onReplace: { _ in }
        )
        XCTAssertTrue(popoverEditable.isEditable)

        let popoverReadOnly = TranslationPopoverView(
            originalText: "Hello",
            isEditable: false,
            onClose: {},
            onReplace: { _ in }
        )
        XCTAssertFalse(popoverReadOnly.isEditable)
    }
}
