import AppKit
import SwiftUI

public final class ClipboardPanel: NSPanel {
    public static let shared = ClipboardPanel()

    private var hostingView: NSHostingView<ClipboardView>?

    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 520),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = true
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.appearance = NSAppearance(named: .darkAqua)
        self.hidesOnDeactivate = false

        // Hide standard window title bar buttons
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true

        let rootView = ClipboardView(
            onSelect: { [weak self] item in
                self?.pasteAndClose(item: item)
            },
            onClose: { [weak self] in
                self?.closePanel()
            }
        )

        let hosting = NSHostingView(rootView: rootView)
        hosting.wantsLayer = true
        hosting.layer?.cornerRadius = 14
        hosting.layer?.masksToBounds = true
        self.contentView = hosting
        self.hostingView = hosting
        self.invalidateShadow()
    }

    public override var canBecomeKey: Bool {
        return true
    }

    public override var canBecomeMain: Bool {
        return true
    }

    private var globalClickMonitor: Any?

    private func startClickMonitoring() {
        stopClickMonitoring()
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, self.isVisible else { return }
            let mouseLocation = NSEvent.mouseLocation
            if !self.frame.contains(mouseLocation) {
                DispatchQueue.main.async {
                    self.closePanel()
                }
            }
        }
    }

    private func stopClickMonitoring() {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }

    public override func keyDown(with event: NSEvent) {
        // Esc key closes panel
        if event.keyCode == 53 {
            closePanel()
            return
        }

        // Return key pastes selected item
        if event.keyCode == 36 {
            if let selected = ClipboardManager.shared.selectedItem {
                pasteAndClose(item: selected)
            }
            return
        }

        // Up arrow
        if event.keyCode == 126 {
            ClipboardManager.shared.selectPrevious()
            return
        }

        // Down arrow
        if event.keyCode == 125 {
            ClipboardManager.shared.selectNext()
            return
        }

        // Cmd + 1..9 quick paste
        if event.modifierFlags.contains(.command) {
            let digitKeyCodes: [UInt16: Int] = [
                18: 0, // 1
                19: 1, // 2
                20: 2, // 3
                21: 3, // 4
                23: 4, // 5
                22: 5, // 6
                26: 6, // 7
                28: 7, // 8
                25: 8  // 9
            ]

            if let targetIndex = digitKeyCodes[event.keyCode] {
                let items = ClipboardManager.shared.filteredItems
                if targetIndex < items.count {
                    pasteAndClose(item: items[targetIndex])
                    return
                }
            }
        }

        super.keyDown(with: event)
    }

    public func toggleVisibility() {
        if isVisible {
            closePanel()
        } else {
            showPanel()
        }
    }

    public func showPanel() {
        // Refresh accessibility status live
        AutoPaster.shared.refreshAccessibilityStatus()

        // Record currently frontmost application before showing our window
        AutoPaster.shared.recordFrontmostApplication()

        // Position window near mouse cursor or centered on current screen
        positionAtMouseOrCenter()

        // Reset search query
        ClipboardManager.shared.searchQuery = ""
        ClipboardManager.shared.selectedIndex = 0
        EmojiManager.shared.searchQuery = ""

        self.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        startClickMonitoring()
    }

    public func closePanel() {
        stopClickMonitoring()
        self.orderOut(nil)
    }

    private func pasteAndClose(item: ClipboardItem) {
        closePanel()
        AutoPaster.shared.paste(item: item)
    }

    private func positionAtMouseOrCenter() {
        let mouseLocation = NSEvent.mouseLocation
        let screens = NSScreen.screens

        // Find which screen contains the mouse cursor
        guard let screen = screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) ?? NSScreen.main else {
            self.center()
            return
        }

        let panelWidth: CGFloat = 320
        let panelHeight: CGFloat = 520
        let visibleFrame = screen.visibleFrame

        // Center on screen or near mouse cursor with screen bounds protection
        var x = mouseLocation.x - (panelWidth / 2)
        var y = mouseLocation.y - (panelHeight / 2)

        // Ensure within visible screen bounds
        if x < visibleFrame.minX { x = visibleFrame.minX + 20 }
        if x + panelWidth > visibleFrame.maxX { x = visibleFrame.maxX - panelWidth - 20 }
        if y < visibleFrame.minY { y = visibleFrame.minY + 20 }
        if y + panelHeight > visibleFrame.maxY { y = visibleFrame.maxY - panelHeight - 20 }

        self.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
    }
}
