import AppKit
import ApplicationServices
import Combine

public final class AutoPaster: ObservableObject {
    public static let shared = AutoPaster()

    @Published public private(set) var isAccessibilityGranted: Bool = AXIsProcessTrusted()

    private var previousApp: NSRunningApplication?
    private var workspaceObserver: Any?
    private var isPasting = false

    public init() {
        // Track the active application automatically whenever the user switches apps
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            if app.bundleIdentifier != Bundle.main.bundleIdentifier {
                self?.previousApp = app
            }
        }

        // Initialize with currently active external application
        recordFrontmostApplication()
        refreshAccessibilityStatus()
    }

    /// Refresh the accessibility status directly from the system
    public func refreshAccessibilityStatus() {
        let current = AXIsProcessTrusted()
        if isAccessibilityGranted != current {
            DispatchQueue.main.async {
                self.isAccessibilityGranted = current
            }
        }
    }

    /// Remember the currently frontmost application before showing the clipboard panel
    public func recordFrontmostApplication() {
        if let front = NSWorkspace.shared.frontmostApplication,
           front.bundleIdentifier != Bundle.main.bundleIdentifier {
            self.previousApp = front
        }
    }

    /// Request Accessibility permission from macOS System Settings with prompt dialog
    public func promptForAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refreshAccessibilityStatus()
    }

    /// Open System Settings directly to Privacy & Security -> Accessibility
    public func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Paste the selected item (Text or Image):
    /// 1. Copy to NSPasteboard.general
    /// 2. Reactivate the target app
    /// 3. Synthesize a single Cmd + V keystroke into the target app
    public func paste(item: ClipboardItem, completion: (() -> Void)? = nil) {
        // Prevent accidental rapid multiple trigger
        guard !isPasting else { return }
        isPasting = true

        let pasteboard = NSPasteboard.general

        switch item.type {
        case .text:
            if let text = item.text {
                ClipboardMonitor.shared.markProgrammaticWrite(text: text)
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
            }
        case .image:
            ClipboardMonitor.shared.markProgrammaticImageWrite()
            pasteboard.clearContents()
            if let pngData = item.loadImageData() {
                pasteboard.setData(pngData, forType: .png)
                if let nsImage = item.loadImage(), let tiffData = nsImage.tiffRepresentation {
                    pasteboard.setData(tiffData, forType: .tiff)
                }
            }
        }

        guard AppSettings.shared.autoPasteEnabled else {
            self.isPasting = false
            completion?()
            return
        }

        // 2. Reactivate the previously active application
        let targetApp = previousApp
        targetApp?.activate(options: .activateIgnoringOtherApps)

        // 3. Give 180ms for window manager to restore active key window, then send single Cmd+V
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            guard let self = self else { return }

            self.simulateCmdV()
            self.refreshAccessibilityStatus()

            // Release paste lock after a short window
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                self.isPasting = false
            }

            completion?()
        }
    }

    /// Paste an emoji directly without closing the floating window so the user can keep clicking
    public func pasteEmoji(_ emoji: String) {
        let pasteboard = NSPasteboard.general
        ClipboardMonitor.shared.markProgrammaticWrite(text: emoji)
        pasteboard.clearContents()
        pasteboard.setString(emoji, forType: .string)

        guard AppSettings.shared.autoPasteEnabled else { return }

        // Reactivate the target application
        let targetApp = previousApp
        targetApp?.activate(options: .activateIgnoringOtherApps)

        // Snappy 80ms delay for continuous typing, then send Cmd+V
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            guard let self = self else { return }
            self.simulateCmdV()
        }
    }

    /// Replaces the currently selected original text in the target application with the translated text.
    /// Uses native Accessibility attribute replacement first if possible; otherwise reactivates the app and pastes via Cmd + V.
    public func replaceOriginalText(with newText: String, inAppWithPID pid: pid_t) {
        let pasteboard = NSPasteboard.general
        ClipboardMonitor.shared.markProgrammaticWrite(text: newText)
        pasteboard.clearContents()
        pasteboard.setString(newText, forType: .string)

        let targetApp = (pid > 0 ? NSRunningApplication(processIdentifier: pid) : nil) ?? previousApp

        // Attempt 1: Direct Accessibility Replacement
        // If the target element supports setting kAXSelectedTextAttribute (e.g. TextEdit, Notes, Mail, Xcode),
        // we can set the text directly and immediately!
        if pid > 0 {
            let appElement = AXUIElementCreateApplication(pid)
            var focusedObj: AnyObject?
            if AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedObj) == .success,
               let focused = focusedObj {
                let el = focused as! AXUIElement
                var isSelSettable: DarwinBoolean = false
                if AXUIElementIsAttributeSettable(el, kAXSelectedTextAttribute as CFString, &isSelSettable) == .success,
                   isSelSettable.boolValue {
                    let setRes = AXUIElementSetAttributeValue(el, kAXSelectedTextAttribute as CFString, newText as CFTypeRef)
                    if setRes == .success {
                        targetApp?.activate()
                        return
                    }
                }
            }
        }

        // Attempt 2: Reactivate the application and synthesize Cmd + V
        // Give 160ms for window manager to bring target window to front and restore first responder focus
        targetApp?.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { [weak self] in
            guard let self = self else { return }
            self.simulateCmdV()
        }
    }

    /// Synthesizes exactly ONE Command + V keystroke into the active session
    private func simulateCmdV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )

        let vKeyCode: CGKeyCode = 9 // ANSI V

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        // Post exactly once to the active session event tap
        keyDown.post(tap: .cgSessionEventTap)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            keyUp.post(tap: .cgSessionEventTap)
        }
    }
}
