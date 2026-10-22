import Foundation
import Carbon
import AppKit
import ServiceManagement

public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()

    private enum Keys {
        static let hotkeyKeyCode = "app_hotkey_keycode"
        static let hotkeyModifiers = "app_hotkey_modifiers"
        static let hotkeyDisplay = "app_hotkey_display"
        static let maxHistory = "app_max_history"
        static let launchAtLogin = "app_launch_at_login"
        static let autoPasteEnabled = "app_auto_paste_enabled"
    }

    @Published public var hotkeyKeyCode: UInt32 {
        didSet {
            UserDefaults.standard.set(hotkeyKeyCode, forKey: Keys.hotkeyKeyCode)
        }
    }

    @Published public var hotkeyModifiers: UInt32 {
        didSet {
            UserDefaults.standard.set(hotkeyModifiers, forKey: Keys.hotkeyModifiers)
        }
    }

    @Published public var hotkeyDisplayString: String {
        didSet {
            UserDefaults.standard.set(hotkeyDisplayString, forKey: Keys.hotkeyDisplay)
        }
    }

    @Published public var maxHistoryCount: Int {
        didSet {
            UserDefaults.standard.set(maxHistoryCount, forKey: Keys.maxHistory)
            ClipboardManager.shared.maxHistoryCount = maxHistoryCount
        }
    }

    @Published public var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin)
            updateLoginItem(enabled: launchAtLogin)
        }
    }

    @Published public var autoPasteEnabled: Bool {
        didSet {
            UserDefaults.standard.set(autoPasteEnabled, forKey: Keys.autoPasteEnabled)
        }
    }

    public init() {
        let defaults = UserDefaults.standard

        // Default hotkey is Cmd + Shift + V (keyCode 9, modifiers: cmdKey | shiftKey)
        let savedKeyCode = defaults.object(forKey: Keys.hotkeyKeyCode) as? UInt32
        let savedModifiers = defaults.object(forKey: Keys.hotkeyModifiers) as? UInt32
        let savedDisplay = defaults.string(forKey: Keys.hotkeyDisplay)
        let savedMax = defaults.object(forKey: Keys.maxHistory) as? Int
        let savedLaunch = defaults.bool(forKey: Keys.launchAtLogin)
        let savedAutoPaste = defaults.object(forKey: Keys.autoPasteEnabled) as? Bool

        self.hotkeyKeyCode = savedKeyCode ?? 9
        self.hotkeyModifiers = savedModifiers ?? UInt32(cmdKey | shiftKey)
        self.hotkeyDisplayString = savedDisplay ?? "⌘⇧V"
        self.maxHistoryCount = savedMax ?? 100
        self.launchAtLogin = savedLaunch
        self.autoPasteEnabled = savedAutoPaste ?? true
    }

    public func setHotKey(keyCode: UInt32, modifiers: UInt32, display: String) {
        self.hotkeyKeyCode = keyCode
        self.hotkeyModifiers = modifiers
        self.hotkeyDisplayString = display
        HotKeyManager.shared.registerHotKey(keyCode: keyCode, modifiers: modifiers)
    }

    private func updateLoginItem(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("[AppSettings] Failed to update login item: \(error)")
            }
        }
    }

    // Preset shortcuts
    public struct Preset: Identifiable {
        public let id = UUID()
        public let name: String
        public let display: String
        public let keyCode: UInt32
        public let modifiers: UInt32
    }

    public static let presets: [Preset] = [
        Preset(name: "Command + Shift + V (Default)", display: "⌘⇧V", keyCode: 9, modifiers: UInt32(cmdKey | shiftKey)),
        Preset(name: "Option + V (Windows Win+V Style)", display: "⌥V", keyCode: 9, modifiers: UInt32(optionKey)),
        Preset(name: "Control + Option + V", display: "⌃⌥V", keyCode: 9, modifiers: UInt32(controlKey | optionKey)),
        Preset(name: "Command + Option + V", display: "⌘⌥V", keyCode: 9, modifiers: UInt32(cmdKey | optionKey))
    ]
}
