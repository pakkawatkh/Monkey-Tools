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
    private var mouseDownAppPID: pid_t = 0
    private var isDragging = false
    private var lastClickCount: Int = 1
    private var isProbeInProgress = false

    private init() {}

    /// Returns true if an AX role/subrole represents non-text UI chrome (buttons, tabs, toolbars, titlebars, images, scrollbars, etc.)
    /// where double-clicking should NEVER trigger text translation.
    public func isNonTextUIRole(_ role: String, subrole: String = "") -> Bool {
        let nonTextRoles: Set<String> = [
            "AXButton", "AXCheckBox", "AXRadioButton", "AXPopUpButton", "AXMenuButton",
            "AXMenuBar", "AXMenuBarItem", "AXMenu", "AXMenuItem",
            "AXTabGroup", "AXTab", "AXToolbar", "AXTitleBar",
            "AXScrollBar", "AXValueIndicator", "AXSlider", "AXImage",
            "AXDockItem", "AXSplitter", "AXGrowArea", "AXDisclosureTriangle",
            "AXIncrementor", "AXColorWell", "AXProgressIndicator", "AXBusyIndicator",
            "AXRelevanceIndicator", "AXRuler", "AXRulerMarker", "AXMatte",
            "AXHandle", "AXApplication", "AXWindow"
        ]
        if nonTextRoles.contains(role) {
            return true
        }
        let nonTextSubroles: Set<String> = [
            "AXCloseButton", "AXMinimizeButton", "AXZoomButton", "AXFullScreenButton",
            "AXToolbarButton", "AXTabButton", "AXSortButton",
            "AXIncrementArrow", "AXDecrementArrow", "AXSystemDialog"
        ]
        return nonTextSubroles.contains(subrole)
    }

    /// Returns true if `point` (Cocoa screen coordinates) lies within a reasonable proximity of `selectionRect`.
    /// Prevents stale selections in another area of the window (e.g. address bar or earlier highlight) from firing when clicking empty space.
    public func isPoint(_ point: CGPoint, nearSelectionRect selectionRect: CGRect, horizontalMargin: CGFloat = 140, verticalMargin: CGFloat = 90) -> Bool {
        guard selectionRect.width > 0 && selectionRect.height > 0 else { return true }
        return selectionRect.insetBy(dx: -horizontalMargin, dy: -verticalMargin).contains(point)
    }

    /// Validates that captured text makes sense for the gesture that triggered it.
    /// A double-click selects a single word/segment on one line, never a multi-line block copied from a stale selection or list row.
    public func isValidSelectionForTrigger(_ text: String, isDrag: Bool, clickCount: Int) -> Bool {
        guard isValidTranslatableText(text) else { return false }
        if !isDrag && clickCount == 2 {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.contains("\n") || trimmed.contains("\r") {
                return false
            }
        }
        return true
    }

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

    /// Returns true if the app is a file manager or system shell where selecting icons is not text selection.
    /// Blindly sending Cmd+C to these apps causes file copying instead of text selection.
    public func isExcludedAppFromNonAXProbe(bundleIdentifier: String?) -> Bool {
        guard let bundleId = bundleIdentifier?.lowercased() else { return false }
        let excluded = [
            "com.apple.finder",
            "com.apple.dock",
            "com.apple.systemuiserver",
            "com.apple.controlcenter",
            "com.apple.notificationcenterui",
            "com.apple.spotlight"
        ]
        return excluded.contains(bundleId)
    }

    /// Returns true if the pasteboard types represent a filesystem file, folder, or application item.
    public func isFilePasteboardTypes(_ types: [NSPasteboard.PasteboardType]) -> Bool {
        return types.contains {
            $0 == .fileURL ||
            $0.rawValue == "public.file-url" ||
            $0.rawValue == "NSFilenamesPboardType" ||
            $0.rawValue.contains("file-url") ||
            $0.rawValue.contains("finder")
        }
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
            mouseDownAppPID = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
            isDragging = false
            lastClickCount = event.clickCount

            // Dismiss active bubble immediately if mouse is pressed down anywhere outside the bubble
            let mouseLoc = NSEvent.mouseLocation
            if SelectionBubblePanel.shared.isVisible && !SelectionBubblePanel.shared.frame.insetBy(dx: -4, dy: -4).contains(mouseLoc) {
                onSelectionCleared?()
            }

        case .leftMouseDragged:
            let current = NSEvent.mouseLocation
            let dist = hypot(current.x - mouseDownLocation.x, current.y - mouseDownLocation.y)
            if dist > 7.0 {
                isDragging = true
            }

        case .leftMouseUp:
            let mouseLoc = NSEvent.mouseLocation
            let dist = hypot(mouseLoc.x - mouseDownLocation.x, mouseLoc.y - mouseDownLocation.y)
            let clickCount = max(event.clickCount, lastClickCount)
            let isMultiClick = clickCount >= 2
            let isDrag = isDragging || dist > 7.0
            let isShiftClick = event.modifierFlags.contains(.shift)
            let currentFrontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
            let switchedAppsDuringClick = (mouseDownAppPID != 0 && currentFrontPID != 0 && mouseDownAppPID != currentFrontPID)
            isDragging = false

            if isDrag || (isMultiClick && !switchedAppsDuringClick) || isShiftClick {
                scheduleSelectionCheck(isDrag: isDrag, clickCount: clickCount)
            } else {
                // User single-clicked (which deselects text in macOS apps)
                if !SelectionBubblePanel.shared.frame.insetBy(dx: -4, dy: -4).contains(mouseLoc) {
                    onSelectionCleared?()
                }
            }

        default:
            break
        }
    }

    private func scheduleSelectionCheck(isDrag: Bool = false, clickCount: Int = 1) {
        pendingWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.checkSelectedText(isDrag: isDrag, clickCount: clickCount)
        }
        pendingWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: workItem)
    }

    public func checkSelectedText(isDrag: Bool = false, clickCount: Int = 1) {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }

        // Don't trigger for monkey-tools's own windows
        if frontApp.bundleIdentifier == Bundle.main.bundleIdentifier {
            return
        }

        // Respect user's excluded apps list (e.g. password managers)
        if let bundleId = frontApp.bundleIdentifier,
           AppSettings.shared.excludedAppBundleIDs.contains(bundleId) {
            return
        }

        let pid = frontApp.processIdentifier
        let mouseLoc = NSEvent.mouseLocation

        // Guard against clicks on non-text UI chrome (buttons, tabs, toolbars, titlebars, images, scrollbars, empty window frames)
        // or outside the active app's focused window
        if !isDrag && isClickOnNonTextElement(pid: pid, mouseLoc: mouseLoc) {
            onSelectionCleared?()
            return
        }

        // Method 1: Try Accessibility API first (fast for native text fields like TextEdit, Mail, Xcode, Notes)
        if let axText = queryAXSelectedText(pid: pid),
           isValidSelectionForTrigger(axText.text, isDrag: isDrag, clickCount: clickCount) {
            // Reject stale selections far away from the click location
            if axText.hasExactBounds && !isPoint(mouseLoc, nearSelectionRect: axText.bounds) {
                onSelectionCleared?()
                return
            }
            let editable = isElementEditable(pid: pid, mouseLoc: mouseLoc)
            let event = TextSelectionEvent(text: axText.text, screenRect: axText.bounds, sourceAppPID: pid, isEditable: editable)
            onSelectionDetected?(event)
            return
        }

        // Exclude system shells / file managers (e.g. Finder/Desktop) from blind Cmd+C probe.
        // On the Desktop or in Finder, selecting icons copies file objects rather than selecting text.
        if isExcludedAppFromNonAXProbe(bundleIdentifier: frontApp.bundleIdentifier) {
            return
        }

        // Method 2: For browsers (Safari, Chrome) and other non-AX apps:
        // Stealth probe to verify translatable text exists without modifying clipboard or polluting history
        probeNonAXSelection(pid: pid, mouseLoc: mouseLoc, isDrag: isDrag, clickCount: clickCount)
    }

    public func triggerImmediateTranslation() {
        if TranslationPopoverPanel.shared.isVisible {
            TranslationPopoverPanel.shared.hide()
            return
        }

        SelectionBubblePanel.shared.hide()

        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              frontApp.bundleIdentifier != Bundle.main.bundleIdentifier else {
            TranslationPopoverPanel.shared.show(text: "", near: NSEvent.mouseLocation)
            return
        }

        let pid = frontApp.processIdentifier
        let mouseLoc = NSEvent.mouseLocation

        // Method 1: Fast AX check
        if let axText = queryAXSelectedText(pid: pid), isValidTranslatableText(axText.text) {
            let editable = isElementEditable(pid: pid, mouseLoc: mouseLoc)
            let point = CGPoint(x: axText.bounds.midX, y: axText.bounds.minY)
            TranslationPopoverPanel.shared.show(text: axText.text, near: point, sourceAppPID: pid, isEditable: editable)
            return
        }

        // Method 2: System shells / Finder excluded from blind copy probe
        if isExcludedAppFromNonAXProbe(bundleIdentifier: frontApp.bundleIdentifier) {
            TranslationPopoverPanel.shared.show(text: "", near: mouseLoc, sourceAppPID: pid, isEditable: false)
            return
        }

        // Method 3: Probe directly to popover
        probeNonAXSelection(pid: pid, mouseLoc: mouseLoc, isDrag: true, clickCount: 1, directToPopover: true)
    }

    private func probeNonAXSelection(pid: pid_t, mouseLoc: CGPoint, isDrag: Bool, clickCount: Int, directToPopover: Bool = false) {
        guard !isProbeInProgress else { return }
        isProbeInProgress = true

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

        // 2. Suppress clipboard monitor capture so monkey-tools never records this probe
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
            isProbeInProgress = false
            if directToPopover {
                TranslationPopoverPanel.shared.show(text: "", near: mouseLoc, sourceAppPID: pid, isEditable: false)
            }
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cgSessionEventTap)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            keyUp.post(tap: .cgSessionEventTap)
        }

        // Helper to restore clipboard backup ONLY when the probe actually mutated the pasteboard
        let restoreBackup = { (didMutateClipboard: Bool) in
            if didMutateClipboard {
                pasteboard.clearContents()
                for backup in backupItems {
                    let item = NSPasteboardItem()
                    for (type, data) in backup.data {
                        item.setData(data, forType: type)
                    }
                    pasteboard.writeObjects([item])
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                ClipboardMonitor.shared.lastChangeCount = pasteboard.changeCount
                ClipboardMonitor.shared.isCapturingSuppressed = false
            }
        }

        // 4. Condition-based polling:
        var attempts = 0
        let maxAttempts = 16
        var checkTimer: Timer?

        let cleanup = { [weak self] in
            checkTimer?.invalidate()
            checkTimer = nil
            self?.isProbeInProgress = false
        }

        checkTimer = Timer.scheduledTimer(withTimeInterval: 0.015, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                ClipboardMonitor.shared.isCapturingSuppressed = false
                return
            }

            attempts += 1
            let currentChangeCount = pasteboard.changeCount

            if currentChangeCount != oldChangeCount {
                timer.invalidate()
                let capturedText = pasteboard.string(forType: .string) ?? ""
                let types = pasteboard.types ?? []
                let isImageType = types.contains {
                    $0 == .tiff || $0 == .png || $0.rawValue.contains("image")
                }
                let isFileType = self.isFilePasteboardTypes(types)

                restoreBackup(true)
                cleanup()

                // If file/folder item (e.g. from Desktop or file manager) -> dismiss or show empty
                if isFileType {
                    if directToPopover {
                        TranslationPopoverPanel.shared.show(text: "", near: mouseLoc, sourceAppPID: pid, isEditable: false)
                    } else {
                        self.onSelectionCleared?()
                    }
                    return
                }

                // If image without translatable text -> dismiss or show empty
                if isImageType && !self.isValidTranslatableText(capturedText) {
                    if directToPopover {
                        TranslationPopoverPanel.shared.show(text: "", near: mouseLoc, sourceAppPID: pid, isEditable: false)
                    } else {
                        self.onSelectionCleared?()
                    }
                    return
                }

                // Validate captured text against gesture (rejects whitespace, pure numbers, and multi-line false positives on double-click)
                let isValidText = directToPopover
                    ? self.isValidTranslatableText(capturedText)
                    : self.isValidSelectionForTrigger(capturedText, isDrag: isDrag, clickCount: clickCount)
                if !isValidText {
                    if directToPopover {
                        TranslationPopoverPanel.shared.show(text: "", near: mouseLoc, sourceAppPID: pid, isEditable: false)
                    } else {
                        self.onSelectionCleared?()
                    }
                    return
                }

                // Valid translatable text!
                let editable = self.isElementEditable(pid: pid, mouseLoc: mouseLoc)
                if directToPopover {
                    TranslationPopoverPanel.shared.show(text: capturedText, near: mouseLoc, sourceAppPID: pid, isEditable: editable)
                } else {
                    let rect = CGRect(x: mouseLoc.x, y: mouseLoc.y, width: 1, height: 1)
                    let event = TextSelectionEvent(text: capturedText, screenRect: rect, sourceAppPID: pid, isEditable: editable)
                    self.onSelectionDetected?(event)
                }
                return
            }

            if attempts >= maxAttempts {
                timer.invalidate()
                // Clipboard never changed -> do NOT clear/rewrite user's existing pasteboard!
                restoreBackup(false)
                cleanup()
                if directToPopover {
                    TranslationPopoverPanel.shared.show(text: "", near: mouseLoc, sourceAppPID: pid, isEditable: false)
                } else {
                    self.onSelectionCleared?()
                }
            }
        }
        RunLoop.main.add(checkTimer!, forMode: .common)
    }

    /// Inspects the AX element directly beneath `mouseLoc` to prevent double-clicking on empty window areas,
    /// titlebars, buttons, tabs, toolbars, scrollbars, images, or outside the focused window from triggering translation.
    private func isClickOnNonTextElement(pid: pid_t, mouseLoc: CGPoint) -> Bool {
        guard pid > 0 else { return false }
        let appElement = AXUIElementCreateApplication(pid)

        // Check if mouseLoc is outside the app's focused window frame
        var focusedWindowObj: AnyObject?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindowObj) == .success,
           let winObj = focusedWindowObj {
            let winEl = winObj as! AXUIElement
            var posObj: AnyObject?
            var sizeObj: AnyObject?
            if AXUIElementCopyAttributeValue(winEl, kAXPositionAttribute as CFString, &posObj) == .success,
               AXUIElementCopyAttributeValue(winEl, kAXSizeAttribute as CFString, &sizeObj) == .success,
               let posVal = posObj, let sizeVal = sizeObj {
                var axOrigin = CGPoint.zero
                var axSize = CGSize.zero
                if AXValueGetValue(posVal as! AXValue, .cgPoint, &axOrigin),
                   AXValueGetValue(sizeVal as! AXValue, .cgSize, &axSize),
                   axSize.width > 0 && axSize.height > 0,
                   let primaryScreen = NSScreen.screens.first {
                    let cocoaY = primaryScreen.frame.height - (axOrigin.y + axSize.height)
                    let winRect = CGRect(x: axOrigin.x, y: cocoaY, width: axSize.width, height: axSize.height)
                    if !winRect.contains(mouseLoc) {
                        return true
                    }
                }
            }
        }

        // Check the specific AX element under the cursor
        let screenHeight = NSScreen.screens.first?.frame.height ?? 1080
        let axPoint = CGPoint(x: mouseLoc.x, y: screenHeight - mouseLoc.y)
        var elementAtPos: AXUIElement?
        guard AXUIElementCopyElementAtPosition(appElement, Float(axPoint.x), Float(axPoint.y), &elementAtPos) == .success,
              let el = elementAtPos else {
            return false
        }

        var roleObj: AnyObject?
        AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &roleObj)
        let role = (roleObj as? String) ?? ""

        var subroleObj: AnyObject?
        AXUIElementCopyAttributeValue(el, kAXSubroleAttribute as CFString, &subroleObj)
        let subrole = (subroleObj as? String) ?? ""

        if isNonTextUIRole(role, subrole: subrole) {
            return true
        }

        // If the element is an empty scroll area or group with no text value and no selected text on a double-click, check parent toolbar/tabbar
        var current = el
        for _ in 0..<2 {
            var parentObj: AnyObject?
            if AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parentObj) == .success,
               let parent = parentObj {
                let parentEl = parent as! AXUIElement
                var pRoleObj: AnyObject?
                AXUIElementCopyAttributeValue(parentEl, kAXRoleAttribute as CFString, &pRoleObj)
                let pRole = (pRoleObj as? String) ?? ""
                if pRole == "AXToolbar" || pRole == "AXTabGroup" || pRole == "AXMenuBar" || pRole == "AXTitleBar" {
                    return true
                }
                current = parentEl
            } else {
                break
            }
        }

        return false
    }

    private func queryAXSelectedText(pid: pid_t) -> (text: String, bounds: CGRect, hasExactBounds: Bool)? {
        let appElement = AXUIElementCreateApplication(pid)

        var focusedElementObj: AnyObject?
        let focusedResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElementObj)
        guard focusedResult == .success, let focusedElement = focusedElementObj else {
            return nil
        }
        let element = focusedElement as! AXUIElement

        var selectedTextObj: AnyObject?
        let textResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedTextObj)
        guard textResult == .success,
              let text = selectedTextObj as? String,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let (bounds, hasExactBounds) = getSelectionBounds(element: element)
        return (text, bounds, hasExactBounds)
    }

    private func getSelectionBounds(element: AXUIElement) -> (rect: CGRect, hasExactBounds: Bool) {
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
                    // Convert AX coordinate (top-left origin of primary screen) to Cocoa screen coordinate (bottom-left origin)
                    if let primaryScreen = NSScreen.screens.first {
                        let screenHeight = primaryScreen.frame.height
                        rect.origin.y = screenHeight - (rect.origin.y + rect.height)
                    }
                    return (rect, true)
                }
            }
        }

        // Fallback: mouse cursor position
        let mouseLoc = NSEvent.mouseLocation
        return (CGRect(x: mouseLoc.x, y: mouseLoc.y, width: 20, height: 20), false)
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
