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

        // Test English
        loc.setLanguage(fromCode: "en")
        XCTAssertEqual(loc.effectiveLanguageCode, "en")
        XCTAssertEqual(loc["tab_clipboard"], "Clipboard")
        XCTAssertEqual(loc["trans_replace"], "Replace Original Text")

        // Test Chinese
        loc.setLanguage(fromCode: "zh")
        XCTAssertEqual(loc.effectiveLanguageCode, "zh")
        XCTAssertEqual(loc["tab_clipboard"], "剪贴板")
        XCTAssertEqual(loc["trans_replace"], "替换原文")

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
        XCTAssertEqual(controller.window?.title, "monkey-copy Preferences")
        XCTAssertFalse(controller.window?.isReleasedWhenClosed ?? true)
    }
}
