import AppKit
import Combine
import SwiftUI

@MainActor
public final class StatusMenuController: NSObject, NSPopoverDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover!
    private let popoverViewModel = MonkeyPopoverViewModel()

    private var cancellables = Set<AnyCancellable>()
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?

    public override init() {
        super.init()
        setupStatusItem()
        setupPopover()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = statusItem?.button else { return }

        // Set monkey template icon for macOS Menu Bar
        let monkeyIcon = createMonkeyTemplateIcon()
        button.image = monkeyIcon
        button.imagePosition = .imageOnly
        button.toolTip = LocalizationManager.shared["menu_tooltip"]

        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseDown, .rightMouseDown])

        setupObservers()
        updateStatusItemDisplay()
    }

    private func setupPopover() {
        let rootView = MonkeyStatusPopoverView(
            settings: AppSettings.shared,
            monitor: ClipboardMonitor.shared,
            clipboard: ClipboardManager.shared,
            localization: LocalizationManager.shared,
            updateChecker: UpdateCheckService.shared,
            updateInstaller: UpdateInstallerService.shared,
            viewModel: popoverViewModel,
            onShowClipboard: { [weak self] in
                self?.closePopover()
                self?.togglePanel()
            },
            onOpenAccessibility: { [weak self] in
                self?.closePopover()
                self?.openAccessibilitySettings()
            },
            onOpenSettings: { [weak self] in
                self?.closePopover()
                self?.openSettings()
            },
            onOpenUpdateDownload: { [weak self] in
                self?.closePopover()
                self?.openUpdateDownload()
            },
            onCheckUpdates: { [weak self] in
                self?.closePopover()
                self?.checkForUpdatesManually()
            },
            onQuit: { [weak self] in
                self?.quitApp()
            }
        )

        let hosting = NSHostingController(rootView: rootView)
        hosting.sizingOptions = [.preferredContentSize]

        let pop = NSPopover()
        pop.contentViewController = hosting
        pop.behavior = .applicationDefined
        pop.animates = true
        pop.delegate = self
        self.popover = pop
    }

    private func setupObservers() {
        ClipboardMonitor.shared.$isPaused
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusItemDisplay()
            }
            .store(in: &cancellables)

        LocalizationManager.shared.$effectiveLanguageCode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusItemDisplay()
            }
            .store(in: &cancellables)
    }

    private func updateStatusItemDisplay() {
        guard let button = statusItem?.button else { return }
        button.toolTip = LocalizationManager.shared["menu_tooltip"]
        button.alphaValue = ClipboardMonitor.shared.isPaused ? 0.45 : 1.0
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
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    public func showMenu() {
        showPopover()
    }

    private func showPopover() {
        guard let button = statusItem?.button else { return }
        popoverViewModel.refreshState()
        popoverViewModel.expandedSection = nil

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        installEventMonitors()
    }

    private func closePopover() {
        if popover.isShown {
            popover.performClose(nil)
        }
        removeEventMonitors()
    }

    public func popoverDidClose(_ notification: Notification) {
        removeEventMonitors()
    }

    private func installEventMonitors() {
        removeEventMonitors()

        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.popover.isShown else { return }
                self.closePopover()
            }
        }

        localEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown]
        ) { [weak self] event in
            guard let self, self.popover.isShown else { return event }

            switch event.type {
            case .keyDown:
                if event.keyCode == 53 { // Escape
                    self.closePopover()
                    return nil
                }
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                if flags == .command {
                    if event.charactersIgnoringModifiers == "," {
                        self.closePopover()
                        self.openSettings()
                        return nil
                    }
                    if event.charactersIgnoringModifiers?.lowercased() == "q" {
                        self.quitApp()
                        return nil
                    }
                }
                return event

            case .leftMouseDown, .rightMouseDown, .otherMouseDown:
                let popoverWindow = self.popover.contentViewController?.view.window
                let statusWindow = self.statusItem?.button?.window
                if event.window !== popoverWindow && event.window !== statusWindow {
                    self.closePopover()
                }
                return event

            default:
                return event
            }
        }
    }

    private func removeEventMonitors() {
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }

    @objc private func togglePanel() {
        ClipboardPanel.shared.toggleVisibility()
    }

    @objc private func openAccessibilitySettings() {
        AutoPaster.shared.openAccessibilitySettings()
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.showSettings()
    }

    @objc private func openUpdateDownload() {
        SettingsWindowController.shared.showSettings()
        if !UpdateInstallerService.shared.isInstalling, let info = UpdateCheckService.shared.latestUpdateInfo {
            UpdateInstallerService.shared.startUpdate(with: info)
        }
    }

    @objc private func checkForUpdatesManually() {
        SettingsWindowController.shared.showSettings()
        UpdateCheckService.shared.checkForUpdates(force: true)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
