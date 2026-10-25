import AppKit
import SwiftUI

public final class TranslationPopoverPanel: NSPanel {
    public static let shared = TranslationPopoverPanel()

    private var globalClickMonitor: Any?

    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 310, height: 230),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.appearance = NSAppearance(named: .darkAqua)
        self.hidesOnDeactivate = false
    }

    public func show(text: String, near screenPoint: CGPoint) {
        let popoverView = TranslationPopoverView(
            originalText: text,
            onClose: { [weak self] in
                self?.hide()
            },
            onReplace: { [weak self] translated in
                self?.hide()
                // Use AutoPaster to paste translated text into active window
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    AutoPaster.shared.pasteEmoji(translated)
                }
            }
        )

        let hosting = NSHostingView(rootView: popoverView)
        hosting.wantsLayer = true
        hosting.layer?.cornerRadius = 12
        hosting.layer?.masksToBounds = true
        self.contentView = hosting

        // Position popover near the trigger point
        var targetX = screenPoint.x
        var targetY = screenPoint.y - 230

        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            if targetX + 310 > visible.maxX {
                targetX = visible.maxX - 314
            }
            if targetX < visible.minX {
                targetX = visible.minX + 4
            }
            if targetY < visible.minY {
                targetY = screenPoint.y + 36
            }
        }

        self.setFrameOrigin(NSPoint(x: targetX, y: targetY))
        self.alphaValue = 0.0
        self.orderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            self.animator().alphaValue = 1.0
        }

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
