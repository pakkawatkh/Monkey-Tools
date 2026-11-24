import AppKit
import SwiftUI

public final class ClipboardPanel: NSPanel {
    public static let shared = ClipboardPanel()

    private var hostingView: NSHostingView<ClipboardView>?

    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 540),
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
        hosting.layer?.cornerRadius = 18
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

    public override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            if handlePanelKeyDown(event) {
                return
            }
        }
        super.sendEvent(event)
    }

    public override func keyDown(with event: NSEvent) {
        if handlePanelKeyDown(event) {
            return
        }
        super.keyDown(with: event)
    }

    private func handlePanelKeyDown(_ event: NSEvent) -> Bool {
        // Esc key closes preview first, or closes panel
        if event.keyCode == 53 {
            if ClipboardManager.shared.previewItem != nil {
                ClipboardManager.shared.previewItem = nil
                return true
            }
            closePanel()
            return true
        }

        // Return / Enter key (36 = Return, 76 = Numpad Enter)
        if event.keyCode == 36 || event.keyCode == 76 {
            if ClipboardManager.shared.activeTab == .clipboard {
                if let preview = ClipboardManager.shared.previewItem {
                    ClipboardManager.shared.previewItem = nil
                    pasteAndClose(item: preview)
                    return true
                }
                if let selected = ClipboardManager.shared.selectedItem {
                    pasteAndClose(item: selected)
                    return true
                }
            } else {
                if let first = EmojiManager.shared.filteredEmojis.first {
                    EmojiManager.shared.useEmoji(first)
                    AutoPaster.shared.pasteEmoji(first)
                    closePanel()
                    return true
                }
            }
            return true
        }

        // Up arrow (126)
        if event.keyCode == 126 {
            if ClipboardManager.shared.activeTab == .clipboard && ClipboardManager.shared.previewItem == nil {
                ClipboardManager.shared.selectPrevious()
                return true
            }
        }

        // Down arrow (125)
        if event.keyCode == 125 {
            if ClipboardManager.shared.activeTab == .clipboard && ClipboardManager.shared.previewItem == nil {
                ClipboardManager.shared.selectNext()
                return true
            }
        }

        // Cmd shortcuts in Clipboard tab
        if event.modifierFlags.contains(.command) && ClipboardManager.shared.activeTab == .clipboard {
            // Cmd + P: Toggle Pin on selected item
            if event.keyCode == 35, let selected = ClipboardManager.shared.selectedItem {
                ClipboardManager.shared.togglePin(for: selected)
                return true
            }

            // Cmd + Backspace (51): Delete selected item
            if event.keyCode == 51, let selected = ClipboardManager.shared.selectedItem {
                ClipboardManager.shared.delete(item: selected)
                return true
            }

            // Cmd + Y (16): Toggle Quick Preview on selected item
            if event.keyCode == 16 {
                if ClipboardManager.shared.previewItem != nil {
                    ClipboardManager.shared.previewItem = nil
                } else if let selected = ClipboardManager.shared.selectedItem {
                    ClipboardManager.shared.previewItem = selected
                }
                return true
            }

            // Cmd + T (17): Translate selected text item immediately
            if event.keyCode == 17,
               let selected = ClipboardManager.shared.selectedItem,
               selected.type == .text,
               let text = selected.text,
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                closePanel()
                DispatchQueue.main.async {
                    TranslationPopoverPanel.shared.show(text: text, near: NSEvent.mouseLocation, sourceAppPID: 0, isEditable: false)
                }
                return true
            }

            // Cmd + 1..9 quick paste
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
                    return true
                }
            }
        }

        return false
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

        // Reset search query, selection, preview, and tab
        ClipboardManager.shared.searchQuery = ""
        ClipboardManager.shared.selectedIndex = 0
        ClipboardManager.shared.previewItem = nil
        ClipboardManager.shared.activeTab = .clipboard
        EmojiManager.shared.searchQuery = ""

        self.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        startClickMonitoring()
    }

    public func closePanel() {
        stopClickMonitoring()
        ClipboardManager.shared.previewItem = nil
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

        let panelWidth: CGFloat = 340
        let panelHeight: CGFloat = 540
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
