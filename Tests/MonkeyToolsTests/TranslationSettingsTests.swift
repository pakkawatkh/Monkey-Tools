import XCTest
@testable import MonkeyTools

final class TranslationSettingsTests: XCTestCase {
    func testTranslationSettingsDefaults() {
        let settings = AppSettings.shared
        XCTAssertTrue(settings.selectionTranslateEnabled)
        XCTAssertEqual(settings.translationEngineMode, .google)
        XCTAssertEqual(settings.translationTargetLang, "auto")
    }

    func testTranslationEngineSwitching() {
        let settings = AppSettings.shared
        settings.translationEngineMode = .appleNative
        XCTAssertEqual(settings.translationEngineMode, .appleNative)
        settings.translationEngineMode = .google
        XCTAssertEqual(settings.translationEngineMode, .google)
    }

    func testTargetLanguagePersistence() {
        let settings = AppSettings.shared
        settings.translationTargetLang = "ja"
        XCTAssertEqual(settings.translationTargetLang, "ja")
        settings.translationTargetLang = "auto"
        XCTAssertEqual(settings.translationTargetLang, "auto")
    }

    func testLocalizationManager() {
        let loc = LocalizationManager.shared

        // Test Thai
        loc.setLanguage(fromCode: "th")
        XCTAssertEqual(loc.effectiveLanguageCode, "th")
        XCTAssertEqual(loc["tab_clipboard"], "คลิปบอร์ด")
        XCTAssertEqual(loc["trans_replace"], "แทนที่คำเดิม")
        XCTAssertEqual(loc["settings_title"], "การตั้งค่า monkey-tools")
        XCTAssertEqual(loc["menu_show_monkey"], "เปิด monkey-tools")
        XCTAssertEqual(loc["menu_quit_item"], "ออกจาก monkey-tools")

        // Test English
        loc.setLanguage(fromCode: "en")
        XCTAssertEqual(loc.effectiveLanguageCode, "en")
        XCTAssertEqual(loc["tab_clipboard"], "Clipboard")
        XCTAssertEqual(loc["trans_replace"], "Replace Original Text")
        XCTAssertEqual(loc["settings_title"], "monkey-tools Settings")
        XCTAssertEqual(loc["menu_show_monkey"], "Show monkey-tools")
        XCTAssertEqual(loc["menu_quit_item"], "Quit monkey-tools")

        // Test Chinese
        loc.setLanguage(fromCode: "zh")
        XCTAssertEqual(loc.effectiveLanguageCode, "zh")
        XCTAssertEqual(loc["tab_clipboard"], "剪贴板")
        XCTAssertEqual(loc["trans_replace"], "替换原文")
        XCTAssertEqual(loc["settings_title"], "monkey-tools 设置")
        XCTAssertEqual(loc["menu_show_monkey"], "打开 monkey-tools")
        XCTAssertEqual(loc["menu_quit_item"], "退出 monkey-tools")

        // Test fallback for unknown key
        XCTAssertEqual(loc["unknown_test_key_xyz"], "unknown_test_key_xyz")

        // Reset to system
        loc.setLanguage(fromCode: "system")
        XCTAssertEqual(loc.currentLanguage, .system)
    }

    func testAppLanguagePersistenceInSettings() {
        let settings = AppSettings.shared
        settings.appLanguage = "en"
        XCTAssertEqual(settings.appLanguage, "en")
        XCTAssertEqual(LocalizationManager.shared.effectiveLanguageCode, "en")

        settings.appLanguage = "zh"
        XCTAssertEqual(settings.appLanguage, "zh")
        XCTAssertEqual(LocalizationManager.shared.effectiveLanguageCode, "zh")

        settings.appLanguage = "system"
        XCTAssertEqual(settings.appLanguage, "system")
    }

    @MainActor
    func testSettingsWindowController() {
        let controller = SettingsWindowController.shared
        XCTAssertNotNil(controller.window)
        XCTAssertEqual(controller.window?.title, "monkey-tools Preferences")
        XCTAssertFalse(controller.window?.isReleasedWhenClosed ?? true)
    }
}
