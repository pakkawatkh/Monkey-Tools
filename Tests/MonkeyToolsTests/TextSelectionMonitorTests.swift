import XCTest
@testable import MonkeyTools

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

    func testIsEditorOrChatApp() {
        let monitor = TextSelectionMonitor.shared
        // Current process is not an editor/chat app
        XCTAssertFalse(monitor.isEditorOrChatApp(pid: -1))
    }

    func testAutoPasterReplaceOriginalTextInterface() {
        // Test that replaceOriginalText can be invoked safely with invalid PID without crashing
        AutoPaster.shared.replaceOriginalText(with: "Test Replacement", inAppWithPID: -1)
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "Test Replacement")
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

    func testValidSelectionTextWithMixedScriptsAndSymbols() {
        let monitor = TextSelectionMonitor.shared

        // Sentences with punctuation & quotes
        XCTAssertTrue(monitor.isValidTranslatableText("\"Hello, world!\""))
        XCTAssertTrue(monitor.isValidTranslatableText("Is this working?"))
        XCTAssertTrue(monitor.isValidTranslatableText("(Note:สำคัญมาก)"))
        XCTAssertTrue(monitor.isValidTranslatableText("Total: 500 บาท"))
        XCTAssertTrue(monitor.isValidTranslatableText("第1章：はじめに"))
        XCTAssertTrue(monitor.isValidTranslatableText("Русский текст с знаками!"))

        // Pure numbers or symbols without letters must still be rejected
        XCTAssertFalse(monitor.isValidTranslatableText("$100.00"))
        XCTAssertFalse(monitor.isValidTranslatableText("--- 12345 ---"))
        XCTAssertFalse(monitor.isValidTranslatableText("(+66) 81-234-5678"))
    }

    func testSelectionBubblePanelShowSafety() {
        let panel = SelectionBubblePanel.shared

        // Show at typical coordinate
        panel.show(at: CGRect(x: 200, y: 300, width: 50, height: 20), selectedText: "Sample", sourceAppPID: 0, isEditable: false)
        XCTAssertTrue(panel.frame.origin.x > 0)
        XCTAssertTrue(panel.frame.origin.y > 0)

        // Show at extreme right edge of screen (should clamp safely)
        panel.show(at: CGRect(x: 99999, y: 500, width: 1, height: 1), selectedText: "Edge", sourceAppPID: 0, isEditable: false)
        let mainWidth = NSScreen.main?.visibleFrame.maxX ?? 1440
        XCTAssertLessThanOrEqual(panel.frame.maxX, mainWidth + 50)

        panel.orderOut(nil)

        // Showing with empty or invalid text should NEVER make panel visible
        panel.show(at: CGRect(x: 200, y: 300, width: 50, height: 20), selectedText: "", sourceAppPID: 0, isEditable: false)
        XCTAssertFalse(panel.isVisible)

        panel.show(at: CGRect(x: 200, y: 300, width: 50, height: 20), selectedText: "   ", sourceAppPID: 0, isEditable: false)
        XCTAssertFalse(panel.isVisible)

        panel.show(at: CGRect(x: 200, y: 300, width: 50, height: 20), selectedText: "12345", sourceAppPID: 0, isEditable: false)
        XCTAssertFalse(panel.isVisible)
    }

    func testTextSelectionMonitorMonitoringLifecycle() {
        let monitor = TextSelectionMonitor.shared
        // Safe to call multiple times without leaking monitors or crashing
        monitor.startMonitoring()
        monitor.startMonitoring()
        monitor.stopMonitoring()
        monitor.stopMonitoring()
    }

    func testSelectionBubblePanelDismissLifecycle() {
        let panel = SelectionBubblePanel.shared
        panel.show(at: CGRect(x: 100, y: 100, width: 20, height: 20), selectedText: "DismissTest")
        XCTAssertTrue(panel.isVisible)

        panel.hide()
        // Ensure hide finishes and invalidates monitors safely
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        XCTAssertEqual(panel.alphaValue, 0.0)
    }
}
