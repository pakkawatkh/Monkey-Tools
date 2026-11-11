import AppKit

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusMenuController: StatusMenuController?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent duplicate instances
        let bundleId = Bundle.main.bundleIdentifier ?? "com.local.monkey-tools"
        let instances = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
        if instances.count > 1 {
            print("[monkey-tools] Another instance is already running. Exiting duplicate.")
            NSApp.terminate(nil)
            return
        }

        // Run as accessory app (Menu bar only, hidden from Dock)
        NSApp.setActivationPolicy(.accessory)
        setupStandardEditMenu()

        // Initialize status menu item in menu bar
        statusMenuController = StatusMenuController()

        // Start clipboard change observer
        ClipboardMonitor.shared.startMonitoring()

        // Setup global hotkey (from AppSettings, default: Command + Shift + V)
        HotKeyManager.shared.onHotKeyPressed = {
            ClipboardPanel.shared.toggleVisibility()
        }
        HotKeyManager.shared.registerSavedHotKey()

        // Setup global quick translate hotkey (default: Command + Shift + E)
        HotKeyManager.shared.onTranslateHotKeyPressed = {
            TextSelectionMonitor.shared.triggerImmediateTranslation()
        }
        HotKeyManager.shared.registerSavedTranslateHotKey()

        // Start text selection translator monitor
        TextSelectionMonitor.shared.onSelectionDetected = { event in
            SelectionBubblePanel.shared.show(at: event.screenRect, selectedText: event.text, sourceAppPID: event.sourceAppPID, isEditable: event.isEditable)
        }
        TextSelectionMonitor.shared.onSelectionCleared = {
            SelectionBubblePanel.shared.hide()
        }
        if AppSettings.shared.selectionTranslateEnabled {
            TextSelectionMonitor.shared.startMonitoring()
        }

        // Check for updates once per 24 hours in background
        UpdateCheckService.shared.checkForUpdates(force: false)

        print("[monkey-tools] Application started successfully. Press your shortcut to show clipboard.")
    }

    public func applicationWillTerminate(_ notification: Notification) {
        ClipboardMonitor.shared.stopMonitoring()
        TextSelectionMonitor.shared.stopMonitoring()
        HotKeyManager.shared.unregisterAll()
    }

    private func setupStandardEditMenu() {
        let mainMenu = NSMenu()
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        NSApp.mainMenu = mainMenu
    }
}
