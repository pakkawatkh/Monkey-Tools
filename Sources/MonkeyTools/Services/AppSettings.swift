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
        static let translateHotkeyEnabled = "app_translate_hotkey_enabled"
        static let translateHotkeyKeyCode = "app_translate_hotkey_keycode"
        static let translateHotkeyModifiers = "app_translate_hotkey_modifiers"
        static let translateHotkeyDisplay = "app_translate_hotkey_display"
        static let excludedApps = "app_excluded_bundle_ids"
        static let translatorExcludedApps = "app_translator_excluded_bundle_ids"
        static let translationEngineMode = "app_translation_engine_mode"
        static let translationTargetLang = "app_translation_target_lang"
        static let appLanguage = "app_ui_language"
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
            if selectionTranslateEnabled {
                TextSelectionMonitor.shared.startMonitoring()
            } else {
                TextSelectionMonitor.shared.stopMonitoring()
                SelectionBubblePanel.shared.hide()
            }
        }
    }

    @Published public var translateHotkeyEnabled: Bool {
        didSet {
            UserDefaults.standard.set(translateHotkeyEnabled, forKey: Keys.translateHotkeyEnabled)
            if translateHotkeyEnabled {
                HotKeyManager.shared.registerSavedTranslateHotKey()
            } else {
                HotKeyManager.shared.unregisterTranslateHotKey()
            }
        }
    }

    @Published public var translateHotkeyKeyCode: UInt32 {
        didSet {
            UserDefaults.standard.set(translateHotkeyKeyCode, forKey: Keys.translateHotkeyKeyCode)
        }
    }

    @Published public var translateHotkeyModifiers: UInt32 {
        didSet {
            UserDefaults.standard.set(translateHotkeyModifiers, forKey: Keys.translateHotkeyModifiers)
        }
    }

    @Published public var translateHotkeyDisplayString: String {
        didSet {
            UserDefaults.standard.set(translateHotkeyDisplayString, forKey: Keys.translateHotkeyDisplay)
        }
    }

    @Published public var excludedAppBundleIDs: [String] {
        didSet {
            UserDefaults.standard.set(excludedAppBundleIDs, forKey: Keys.excludedApps)
        }
    }

    @Published public var translatorExcludedAppBundleIDs: [String] {
        didSet {
            UserDefaults.standard.set(translatorExcludedAppBundleIDs, forKey: Keys.translatorExcludedApps)
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

        let savedTranslateEnabled = defaults.object(forKey: Keys.translateHotkeyEnabled) as? Bool
        let savedTranslateKeyCode = defaults.object(forKey: Keys.translateHotkeyKeyCode) as? UInt32
        let savedTranslateModifiers = defaults.object(forKey: Keys.translateHotkeyModifiers) as? UInt32
        let savedTranslateDisplay = defaults.string(forKey: Keys.translateHotkeyDisplay)
        let savedExcludedApps = defaults.stringArray(forKey: Keys.excludedApps)
        let savedTranslatorExcludedApps = defaults.stringArray(forKey: Keys.translatorExcludedApps)

        self.hotkeyKeyCode = savedKeyCode ?? 9
        self.hotkeyModifiers = savedModifiers ?? UInt32(cmdKey | shiftKey)
        self.hotkeyDisplayString = AppSettings.formatDisplayString(savedDisplay ?? "⌘ + ⇧ + V")
        self.maxHistoryCount = savedMax ?? 100
        self.launchAtLogin = savedLaunch
        self.autoPasteEnabled = savedAutoPaste ?? true
        self.selectionTranslateEnabled = savedSelectionTranslate ?? true
        self.translateHotkeyEnabled = savedTranslateEnabled ?? true
        self.translateHotkeyKeyCode = savedTranslateKeyCode ?? 14
        self.translateHotkeyModifiers = savedTranslateModifiers ?? UInt32(cmdKey | shiftKey)
        self.translateHotkeyDisplayString = AppSettings.formatDisplayString(savedTranslateDisplay ?? "⌘ + ⇧ + E")
        self.excludedAppBundleIDs = savedExcludedApps ?? []
        self.translatorExcludedAppBundleIDs = savedTranslatorExcludedApps ?? []
        self.translationEngineMode = (savedEngineRaw.flatMap(TranslationEngineMode.init(rawValue:))) ?? .google
        self.translationTargetLang = savedTargetLang ?? "auto"
        self.appLanguage = savedAppLanguage ?? "system"
    }

    public func setHotKey(keyCode: UInt32, modifiers: UInt32, display: String) {
        self.hotkeyKeyCode = keyCode
        self.hotkeyModifiers = modifiers
        self.hotkeyDisplayString = AppSettings.formatDisplayString(display)
        HotKeyManager.shared.registerHotKey(keyCode: keyCode, modifiers: modifiers)
    }

    public func setTranslateHotKey(keyCode: UInt32, modifiers: UInt32, display: String) {
        self.translateHotkeyKeyCode = keyCode
        self.translateHotkeyModifiers = modifiers
        self.translateHotkeyDisplayString = AppSettings.formatDisplayString(display)
        if self.translateHotkeyEnabled {
            HotKeyManager.shared.registerTranslateHotKey(keyCode: keyCode, modifiers: modifiers)
        }
    }

    public func addExcludedApp(bundleID: String) {
        let trimmed = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !excludedAppBundleIDs.contains(trimmed) else { return }
        excludedAppBundleIDs.append(trimmed)
    }

    public func removeExcludedApp(bundleID: String) {
        excludedAppBundleIDs.removeAll { $0 == bundleID }
    }

    public func addTranslatorExcludedApp(bundleID: String) {
        let trimmed = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !translatorExcludedAppBundleIDs.contains(trimmed) else { return }
        translatorExcludedAppBundleIDs.append(trimmed)
    }

    public func removeTranslatorExcludedApp(bundleID: String) {
        translatorExcludedAppBundleIDs.removeAll { $0 == bundleID }
    }

    /// Returns true if both clipboard and quick-translate global hotkeys are set to the same key combination.
    public var hasHotkeyConflict: Bool {
        guard translateHotkeyEnabled else { return false }
        return hotkeyKeyCode == translateHotkeyKeyCode && hotkeyModifiers == translateHotkeyModifiers
    }

    /// Formats a shortcut string to ensure standard spacing and '+' separator (e.g. "⌘ + ⇧ + V").
    public static func formatDisplayString(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "⌘ + ⇧ + V"
        }
        if trimmed.contains("+") {
            let tokens = trimmed.split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            if !tokens.isEmpty {
                return tokens.joined(separator: " + ")
            }
        }
        var parts: [String] = []
        for char in trimmed {
            let s = String(char).trimmingCharacters(in: .whitespaces)
            if !s.isEmpty {
                parts.append(s)
            }
        }
        return parts.joined(separator: " + ")
    }

    /// Translates key codes to user-friendly display symbols/names for shortcut recording.
    public static func displayStringForKeyCode(_ keyCode: UInt16, characters: String?) -> String {
        switch Int(keyCode) {
        case 49: return "Space"
        case 36, 76: return "Return"
        case 48: return "Tab"
        case 51: return "Delete"
        case 53: return "Esc"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 122: return "F1"
        case 120: return "F2"
        case 99:  return "F3"
        case 118: return "F4"
        case 96:  return "F5"
        case 97:  return "F6"
        case 98:  return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        default:
            if let chars = characters?.uppercased().trimmingCharacters(in: .whitespacesAndNewlines), !chars.isEmpty {
                return chars
            }
            return ""
        }
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
        Preset(name: "Command + Shift + V (Default)", display: "⌘ + ⇧ + V", keyCode: 9, modifiers: UInt32(cmdKey | shiftKey)),
        Preset(name: "Option + V (Windows Win+V Style)", display: "⌥ + V", keyCode: 9, modifiers: UInt32(optionKey)),
        Preset(name: "Control + Option + V", display: "⌃ + ⌥ + V", keyCode: 9, modifiers: UInt32(controlKey | optionKey)),
        Preset(name: "Command + Option + V", display: "⌘ + ⌥ + V", keyCode: 9, modifiers: UInt32(cmdKey | optionKey))
    ]

    public static let translatePresets: [Preset] = [
        Preset(name: "Command + Shift + E (Default)", display: "⌘ + ⇧ + E", keyCode: 14, modifiers: UInt32(cmdKey | shiftKey)),
        Preset(name: "Option + E", display: "⌥ + E", keyCode: 14, modifiers: UInt32(optionKey)),
        Preset(name: "Control + Option + T", display: "⌃ + ⌥ + T", keyCode: 17, modifiers: UInt32(controlKey | optionKey)),
        Preset(name: "Command + Option + T", display: "⌘ + ⌥ + T", keyCode: 17, modifiers: UInt32(cmdKey | optionKey))
    ]
}
