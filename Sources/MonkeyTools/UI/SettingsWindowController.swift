import AppKit
import SwiftUI

public final class SettingsWindowController: NSWindowController {
    public static let shared = SettingsWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 550),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "monkey-tools Preferences"
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.center()

        let hosting = NSHostingView(rootView: SettingsView())
        window.contentView = hosting

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func showSettings() {
        if let window = window {
            if !window.isVisible {
                window.center()
            }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    public func toggleSettings() {
        guard let window = window else { return }
        if window.isVisible && NSApp.isActive {
            window.orderOut(nil)
        } else {
            showSettings()
        }
    }
}
