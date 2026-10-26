import AppKit
import Carbon

public final class HotKeyManager {
    public static let shared = HotKeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    public var onHotKeyPressed: (() -> Void)?

    public init() {}

    /// Registers the hotkey stored in AppSettings
    public func registerSavedHotKey() {
        let keyCode = AppSettings.shared.hotkeyKeyCode
        let modifiers = AppSettings.shared.hotkeyModifiers
        registerHotKey(keyCode: keyCode, modifiers: modifiers)
    }

    public func registerHotKey(keyCode: UInt32, modifiers: UInt32) {
        unregisterHotKey()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        let handler: EventHandlerUPP = { (_, _, userData) -> OSStatus in
            guard let userData = userData else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async {
                manager.onHotKeyPressed?()
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

        guard installStatus == noErr else {
            print("[HotKeyManager] Failed to install event handler: \(installStatus)")
            return
        }

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
            print("[HotKeyManager] Failed to register hot key: \(registerStatus)")
        } else {
            print("[HotKeyManager] Successfully registered hot key (code: \(keyCode), mods: \(modifiers))")
        }
    }

    public func unregisterHotKey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef = eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    deinit {
        unregisterHotKey()
    }
}
