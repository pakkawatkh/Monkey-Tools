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
        let maxScreenX = NSScreen.screens.map { $0.visibleFrame.maxX }.max() ?? 1440
        XCTAssertLessThanOrEqual(panel.frame.maxX, maxScreenX + 50)

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

    func testExcludedAppFromNonAXProbe() {
        let monitor = TextSelectionMonitor.shared
        XCTAssertTrue(monitor.isExcludedAppFromNonAXProbe(bundleIdentifier: "com.apple.finder"))
        XCTAssertTrue(monitor.isExcludedAppFromNonAXProbe(bundleIdentifier: "com.apple.Finder"))
        XCTAssertTrue(monitor.isExcludedAppFromNonAXProbe(bundleIdentifier: "com.apple.dock"))
        XCTAssertTrue(monitor.isExcludedAppFromNonAXProbe(bundleIdentifier: "com.apple.Spotlight"))
        XCTAssertFalse(monitor.isExcludedAppFromNonAXProbe(bundleIdentifier: "com.apple.Safari"))
        XCTAssertFalse(monitor.isExcludedAppFromNonAXProbe(bundleIdentifier: "com.google.Chrome"))
        XCTAssertFalse(monitor.isExcludedAppFromNonAXProbe(bundleIdentifier: nil))
    }

    func testIsFilePasteboardTypes() {
        let monitor = TextSelectionMonitor.shared
        XCTAssertTrue(monitor.isFilePasteboardTypes([.fileURL]))
        XCTAssertTrue(monitor.isFilePasteboardTypes([NSPasteboard.PasteboardType("public.file-url")]))
        XCTAssertTrue(monitor.isFilePasteboardTypes([NSPasteboard.PasteboardType("NSFilenamesPboardType")]))
        XCTAssertTrue(monitor.isFilePasteboardTypes([NSPasteboard.PasteboardType("com.apple.finder.noderef")]))
        XCTAssertFalse(monitor.isFilePasteboardTypes([.string, .rtf, .html]))
        XCTAssertFalse(monitor.isFilePasteboardTypes([]))
    }

    func testNonTextUIRoleFiltering() {
        let monitor = TextSelectionMonitor.shared

        // Non-text UI chrome must be rejected
        XCTAssertTrue(monitor.isNonTextUIRole("AXButton"))
        XCTAssertTrue(monitor.isNonTextUIRole("AXToolbar"))
        XCTAssertTrue(monitor.isNonTextUIRole("AXTitleBar"))
        XCTAssertTrue(monitor.isNonTextUIRole("AXTab"))
        XCTAssertTrue(monitor.isNonTextUIRole("AXTabGroup"))
        XCTAssertTrue(monitor.isNonTextUIRole("AXImage"))
        XCTAssertTrue(monitor.isNonTextUIRole("AXScrollBar"))
        XCTAssertTrue(monitor.isNonTextUIRole("AXUnknown", subrole: "AXCloseButton"))

        // Text / content containers (including AXWindow for Electron/Chromium fallback) must remain allowed
        XCTAssertFalse(monitor.isNonTextUIRole("AXWindow"))
        XCTAssertFalse(monitor.isNonTextUIRole("AXStaticText"))
        XCTAssertFalse(monitor.isNonTextUIRole("AXTextField"))
        XCTAssertFalse(monitor.isNonTextUIRole("AXTextArea"))
        XCTAssertFalse(monitor.isNonTextUIRole("AXWebArea"))
        XCTAssertFalse(monitor.isNonTextUIRole("AXGroup"))
    }

    func testSelectionBoundsProximityCheck() {
        let monitor = TextSelectionMonitor.shared
        let selectionRect = CGRect(x: 200, y: 300, width: 80, height: 20)

        // Click on or near the selected text passes
        XCTAssertTrue(monitor.isPoint(CGPoint(x: 240, y: 310), nearSelectionRect: selectionRect))
        XCTAssertTrue(monitor.isPoint(CGPoint(x: 320, y: 310), nearSelectionRect: selectionRect))

        // Click far away (stale selection in another part of window) is rejected
        XCTAssertFalse(monitor.isPoint(CGPoint(x: 800, y: 310), nearSelectionRect: selectionRect))
        XCTAssertFalse(monitor.isPoint(CGPoint(x: 240, y: 600), nearSelectionRect: selectionRect))
    }

    func testDoubleClickTriggerValidation() {
        let monitor = TextSelectionMonitor.shared

        // Double-click on a single word/phrase passes
        XCTAssertTrue(monitor.isValidSelectionForTrigger("hello", isDrag: false, clickCount: 2))
        XCTAssertTrue(monitor.isValidSelectionForTrigger("สวัสดีครับ", isDrag: false, clickCount: 2))

        // Double-click yielding multi-line text (e.g. stale highlight or list row) is rejected
        XCTAssertFalse(monitor.isValidSelectionForTrigger("Line 1\nLine 2", isDrag: false, clickCount: 2))

        // Drag or triple-click selecting multi-line text still passes
        XCTAssertTrue(monitor.isValidSelectionForTrigger("Line 1\nLine 2", isDrag: true, clickCount: 1))
        XCTAssertTrue(monitor.isValidSelectionForTrigger("Line 1\nLine 2", isDrag: false, clickCount: 3))
    }

    func testRapidHideThenShowKeepsBubbleVisible() {
        let panel = SelectionBubblePanel.shared
        panel.show(at: CGRect(x: 100, y: 100, width: 20, height: 20), selectedText: "First")
        panel.hide()
        // Re-show immediately before the 120ms fade-out animation finishes
        panel.show(at: CGRect(x: 120, y: 120, width: 20, height: 20), selectedText: "Second")

        RunLoop.main.run(until: Date().addingTimeInterval(0.20))
        XCTAssertTrue(panel.isVisible)
        XCTAssertEqual(panel.alphaValue, 1.0)
        panel.orderOut(nil)
    }

    func testBubbleOriginNeverCoversSelectedText() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)

        // 1. Exact AX text rect in middle of screen -> bubble floats snugly ABOVE text with zero overlap
        let textRect = CGRect(x: 300, y: 500, width: 140, height: 22)
        let originAbove = SelectionBubblePanel.computeBubbleOrigin(for: textRect, in: screenFrame)
        let bubbleAbove = CGRect(origin: originAbove, size: CGSize(width: 26, height: 26))
        XCTAssertFalse(bubbleAbove.intersects(textRect))
        XCTAssertGreaterThanOrEqual(bubbleAbove.minY, textRect.maxY + 4)

        // 2. Cursor-point fallback (width=1, height=1) -> bubble sits close to mouse & cleanly ABOVE text line
        let pointRect = CGRect(x: 400, y: 500, width: 1, height: 1)
        let originPoint = SelectionBubblePanel.computeBubbleOrigin(for: pointRect, in: screenFrame)
        XCTAssertGreaterThanOrEqual(originPoint.y, pointRect.origin.y + 11)
        XCTAssertLessThanOrEqual(originPoint.y, pointRect.origin.y + 14)

        // 3. Selection near top of screen -> bubble flips cleanly BELOW text instead of covering it
        let topTextRect = CGRect(x: 300, y: 870, width: 140, height: 22)
        let originBelow = SelectionBubblePanel.computeBubbleOrigin(for: topTextRect, in: screenFrame)
        let bubbleBelow = CGRect(origin: originBelow, size: CGSize(width: 26, height: 26))
        XCTAssertFalse(bubbleBelow.intersects(topTextRect))
        XCTAssertLessThanOrEqual(bubbleBelow.maxY, topTextRect.minY - 4)
    }
}
