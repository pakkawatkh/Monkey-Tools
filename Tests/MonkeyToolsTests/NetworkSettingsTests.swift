import XCTest
@testable import MonkeyTools

final class NetworkSettingsTests: XCTestCase {
    func testNetworkSettingsDefaultsAndPersistence() {
        let settings = AppSettings.shared
        XCTAssertNotNil(settings.networkMonitorEnabled)
        XCTAssertNotNil(settings.networkSpeedUnit)

        settings.networkSpeedUnit = .bits
        XCTAssertEqual(settings.networkSpeedUnit, .bits)
        settings.networkSpeedUnit = .autoBytes
    }

    func testLocalizationKeysExist() {
        let loc = LocalizationManager.shared
        let keys = [
            "settings_network_heading",
            "settings_network_enable",
            "settings_network_unit",
            "unit_auto_bytes",
            "unit_bits",
            "unit_fixed_kb",
            "unit_fixed_mb",
            "menu_network_speed",
            "menu_network_session_total"
        ]
        for key in keys {
            XCTAssertFalse(loc[key].isEmpty, "Missing translation for key \(key)")
            XCTAssertNotEqual(loc[key], key, "Key \(key) was not localized")
        }
    }
}
