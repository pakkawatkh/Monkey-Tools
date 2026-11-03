import AppKit
import SwiftUI

public final class TranslationPopoverPanel: NSPanel, NSWindowDelegate {
    public static let shared = TranslationPopoverPanel()

    private var globalClickMonitor: Any?
    private var currentSize: CGSize

    public init() {
        let savedW = UserDefaults.standard.double(forKey: "translation_popover_width")
        let savedH = UserDefaults.standard.double(forKey: "translation_popover_height")
        let initialWidth = savedW >= 300 ? CGFloat(savedW) : 345
        let initialHeight = savedH >= 200 ? CGFloat(savedH) : 250
        self.currentSize = CGSize(width: initialWidth, height: initialHeight)

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: initialWidth, height: initialHeight),
            styleMask: [.titled, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.minSize = NSSize(width: 300, height: 200)
        self.maxSize = NSSize(width: 800, height: 650)
        self.level = .statusBar
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = true
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.appearance = NSAppearance(named: .darkAqua)
        self.hidesOnDeactivate = false
        self.delegate = self

        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true
    }

    public func windowDidResize(_ notification: Notification) {
        saveCurrentSize()
    }

    public func saveCurrentSize() {
        currentSize = self.frame.size
        UserDefaults.standard.set(currentSize.width, forKey: "translation_popover_width")
        UserDefaults.standard.set(currentSize.height, forKey: "translation_popover_height")
    }

    public override var canBecomeKey: Bool {
        return true
    }

    public override var canBecomeMain: Bool {
        return true
    }

    public func show(text: String, near screenPoint: CGPoint, sourceAppPID: pid_t = 0, isEditable: Bool = false) {
        let popoverView = TranslationPopoverView(
            originalText: text,
            isEditable: isEditable,
            onClose: { [weak self] in
                self?.hide()
            },
            onReplace: { [weak self] translated in
                self?.hide()
                AutoPaster.shared.replaceOriginalText(with: translated, inAppWithPID: sourceAppPID)
            }
        )

        let hosting = NSHostingView(rootView: popoverView)
        hosting.wantsLayer = true
        hosting.layer?.cornerRadius = 12
        hosting.layer?.masksToBounds = true
        self.contentView = hosting
        self.invalidateShadow()

        // Position popover near the trigger point using remembered or default size
        let popoverWidth = max(300, currentSize.width)
        let popoverHeight = max(200, currentSize.height)
        var targetX = screenPoint.x
        var targetY = screenPoint.y - popoverHeight

        let screen = NSScreen.screens.first { $0.frame.contains(screenPoint) }
                  ?? NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
                  ?? NSScreen.main
                  ?? NSScreen.screens.first

        if let screen = screen {
            let visible = screen.visibleFrame
            if targetX + popoverWidth > visible.maxX {
                targetX = visible.maxX - (popoverWidth + 4)
            }
            if targetX < visible.minX {
                targetX = visible.minX + 4
            }
            if targetY < visible.minY {
                targetY = screenPoint.y + 36
            }
        }

        self.setFrame(NSRect(x: targetX, y: targetY, width: popoverWidth, height: popoverHeight), display: true)
        self.alphaValue = 1.0
        self.orderFrontRegardless()
        self.makeKey()

        startClickMonitoring()
    }

    public func hide() {
        stopClickMonitoring()
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            self.animator().alphaValue = 0.0
        }, completionHandler: {
            self.orderOut(nil)
        })
    }

    public override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Esc
            hide()
            return
        }
        super.keyDown(with: event)
    }

    private func startClickMonitoring() {
        stopClickMonitoring()
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, self.isVisible else { return }
            let mouseLocation = NSEvent.mouseLocation
            if !self.frame.contains(mouseLocation) {
                DispatchQueue.main.async {
                    self.hide()
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
}
