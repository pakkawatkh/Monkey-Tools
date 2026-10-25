import AppKit
import SwiftUI

public final class SelectionBubblePanel: NSPanel {
    public static let shared = SelectionBubblePanel()

    private var currentText: String = ""
    private var currentRect: CGRect = .zero
    private var autoDismissTimer: Timer?
    private var globalClickMonitor: Any?

    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 34, height: 34),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .statusBar
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.appearance = NSAppearance(named: .darkAqua)
        self.hidesOnDeactivate = false

        let bubbleView = SelectionBubbleView(
            onTap: { [weak self] in
                self?.handleBubbleTap()
            }
        )

        let hosting = NSHostingView(rootView: bubbleView)
        hosting.wantsLayer = true
        hosting.layer?.cornerRadius = 17
        hosting.layer?.masksToBounds = true
        self.contentView = hosting
    }

    public override var canBecomeKey: Bool {
        return false
    }

    public override var canBecomeMain: Bool {
        return false
    }

    public func show(at rect: CGRect, selectedText: String) {
        self.currentText = selectedText
        self.currentRect = rect

        // Position bubble near top-right of the selection rectangle
        var bubbleX = rect.maxX + 6
        var bubbleY = rect.maxY + 6

        // Prevent overflow beyond screen bounds
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            if bubbleX + 40 > screenFrame.maxX {
                bubbleX = rect.minX - 40
            }
            if bubbleY + 40 > screenFrame.maxY {
                bubbleY = rect.minY - 40
            }
            if bubbleX < screenFrame.minX {
                bubbleX = screenFrame.minX + 10
            }
            if bubbleY < screenFrame.minY {
                bubbleY = screenFrame.minY + 10
            }
        }

        self.setFrameOrigin(NSPoint(x: bubbleX, y: bubbleY))
        self.alphaValue = 1.0
        self.orderFrontRegardless()

        startClickMonitoring()

        // Auto-dismiss after 6 seconds if untouched
        autoDismissTimer?.invalidate()
        autoDismissTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: false) { [weak self] _ in
            self?.hide()
        }
    }

    public func hide() {
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil
        stopClickMonitoring()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            self.animator().alphaValue = 0.0
        }, completionHandler: {
            self.orderOut(nil)
        })
    }

    private func handleBubbleTap() {
        let text = self.currentText
        let targetPoint = CGPoint(x: self.frame.origin.x, y: self.frame.origin.y)
        self.hide()

        DispatchQueue.main.async {
            TranslationPopoverPanel.shared.show(text: text, near: targetPoint)
        }
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

public struct SelectionBubbleView: View {
    public let onTap: () -> Void
    @State private var isHovered = false

    public var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.12, green: 0.12, blue: 0.15).opacity(0.95))
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(isHovered ? 0.35 : 0.18), lineWidth: 1)
                    )

                HStack(spacing: 0) {
                    Image(systemName: "globe")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isHovered ? .white : Color.white.opacity(0.85))
                }
            }
            .frame(width: 32, height: 32)
            .scaleEffect(isHovered ? 1.08 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .help("แปลภาษาข้อความที่คุมดำ (Translate)")
    }
}
