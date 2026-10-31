import XCTest
@testable import MonkeyTools

final class UpdateLocalizationTests: XCTestCase {
    func testUpdateLocalizationKeysExist() {
        let loc = LocalizationManager.shared
        let keys = [
            "update_heading",
            "update_current_version",
            "update_last_checked",
            "update_check_button",
            "update_checking",
            "update_available_title",
            "update_download_button",
            "update_up_to_date",
            "menu_check_updates",
            "menu_update_available",
            "update_button_install",
            "update_downloading",
            "update_extracting",
            "update_relaunching",
            "update_failed",
            "update_restart_button"
        ]

        for key in keys {
            XCTAssertFalse(loc[key].isEmpty, "Missing translation for key \(key)")
            XCTAssertNotEqual(loc[key], key, "Key \(key) was not localized")
        }
    }
}
