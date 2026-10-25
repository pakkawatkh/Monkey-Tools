import XCTest
@testable import MonkeyCopy

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

    @MainActor
    func testSettingsWindowController() {
        let controller = SettingsWindowController.shared
        XCTAssertNotNil(controller.window)
        XCTAssertEqual(controller.window?.title, "monkey-copy Preferences")
        XCTAssertFalse(controller.window?.isReleasedWhenClosed ?? true)
    }
}
