import AppKit
import ApplicationServices

public struct TextSelectionEvent: Equatable {
    public let text: String
    public let screenRect: CGRect
    public let sourceAppPID: pid_t

    public init(text: String, screenRect: CGRect, sourceAppPID: pid_t) {
        self.text = text
        self.screenRect = screenRect
        self.sourceAppPID = sourceAppPID
    }
}

public final class TextSelectionMonitor: ObservableObject {
    public static let shared = TextSelectionMonitor()

    public var onSelectionDetected: ((TextSelectionEvent) -> Void)?
    public var onSelectionCleared: (() -> Void)?

    private var globalMouseMonitor: Any?
    private var isMonitoring = false
    private var pendingWorkItem: DispatchWorkItem?

    private var mouseDownLocation: CGPoint = .zero
    private var isDragging = false
    private var lastClickCount: Int = 1

    private init() {}

    public func isValidSelectionText(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return false }

        // Ignore if single punctuation
        let punctuationSet = CharacterSet(charactersIn: ".,;:!?\"'()[]{}<>-–—/\\|`~@#$%^&*+=_")
        if trimmed.count == 1, let scalar = trimmed.unicodeScalars.first, punctuationSet.contains(scalar) {
            return false
        }

        return trimmed.count >= 1
    }

    public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            self?.handleMouseEvent(event)
        }
    }

    public func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false

        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
        }
        pendingWorkItem?.cancel()
        pendingWorkItem = nil
    }

    private func handleMouseEvent(_ event: NSEvent) {
        guard AppSettings.shared.selectionTranslateEnabled else { return }

        switch event.type {
        case .leftMouseDown:
            mouseDownLocation = NSEvent.mouseLocation
            isDragging = false
            lastClickCount = event.clickCount

        case .leftMouseDragged:
            let current = NSEvent.mouseLocation
            let dist = hypot(current.x - mouseDownLocation.x, current.y - mouseDownLocation.y)
            if dist > 6.0 {
                isDragging = true
            }

        case .leftMouseUp:
            let shouldCheck = isDragging || lastClickCount >= 2
            isDragging = false

            if shouldCheck {
                scheduleSelectionCheck()
            }

        default:
            break
        }
    }

    private func scheduleSelectionCheck() {
        pendingWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.checkSelectedText()
        }
        pendingWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: workItem)
    }

    public func checkSelectedText() {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }

        // Don't trigger for monkey-copy's own windows
        if frontApp.bundleIdentifier == Bundle.main.bundleIdentifier {
            return
        }

        let pid = frontApp.processIdentifier
        let mouseLoc = NSEvent.mouseLocation

        // Method 1: Try Accessibility API first (fast for native text fields like TextEdit, Mail, Xcode)
        if let axText = queryAXSelectedText(pid: pid), isValidSelectionText(axText.text) {
            let event = TextSelectionEvent(text: axText.text, screenRect: axText.bounds, sourceAppPID: pid)
            onSelectionDetected?(event)
            return
        }

        // Method 2: For browsers (Safari, Chrome) and other apps:
        // Simply show the floating bubble at mouse location WITHOUT copying or touching pasteboard!
        let rect = CGRect(x: mouseLoc.x, y: mouseLoc.y, width: 1, height: 1)
        let event = TextSelectionEvent(text: "", screenRect: rect, sourceAppPID: pid)
        onSelectionDetected?(event)
    }

    private func queryAXSelectedText(pid: pid_t) -> (text: String, bounds: CGRect)? {
        let appElement = AXUIElementCreateApplication(pid)

        var focusedElementObj: AnyObject?
        let focusedResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElementObj)
        guard focusedResult == .success, let focusedElement = focusedElementObj else {
            return nil
        }
        let element = focusedElement as! AXUIElement

        var selectedTextObj: AnyObject?
        let textResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedTextObj)
        guard textResult == .success, let text = selectedTextObj as? String else {
            return nil
        }

        let bounds = getSelectionBounds(element: element)
        return (text, bounds)
    }

    private func getSelectionBounds(element: AXUIElement) -> CGRect {
        var selectedRangeValue: AnyObject?
        let rangeResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedRangeValue)

        if rangeResult == .success, let rangeVal = selectedRangeValue {
            var boundsVal: AnyObject?
            let boundsResult = AXUIElementCopyParameterizedAttributeValue(
                element,
                kAXBoundsForRangeParameterizedAttribute as CFString,
                rangeVal,
                &boundsVal
            )

            if boundsResult == .success, let boundsVal = boundsVal {
                var rect = CGRect.zero
                if AXValueGetValue(boundsVal as! AXValue, .cgRect, &rect) && rect.width > 0 && rect.height > 0 {
                    // Convert AX coordinate (top-left origin) to Cocoa screen coordinate (bottom-left origin)
                    if let mainScreen = NSScreen.main {
                        let screenHeight = mainScreen.frame.height
                        rect.origin.y = screenHeight - (rect.origin.y + rect.height)
                    }
                    return rect
                }
            }
        }

        // Fallback: mouse cursor position
        let mouseLoc = NSEvent.mouseLocation
        return CGRect(x: mouseLoc.x, y: mouseLoc.y, width: 20, height: 20)
    }
}
