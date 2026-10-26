import AppKit
import ApplicationServices

public struct TextSelectionEvent: Equatable {
    public let text: String
    public let screenRect: CGRect
    public let sourceAppPID: pid_t
    public let isEditable: Bool

    public init(text: String, screenRect: CGRect, sourceAppPID: pid_t, isEditable: Bool = false) {
        self.text = text
        self.screenRect = screenRect
        self.sourceAppPID = sourceAppPID
        self.isEditable = isEditable
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
                let editable = isElementEditable(pid: pid, mouseLoc: mouseLoc)
                let event = TextSelectionEvent(text: axText.text, screenRect: axText.bounds, sourceAppPID: pid, isEditable: editable)
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
                let editable = self.isElementEditable(pid: pid, mouseLoc: mouseLoc)
                let rect = CGRect(x: mouseLoc.x, y: mouseLoc.y, width: 1, height: 1)
                let event = TextSelectionEvent(text: capturedText, screenRect: rect, sourceAppPID: pid, isEditable: editable)
                self.onSelectionDetected?(event)
                return
            }

            // Fallback for double-click on words in applications that intercept or slow synthetic copy:
            // When a user double-clicks, a word is guaranteed to be selected!
            if isDoubleClick {
                let editable = self.isElementEditable(pid: pid, mouseLoc: mouseLoc)
                let rect = CGRect(x: mouseLoc.x, y: mouseLoc.y, width: 1, height: 1)
                let event = TextSelectionEvent(text: "", screenRect: rect, sourceAppPID: pid, isEditable: editable)
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

    public func isElementEditable(pid: pid_t, mouseLoc: CGPoint? = nil) -> Bool {
        guard pid > 0 else { return false }

        let appElement = AXUIElementCreateApplication(pid)

        // Enable AX on Chromium/Electron apps so they populate inner elements
        AXUIElementSetAttributeValue(appElement, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)

        // 1. Check focused element of the application
        var focusedElementObj: AnyObject?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElementObj) == .success,
           let focused = focusedElementObj {
            if isAXElementEditable(focused as! AXUIElement) {
                return true
            }
        }

        // 2. Check focused window -> focused element
        var focusedWindowObj: AnyObject?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindowObj) == .success,
           let win = focusedWindowObj {
            var winFocusedObj: AnyObject?
            if AXUIElementCopyAttributeValue(win as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &winFocusedObj) == .success,
               let winFocused = winFocusedObj {
                if isAXElementEditable(winFocused as! AXUIElement) {
                    return true
                }
            }
        }

        // 3. Check element under mouse position and its ancestors (e.g. text node inside an input or textarea in a browser)
        if let mouseLoc = mouseLoc {
            let screenHeight = NSScreen.screens.first?.frame.height ?? 1080
            let axPoint = CGPoint(x: mouseLoc.x, y: screenHeight - mouseLoc.y)
            var elementAtPos: AXUIElement?
            if AXUIElementCopyElementAtPosition(appElement, Float(axPoint.x), Float(axPoint.y), &elementAtPos) == .success,
               let el = elementAtPos {
                if isAXElementEditable(el) {
                    return true
                }

                // Check up to 3 parent levels (e.g. static text child inside an <input> or <textarea>)
                var current = el
                for _ in 0..<3 {
                    var parentObj: AnyObject?
                    if AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parentObj) == .success,
                       let parent = parentObj {
                        let parentEl = parent as! AXUIElement
                        if isAXElementEditable(parentEl) {
                            return true
                        }
                        current = parentEl
                    } else {
                        break
                    }
                }
            }
        }

        // 4. App-level heuristics:
        // If the frontmost app is an editor, IDE, or chat app (NOT a static viewer like Preview/Books),
        // text selected in it is typable/editable.
        if isEditorOrChatApp(pid: pid) {
            return true
        }

        return false
    }

    public func isEditorOrChatApp(pid: pid_t) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: pid),
              let bundleId = app.bundleIdentifier?.lowercased() else {
            return false
        }
        let editorKeywords = [
            "textedit", "notes", "xcode", "code", "sublime", "atom", "bbedit",
            "intellij", "goland", "pycharm", "webstorm", "clion", "rider",
            "dbeaver", "datagrip", "postman", "terminal", "iterm",
            "word", "excel", "powerpoint", "pages", "numbers", "keynote",
            "slack", "line", "teams", "telegram", "discord", "whatsapp",
            "messages", "skype", "wechat", "kiro"
        ]
        for kw in editorKeywords {
            if bundleId.contains(kw) {
                return true
            }
        }
        return false
    }

    public func isAXElementEditable(_ element: AXUIElement) -> Bool {
        var roleObj: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleObj)
        let role = (roleObj as? String) ?? ""

        var subroleObj: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subroleObj)
        let subrole = (subroleObj as? String) ?? ""

        // 1. Roles that are inherently editable text fields or text areas
        if role == "AXTextField" || role == "AXTextArea" || role == "AXSearchField" || subrole == "AXEditableText" {
            return true
        }

        // 2. Settability of SelectedText (AppKit NSTextView, WebKit editable text)
        var isSelSettable: DarwinBoolean = false
        if AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &isSelSettable) == .success,
           isSelSettable.boolValue {
            return true
        }

        // 3. Settability of Value (single line inputs, text fields)
        var isValSettable: DarwinBoolean = false
        if AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &isValSettable) == .success,
           isValSettable.boolValue {
            if role != "AXSlider" && role != "AXCheckBox" && role != "AXButton" && role != "AXProgressIndicator" && role != "AXScrollArea" && role != "AXWebArea" {
                return true
            }
        }

        return false
    }
}
