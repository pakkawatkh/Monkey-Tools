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

    public func isValidTranslatableText(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return false }

        // Must contain at least one letter (rejects pure punctuation, symbols, whitespace, and numbers)
        guard trimmed.rangeOfCharacter(from: .letters) != nil else {
            return false
        }

        // Must not be an image file or URL
        let lower = trimmed.lowercased()
        let imageExtensions = [
            ".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp", ".svg",
            ".tiff", ".ico", ".heic", ".raw", ".psd", ".ai"
        ]
        for ext in imageExtensions {
            if lower.hasSuffix(ext) {
                return false
            }
        }

        return true
    }

    public func isValidSelectionText(_ text: String) -> Bool {
        return isValidTranslatableText(text)
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
            if dist > 3.0 {
                isDragging = true
            }

        case .leftMouseUp:
            let mouseLoc = NSEvent.mouseLocation
            let dist = hypot(mouseLoc.x - mouseDownLocation.x, mouseLoc.y - mouseDownLocation.y)
            let isDoubleClick = event.clickCount >= 2 || lastClickCount >= 2
            let isDrag = isDragging || dist > 3.0
            isDragging = false

            if isDrag || isDoubleClick {
                scheduleSelectionCheck(isDoubleClick: isDoubleClick)
            }

        default:
            break
        }
    }

    private func scheduleSelectionCheck(isDoubleClick: Bool = false) {
        pendingWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.checkSelectedText(isDoubleClick: isDoubleClick)
        }
        pendingWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: workItem)
    }

    public func checkSelectedText(isDoubleClick: Bool = false) {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }

        // Don't trigger for monkey-copy's own windows
        if frontApp.bundleIdentifier == Bundle.main.bundleIdentifier {
            return
        }

        let pid = frontApp.processIdentifier
        let mouseLoc = NSEvent.mouseLocation

        // Method 1: Try Accessibility API first (fast for native text fields like TextEdit, Mail, Xcode, Notes)
        if let axText = queryAXSelectedText(pid: pid) {
            if isValidTranslatableText(axText.text) {
                let event = TextSelectionEvent(text: axText.text, screenRect: axText.bounds, sourceAppPID: pid)
                onSelectionDetected?(event)
            } else {
                onSelectionCleared?()
            }
            return
        }

        // Method 2: For browsers (Safari, Chrome) and other non-AX apps:
        // Stealth probe to verify translatable text exists without modifying clipboard or polluting history
        probeNonAXSelection(pid: pid, mouseLoc: mouseLoc, isDoubleClick: isDoubleClick)
    }

    private func probeNonAXSelection(pid: pid_t, mouseLoc: CGPoint, isDoubleClick: Bool) {
        let pasteboard = NSPasteboard.general
        let oldChangeCount = pasteboard.changeCount

        // 1. In-memory backup of current clipboard contents
        var backupItems: [(types: [NSPasteboard.PasteboardType], data: [NSPasteboard.PasteboardType: Data])] = []
        if let items = pasteboard.pasteboardItems {
            for item in items {
                var itemData: [NSPasteboard.PasteboardType: Data] = [:]
                for type in item.types {
                    if let data = item.data(forType: type) {
                        itemData[type] = data
                    }
                }
                if !itemData.isEmpty {
                    backupItems.append((types: item.types, data: itemData))
                }
            }
        }

        // 2. Suppress clipboard monitor capture so monkey-copy never records this probe
        ClipboardMonitor.shared.isCapturingSuppressed = true

        // 3. Post momentary Cmd + C into active session
        let source = CGEventSource(stateID: .combinedSessionState)
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )

        let cKeyCode: CGKeyCode = 8
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: cKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: cKeyCode, keyDown: false) else {
            ClipboardMonitor.shared.isCapturingSuppressed = false
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cgSessionEventTap)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            keyUp.post(tap: .cgSessionEventTap)
        }

        // 4. Inspect result after 110ms and IMMEDIATELY restore user's original clipboard
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) { [weak self] in
            guard let self = self else {
                ClipboardMonitor.shared.isCapturingSuppressed = false
                return
            }

            let capturedChangeCount = pasteboard.changeCount
            let capturedText = pasteboard.string(forType: .string) ?? ""
            let types = pasteboard.types ?? []
            let isImageType = types.contains {
                $0 == .tiff || $0 == .png || $0.rawValue.contains("image")
            }

            // Immediately restore the user's previous clipboard contents
            pasteboard.clearContents()
            for backup in backupItems {
                let item = NSPasteboardItem()
                for (type, data) in backup.data {
                    item.setData(data, forType: type)
                }
                pasteboard.writeObjects([item])
            }

            // Restore monitoring state after brief debounce
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                ClipboardMonitor.shared.lastChangeCount = pasteboard.changeCount
                ClipboardMonitor.shared.isCapturingSuppressed = false
            }

            // If translatable text was captured:
            if capturedChangeCount != oldChangeCount {
                // If it is an image without translatable text -> DO NOT SHOW BUBBLE
                if isImageType && !self.isValidTranslatableText(capturedText) {
                    self.onSelectionCleared?()
                    return
                }

                // If captured text is whitespace, pure numbers, punctuation -> DO NOT SHOW BUBBLE
                if !self.isValidTranslatableText(capturedText) {
                    self.onSelectionCleared?()
                    return
                }

                // Valid translatable text! Show the floating bubble
                let rect = CGRect(x: mouseLoc.x, y: mouseLoc.y, width: 1, height: 1)
                let event = TextSelectionEvent(text: capturedText, screenRect: rect, sourceAppPID: pid)
                self.onSelectionDetected?(event)
                return
            }

            // Fallback for double-click on words in applications that intercept or slow synthetic copy:
            // When a user double-clicks, a word is guaranteed to be selected!
            if isDoubleClick {
                let rect = CGRect(x: mouseLoc.x, y: mouseLoc.y, width: 1, height: 1)
                let event = TextSelectionEvent(text: "", screenRect: rect, sourceAppPID: pid)
                self.onSelectionDetected?(event)
            } else {
                self.onSelectionCleared?()
            }
        }
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
