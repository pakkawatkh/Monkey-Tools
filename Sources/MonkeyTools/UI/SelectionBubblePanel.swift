import AppKit
import SwiftUI

public final class SelectionBubblePanel: NSPanel {
    public static let shared = SelectionBubblePanel()

    private var currentText: String = ""
    private var currentRect: CGRect = .zero
    private var isCurrentSelectionEditable: Bool = false
    private var currentSourceAppPID: pid_t = 0
    private var autoDismissTimer: Timer?
    private var globalEventMonitor: Any?
    private var localKeyMonitor: Any?
    private var localMouseMonitor: Any?
    private var workspaceObserver: NSObjectProtocol?

    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 26, height: 26),
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
        hosting.layer?.cornerRadius = 13
        hosting.layer?.masksToBounds = true
        self.contentView = hosting
    }

    public override var canBecomeKey: Bool {
        return false
    }

    public override var canBecomeMain: Bool {
        return false
    }

    public func show(at rect: CGRect, selectedText: String, sourceAppPID: pid_t = 0, isEditable: Bool = false) {
        guard TextSelectionMonitor.shared.isValidSelectionText(selectedText) else { return }

        self.currentText = selectedText
        self.currentRect = rect
        self.currentSourceAppPID = sourceAppPID
        self.isCurrentSelectionEditable = isEditable

        // Position bubble snugly right next to the end of selection, centered vertically on text
        let endX = rect.width <= 2 ? rect.origin.x : rect.maxX
        let centerY = rect.width <= 2 ? rect.origin.y : rect.midY

        var bubbleX = endX + 4
        var bubbleY = centerY - 13 // Centered vertically (26pt height / 2)

        // Prevent overflow beyond screen bounds on the specific screen containing this selection
        let targetPoint = CGPoint(x: endX, y: centerY)
        let screen = NSScreen.screens.first { $0.frame.contains(targetPoint) }
                  ?? NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
                  ?? NSScreen.main
                  ?? NSScreen.screens.first

        if let screen = screen {
            let screenFrame = screen.visibleFrame
            if bubbleX + 30 > screenFrame.maxX {
                bubbleX = (rect.width <= 2 ? rect.origin.x : rect.minX) - 30
            }
            if bubbleX + 30 > screenFrame.maxX {
                bubbleX = screenFrame.maxX - 30
            }
            if bubbleY + 30 > screenFrame.maxY {
                bubbleY = screenFrame.maxY - 30
            }
            if bubbleX < screenFrame.minX {
                bubbleX = screenFrame.minX + 4
            }
            if bubbleY < screenFrame.minY {
                bubbleY = screenFrame.minY + 4
            }
        }

        self.setFrameOrigin(NSPoint(x: bubbleX, y: bubbleY))
        self.alphaValue = 1.0
        self.orderFrontRegardless()

        startEventMonitoring()

        // Auto-dismiss after 6 seconds if untouched
        autoDismissTimer?.invalidate()
        autoDismissTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: false) { [weak self] _ in
            self?.hide()
        }
    }

    public func hide() {
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil
        stopEventMonitoring()

        if !NSApp.isRunning {
            self.alphaValue = 0.0
            self.orderOut(nil)
            return
        }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            self.animator().alphaValue = 0.0
        }, completionHandler: {
            self.alphaValue = 0.0
            self.orderOut(nil)
        })
    }

    private func handleBubbleTap() {
        let text = self.currentText
        let targetPoint = CGPoint(x: self.frame.origin.x, y: self.frame.origin.y)
        let isEditable = self.isCurrentSelectionEditable
        let pid = self.currentSourceAppPID
        self.hide()

        guard TextSelectionMonitor.shared.isValidSelectionText(text) else { return }

        DispatchQueue.main.async {
            TranslationPopoverPanel.shared.show(text: text, near: targetPoint, sourceAppPID: pid, isEditable: isEditable)
        }
    }

    private func startEventMonitoring() {
        stopEventMonitoring()

        // 1. Global event monitor:
        // Dismiss immediately if user clicks outside the bubble, presses any key, or scrolls
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown, .scrollWheel]
        ) { [weak self] event in
            guard let self = self, self.isVisible else { return }

            switch event.type {
            case .keyDown, .scrollWheel:
                DispatchQueue.main.async {
                    self.hide()
                }

            case .leftMouseDown, .rightMouseDown, .otherMouseDown:
                let mouseLocation = NSEvent.mouseLocation
                if !self.frame.insetBy(dx: -4, dy: -4).contains(mouseLocation) {
                    DispatchQueue.main.async {
                        self.hide()
                    }
                }

            default:
                break
            }
        }

        // 2. Local monitors (when monkey-tools receives keyboard or mouse events):
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            DispatchQueue.main.async {
                self?.hide()
            }
            return event
        }

        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            guard let self = self, self.isVisible else { return event }
            let mouseLocation = NSEvent.mouseLocation
            if !self.frame.insetBy(dx: -4, dy: -4).contains(mouseLocation) {
                DispatchQueue.main.async {
                    self.hide()
                }
            }
            return event
        }

        // 3. Workspace active app change observer:
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.hide()
        }
    }

    private func stopEventMonitoring() {
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
        if let monitor = localMouseMonitor {
            NSEvent.removeMonitor(monitor)
            localMouseMonitor = nil
        }
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            workspaceObserver = nil
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
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isHovered ? .white : Color.white.opacity(0.90))
                }
            }
            .frame(width: 26, height: 26)
            .scaleEffect(isHovered ? 1.08 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .help(LocalizationManager.shared["bubble_tooltip"])
    }
}
