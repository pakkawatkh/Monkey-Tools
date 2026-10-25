import AppKit

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusMenuController: StatusMenuController?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent duplicate instances
        let bundleId = Bundle.main.bundleIdentifier ?? "com.local.monkey-copy"
        let instances = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
        if instances.count > 1 {
            print("[monkey-copy] Another instance is already running. Exiting duplicate.")
            NSApp.terminate(nil)
            return
        }

        // Run as accessory app (Menu bar only, hidden from Dock)
        NSApp.setActivationPolicy(.accessory)

        // Initialize status menu item in menu bar
        statusMenuController = StatusMenuController()

        // Start clipboard change observer
        ClipboardMonitor.shared.startMonitoring()

        // Setup global hotkey (from AppSettings, default: Command + Shift + V)
        HotKeyManager.shared.onHotKeyPressed = {
            ClipboardPanel.shared.toggleVisibility()
        }
        HotKeyManager.shared.registerSavedHotKey()

        // Start text selection translator monitor
        TextSelectionMonitor.shared.onSelectionDetected = { event in
            SelectionBubblePanel.shared.show(at: event.screenRect, selectedText: event.text, isEditable: event.isEditable)
        }
        TextSelectionMonitor.shared.onSelectionCleared = {
            SelectionBubblePanel.shared.hide()
        }
        if AppSettings.shared.selectionTranslateEnabled {
            TextSelectionMonitor.shared.startMonitoring()
        }

        print("[monkey-copy] Application started successfully. Press your shortcut to show clipboard.")
    }

    public func applicationWillTerminate(_ notification: Notification) {
        ClipboardMonitor.shared.stopMonitoring()
        TextSelectionMonitor.shared.stopMonitoring()
        HotKeyManager.shared.unregisterHotKey()
    }
}
