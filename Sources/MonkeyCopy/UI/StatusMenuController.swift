import AppKit

public final class StatusMenuController: NSObject {
    private var statusItem: NSStatusItem?

    public override init() {
        super.init()
        setupStatusItem()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else { return }

        // Set monkey template icon for macOS Menu Bar
        let monkeyIcon = createMonkeyTemplateIcon()
        button.image = monkeyIcon
        button.imagePosition = .imageOnly
        button.toolTip = "monkey-copy (คลิกเพื่อเปิดการตั้งค่า / Settings)"

        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func createMonkeyTemplateIcon() -> NSImage {
        let size: CGFloat = 18
        let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            let s = rect.width
            let cx = s * 0.5
            let cy = s * 0.5

            // Ears
            let earRadius = s * 0.20
            let leftEarCenter = CGPoint(x: s * 0.17, y: s * 0.52)
            let rightEarCenter = CGPoint(x: s * 0.83, y: s * 0.52)

            ctx.setFillColor(NSColor.black.cgColor)
            ctx.addArc(center: leftEarCenter, radius: earRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
            ctx.fillPath()
            ctx.addArc(center: rightEarCenter, radius: earRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
            ctx.fillPath()

            // Head
            let headW = s * 0.68
            let headH = s * 0.62
            let headRect = CGRect(x: cx - headW/2, y: cy - headH/2, width: headW, height: headH)
            ctx.addEllipse(in: headRect)
            ctx.fillPath()

            // Cutout face mask (so eyes/muzzle show crisp template background)
            ctx.setBlendMode(.clear)
            let eyeLobeR = s * 0.16
            ctx.addArc(center: CGPoint(x: s * 0.40, y: s * 0.58), radius: eyeLobeR, startAngle: 0, endAngle: .pi * 2, clockwise: false)
            ctx.fillPath()
            ctx.addArc(center: CGPoint(x: s * 0.60, y: s * 0.58), radius: eyeLobeR, startAngle: 0, endAngle: .pi * 2, clockwise: false)
            ctx.fillPath()

            let muzzleRect = CGRect(x: s * 0.26, y: s * 0.28, width: s * 0.48, height: s * 0.36)
            ctx.addEllipse(in: muzzleRect)
            ctx.fillPath()

            // Draw facial features
            ctx.setBlendMode(.normal)
            ctx.setFillColor(NSColor.black.cgColor)

            // Eyes
            let eyeR = s * 0.045
            ctx.addArc(center: CGPoint(x: s * 0.41, y: s * 0.58), radius: eyeR, startAngle: 0, endAngle: .pi * 2, clockwise: false)
            ctx.fillPath()
            ctx.addArc(center: CGPoint(x: s * 0.59, y: s * 0.58), radius: eyeR, startAngle: 0, endAngle: .pi * 2, clockwise: false)
            ctx.fillPath()

            // Nose
            let noseRect = CGRect(x: s * 0.46, y: s * 0.45, width: s * 0.08, height: s * 0.05)
            ctx.addEllipse(in: noseRect)
            ctx.fillPath()

            // Smile
            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setLineWidth(s * 0.05)
            ctx.setLineCap(.round)
            ctx.beginPath()
            ctx.addArc(center: CGPoint(x: cx, y: s * 0.40), radius: s * 0.09, startAngle: .pi * 1.2, endAngle: .pi * 1.8, clockwise: false)
            ctx.strokePath()

            return true
        }
        img.isTemplate = true
        return img
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        // If right click or holding Control, show menu
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showMenu()
        } else {
            // Normal left click opens the app settings / config directly
            SettingsWindowController.shared.toggleSettings()
        }
    }

    public func showMenu() {
        let menu = NSMenu()
        let loc = LocalizationManager.shared

        let shortcutDisplay = AppSettings.shared.hotkeyDisplayString
        let showItem = NSMenuItem(title: "\(loc["menu_show_monkey"]) (\(shortcutDisplay))", action: #selector(togglePanel), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)

        menu.addItem(NSMenuItem.separator())

        let count = ClipboardManager.shared.items.count
        let countItem = NSMenuItem(title: "\(loc["menu_history_count"]) \(count) \(loc["items_count"])", action: nil, keyEquivalent: "")
        countItem.isEnabled = false
        menu.addItem(countItem)

        let clearUnpinned = NSMenuItem(title: loc["menu_clear_unpinned"], action: #selector(clearUnpinnedHistory), keyEquivalent: "")
        clearUnpinned.target = self
        menu.addItem(clearUnpinned)

        let clearAll = NSMenuItem(title: loc["menu_clear_all"], action: #selector(clearAllHistory), keyEquivalent: "")
        clearAll.target = self
        menu.addItem(clearAll)

        menu.addItem(NSMenuItem.separator())

        let accessStatus = AutoPaster.shared.isAccessibilityGranted ? loc["menu_access_granted"] : loc["menu_access_enable"]
        let accessItem = NSMenuItem(title: accessStatus, action: #selector(openAccessibilitySettings), keyEquivalent: "")
        accessItem.target = self
        menu.addItem(accessItem)

        let settingsItem = NSMenuItem(title: loc["menu_settings_item"], action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: loc["menu_quit_item"], action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        // Reset menu so left-click continues to toggle
        statusItem?.menu = nil
    }

    @objc private func togglePanel() {
        ClipboardPanel.shared.toggleVisibility()
    }

    @objc private func clearUnpinnedHistory() {
        ClipboardManager.shared.clearAll(includingPinned: false)
    }

    @objc private func clearAllHistory() {
        ClipboardManager.shared.clearAll(includingPinned: true)
    }

    @objc private func openAccessibilitySettings() {
        AutoPaster.shared.openAccessibilitySettings()
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.showSettings()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
