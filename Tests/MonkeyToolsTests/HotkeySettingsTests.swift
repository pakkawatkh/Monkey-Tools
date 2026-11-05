import XCTest
import Carbon
@testable import MonkeyTools

final class HotkeySettingsTests: XCTestCase {
    func testPresetsUsePlusSeparator() {
        XCTAssertFalse(AppSettings.presets.isEmpty)
        for preset in AppSettings.presets {
            XCTAssertTrue(preset.display.contains(" + "), "Preset \(preset.name) display '\(preset.display)' should contain ' + ' separator")
        }

        let targetMods = UInt32(cmdKey | shiftKey)
        let defaultPreset = AppSettings.presets.first(where: { $0.keyCode == 9 && $0.modifiers == targetMods })
        XCTAssertNotNil(defaultPreset)
        XCTAssertEqual(defaultPreset?.display, "⌘ + ⇧ + V")
    }

    func testFormatDisplayStringLegacyCompact() {
        XCTAssertEqual(AppSettings.formatDisplayString("⌘⇧V"), "⌘ + ⇧ + V")
        XCTAssertEqual(AppSettings.formatDisplayString("⌥V"), "⌥ + V")
        XCTAssertEqual(AppSettings.formatDisplayString("⌃⌥V"), "⌃ + ⌥ + V")
        XCTAssertEqual(AppSettings.formatDisplayString("⌘⌥V"), "⌘ + ⌥ + V")
        XCTAssertEqual(AppSettings.formatDisplayString("⌘+⇧+V"), "⌘ + ⇧ + V")
        XCTAssertEqual(AppSettings.formatDisplayString("⌘ + ⇧ + V"), "⌘ + ⇧ + V")
        XCTAssertEqual(AppSettings.formatDisplayString(""), "⌘ + ⇧ + V")
    }

    func testDisplayStringForKeyCode() {
        XCTAssertEqual(AppSettings.displayStringForKeyCode(49, characters: " "), "Space")
        XCTAssertEqual(AppSettings.displayStringForKeyCode(36, characters: "\r"), "Return")
        XCTAssertEqual(AppSettings.displayStringForKeyCode(48, characters: "\t"), "Tab")
        XCTAssertEqual(AppSettings.displayStringForKeyCode(53, characters: nil), "Esc")
        XCTAssertEqual(AppSettings.displayStringForKeyCode(9, characters: "v"), "V")
    }
}
