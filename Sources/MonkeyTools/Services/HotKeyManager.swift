import AppKit
import Carbon

public final class HotKeyManager {
    public static let shared = HotKeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var translateHotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    public var onHotKeyPressed: (() -> Void)?
    public var onTranslateHotKeyPressed: (() -> Void)?

    public init() {}

    private func ensureEventHandlerInstalled() {
        guard eventHandlerRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        let handler: EventHandlerUPP = { (_, event, userData) -> OSStatus in
            guard let userData = userData, let event = event else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()

            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            if status == noErr {
                if hotKeyID.id == 1 {
                    DispatchQueue.main.async {
                        manager.onHotKeyPressed?()
                    }
                } else if hotKeyID.id == 2 {
                    DispatchQueue.main.async {
                        manager.onTranslateHotKeyPressed?()
                    }
                }
            } else {
                DispatchQueue.main.async {
                    manager.onHotKeyPressed?()
                }
            }
            return noErr
        }

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )

        if installStatus != noErr {
            print("[HotKeyManager] Failed to install event handler: \(installStatus)")
        }
    }

    /// Registers the clipboard hotkey stored in AppSettings
    public func registerSavedHotKey() {
        let keyCode = AppSettings.shared.hotkeyKeyCode
        let modifiers = AppSettings.shared.hotkeyModifiers
        registerHotKey(keyCode: keyCode, modifiers: modifiers)
    }

    public func registerHotKey(keyCode: UInt32, modifiers: UInt32) {
        unregisterHotKey()
        ensureEventHandlerInstalled()

        let hotKeyID = EventHotKeyID(signature: OSType(0x4D434250), id: 1)
        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if registerStatus != noErr {
            print("[HotKeyManager] Failed to register clipboard hot key: \(registerStatus)")
        } else {
            print("[HotKeyManager] Successfully registered clipboard hot key (code: \(keyCode), mods: \(modifiers))")
        }
    }

    public func unregisterHotKey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    /// Registers the quick translate hotkey stored in AppSettings
    public func registerSavedTranslateHotKey() {
        guard AppSettings.shared.translateHotkeyEnabled else {
            unregisterTranslateHotKey()
            return
        }
        let keyCode = AppSettings.shared.translateHotkeyKeyCode
        let modifiers = AppSettings.shared.translateHotkeyModifiers
        registerTranslateHotKey(keyCode: keyCode, modifiers: modifiers)
    }

    public func registerTranslateHotKey(keyCode: UInt32, modifiers: UInt32) {
        unregisterTranslateHotKey()
        ensureEventHandlerInstalled()

        let hotKeyID = EventHotKeyID(signature: OSType(0x4D434250), id: 2)
        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &translateHotKeyRef
        )

        if registerStatus != noErr {
            print("[HotKeyManager] Failed to register translate hot key: \(registerStatus)")
        } else {
            print("[HotKeyManager] Successfully registered translate hot key (code: \(keyCode), mods: \(modifiers))")
        }
    }

    public func unregisterTranslateHotKey() {
        if let translateRef = translateHotKeyRef {
            UnregisterEventHotKey(translateRef)
            self.translateHotKeyRef = nil
        }
    }

    public func unregisterAll() {
        unregisterHotKey()
        unregisterTranslateHotKey()
        if let eventHandlerRef = eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    deinit {
        unregisterAll()
    }
}
