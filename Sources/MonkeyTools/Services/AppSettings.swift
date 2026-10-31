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
        static let selectionTranslateEnabled = "app_selection_translate_enabled"
        static let translationEngineMode = "app_translation_engine_mode"
        static let translationTargetLang = "app_translation_target_lang"
        static let appLanguage = "app_ui_language"
        static let networkMonitorEnabled = "app_network_monitor_enabled"
        static let networkSpeedUnit = "app_network_speed_unit"
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

    @Published public var selectionTranslateEnabled: Bool {
        didSet {
            UserDefaults.standard.set(selectionTranslateEnabled, forKey: Keys.selectionTranslateEnabled)
        }
    }

    @Published public var translationEngineMode: TranslationEngineMode {
        didSet {
            UserDefaults.standard.set(translationEngineMode.rawValue, forKey: Keys.translationEngineMode)
        }
    }

    @Published public var translationTargetLang: String {
        didSet {
            UserDefaults.standard.set(translationTargetLang, forKey: Keys.translationTargetLang)
        }
    }

    @Published public var appLanguage: String {
        didSet {
            UserDefaults.standard.set(appLanguage, forKey: Keys.appLanguage)
            LocalizationManager.shared.setLanguage(fromCode: appLanguage)
        }
    }

    @Published public var networkMonitorEnabled: Bool {
        didSet {
            UserDefaults.standard.set(networkMonitorEnabled, forKey: Keys.networkMonitorEnabled)
            if networkMonitorEnabled {
                NetworkMonitorService.shared.startMonitoring()
            } else {
                NetworkMonitorService.shared.stopMonitoring()
            }
        }
    }

    @Published public var networkSpeedUnit: NetworkSpeedUnit {
        didSet {
            UserDefaults.standard.set(networkSpeedUnit.rawValue, forKey: Keys.networkSpeedUnit)
            NetworkMonitorService.shared.currentUnit = networkSpeedUnit
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
        let savedSelectionTranslate = defaults.object(forKey: Keys.selectionTranslateEnabled) as? Bool
        let savedEngineRaw = defaults.string(forKey: Keys.translationEngineMode)
        let savedTargetLang = defaults.string(forKey: Keys.translationTargetLang)
        let savedAppLanguage = defaults.string(forKey: Keys.appLanguage)
        let savedNetworkMonitor = defaults.object(forKey: Keys.networkMonitorEnabled) as? Bool
        let savedNetworkSpeedUnitRaw = defaults.string(forKey: Keys.networkSpeedUnit)

        self.hotkeyKeyCode = savedKeyCode ?? 9
        self.hotkeyModifiers = savedModifiers ?? UInt32(cmdKey | shiftKey)
        self.hotkeyDisplayString = savedDisplay ?? "⌘⇧V"
        self.maxHistoryCount = savedMax ?? 100
        self.launchAtLogin = savedLaunch
        self.autoPasteEnabled = savedAutoPaste ?? true
        self.selectionTranslateEnabled = savedSelectionTranslate ?? true
        self.translationEngineMode = (savedEngineRaw.flatMap(TranslationEngineMode.init(rawValue:))) ?? .google
        self.translationTargetLang = savedTargetLang ?? "auto"
        self.appLanguage = savedAppLanguage ?? "system"

        self.networkMonitorEnabled = savedNetworkMonitor ?? true
        let unit = (savedNetworkSpeedUnitRaw.flatMap(NetworkSpeedUnit.init(rawValue:))) ?? .autoBytes
        self.networkSpeedUnit = unit

        NetworkMonitorService.shared.currentUnit = unit
        if self.networkMonitorEnabled {
            NetworkMonitorService.shared.startMonitoring()
        }
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
