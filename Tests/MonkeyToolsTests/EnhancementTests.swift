import XCTest
import Carbon
import AppKit
@testable import MonkeyTools

final class EnhancementTests: XCTestCase {
    private var tempDir: URL!
    private var testStorage: ClipboardStorage!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        testStorage = ClipboardStorage(
            customURL: tempDir.appendingPathComponent("history.json"),
            customImagesURL: tempDir.appendingPathComponent("images")
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testClipboardCategoryFilter() {
        let manager = ClipboardManager(storage: testStorage)
        manager.clearAll(includingPinned: true)

        _ = manager.add(text: "Hello text item")!
        let item2 = manager.add(text: "Pinned text item")!
        manager.togglePin(for: item2)

        let testImg = NSImage(size: NSSize(width: 40, height: 40))
        testImg.lockFocus()
        NSColor.blue.drawSwatch(in: NSRect(x: 0, y: 0, width: 40, height: 40))
        testImg.unlockFocus()
        let imgData = testImg.tiffRepresentation!
        let imgItem = manager.addImage(nsImage: testImg, data: imgData)!

        // All filter
        manager.selectedFilter = .all
        XCTAssertEqual(manager.filteredItems.count, 3)

        // Text filter
        manager.selectedFilter = .text
        XCTAssertEqual(manager.filteredItems.count, 2)
        XCTAssertTrue(manager.filteredItems.allSatisfy { $0.type == .text })

        // Image filter
        manager.selectedFilter = .image
        XCTAssertEqual(manager.filteredItems.count, 1)
        XCTAssertEqual(manager.filteredItems.first?.id, imgItem.id)

        // Pinned filter
        manager.selectedFilter = .pinned
        XCTAssertEqual(manager.filteredItems.count, 1)
        XCTAssertEqual(manager.filteredItems.first?.id, item2.id)
    }

    func testTranslatePresetsAndSettings() {
        XCTAssertFalse(AppSettings.translatePresets.isEmpty)
        let defaultTranslate = AppSettings.translatePresets.first { $0.keyCode == 14 }
        XCTAssertNotNil(defaultTranslate)
        XCTAssertEqual(defaultTranslate?.display, "⌘ + ⇧ + E")

        for preset in AppSettings.translatePresets {
            XCTAssertTrue(preset.display.contains(" + "))
        }

        let settings = AppSettings.shared
        let originalExcluded = settings.excludedAppBundleIDs

        settings.addExcludedApp(bundleID: "com.test.excluded")
        XCTAssertTrue(settings.excludedAppBundleIDs.contains("com.test.excluded"))

        // Test deduplication
        settings.addExcludedApp(bundleID: "com.test.excluded")
        XCTAssertEqual(settings.excludedAppBundleIDs.filter { $0 == "com.test.excluded" }.count, 1)

        settings.removeExcludedApp(bundleID: "com.test.excluded")
        XCTAssertFalse(settings.excludedAppBundleIDs.contains("com.test.excluded"))

        // Restore
        settings.excludedAppBundleIDs = originalExcluded
    }

    func testNewLocalizationKeys() {
        let loc = LocalizationManager.shared
        let keysToCheck = [
            "trans_loading",
            "trans_retry",
            "settings_recording_hint",
            "settings_popular_presets",
            "settings_translate_hotkey_heading",
            "settings_translate_hotkey_desc",
            "settings_translate_hotkey_enable",
            "settings_excluded_apps_heading",
            "settings_excluded_apps_desc",
            "settings_add_excluded_app",
            "settings_remove_excluded_app",
            "settings_no_excluded_apps",
            "settings_permissions_heading",
            "settings_accessibility_title",
            "settings_accessibility_granted_desc",
            "settings_accessibility_missing_desc",
            "settings_open_system_settings",
            "menu_pause_clipboard",
            "menu_resume_clipboard",
            "clipboard_paused_banner",
            "time_just_now",
            "preview_item",
            "translate_item",
            "open_url",
            "ocr_extract",
            "ocr_copied",
            "ocr_no_text",
            "trans_history",
            "settings_translator_excluded_heading",
            "settings_hotkey_conflict",
            "bubble_tooltip"
        ]

        for code in ["th", "en", "zh"] {
            loc.setLanguage(fromCode: code)
            for key in keysToCheck {
                let localized = loc[key]
                XCTAssertNotEqual(localized, key, "Key '\(key)' should be localized for language \(code)")
                XCTAssertFalse(localized.isEmpty, "Key '\(key)' should not be empty for language \(code)")
            }
        }
    }

    func testSmartContentDetectionHexColorAndURL() {
        let hex6 = ClipboardItem(type: .text, text: "#3B82F6")
        XCTAssertNotNil(hex6.detectedHexColor)
        XCTAssertNil(hex6.detectedURL)

        let hex3 = ClipboardItem(type: .text, text: " #F0A ")
        XCTAssertNotNil(hex3.detectedHexColor)

        let hex8 = ClipboardItem(type: .text, text: "#FF573380")
        XCTAssertNotNil(hex8.detectedHexColor)

        let notHex = ClipboardItem(type: .text, text: "#ZZZZZZ")
        XCTAssertNil(notHex.detectedHexColor)

        let validURL = ClipboardItem(type: .text, text: "https://pakkawatkh.github.io/Pliw-App/")
        XCTAssertNotNil(validURL.detectedURL)
        XCTAssertNil(validURL.detectedHexColor)

        let multilineText = ClipboardItem(type: .text, text: "https://example.com\nsecond line")
        XCTAssertNil(multilineText.detectedURL)
    }

    func testSourceAppMetadataAndSearch() {
        let manager = ClipboardManager(storage: testStorage)
        manager.clearAll(includingPinned: true)

        let item = manager.add(text: "console.log('hi')", sourceAppBundleID: "com.microsoft.VSCode", sourceAppName: "Visual Studio Code")
        XCTAssertEqual(item?.sourceAppBundleID, "com.microsoft.VSCode")
        XCTAssertEqual(item?.sourceAppName, "Visual Studio Code")

        // Search by sourceAppName
        manager.searchQuery = "Visual Studio"
        XCTAssertEqual(manager.filteredItems.count, 1)
        XCTAssertEqual(manager.filteredItems.first?.id, item?.id)

        // Verify persistence through async save -> sync load
        let reloaded = testStorage.load()
        XCTAssertEqual(reloaded.count, 1)
        XCTAssertEqual(reloaded.first?.sourceAppBundleID, "com.microsoft.VSCode")
        XCTAssertEqual(reloaded.first?.sourceAppName, "Visual Studio Code")
    }

    func testLocalizedRelativeTime() {
        let loc = LocalizationManager.shared
        let nowItem = ClipboardItem(type: .text, text: "now", timestamp: Date())

        loc.setLanguage(fromCode: "th")
        XCTAssertEqual(nowItem.localizedRelativeTime(loc: loc), "เมื่อสักครู่")

        loc.setLanguage(fromCode: "en")
        XCTAssertEqual(nowItem.localizedRelativeTime(loc: loc), "Just now")

        loc.setLanguage(fromCode: "zh")
        XCTAssertEqual(nowItem.localizedRelativeTime(loc: loc), "刚刚")
    }

    func testClipboardMonitorPauseAndTranslatorExcludedAndConflict() {
        let monitor = ClipboardMonitor()
        XCTAssertFalse(monitor.isPaused)
        monitor.togglePause()
        XCTAssertTrue(monitor.isPaused)
        monitor.togglePause()
        XCTAssertFalse(monitor.isPaused)

        let settings = AppSettings.shared
        let origTranslatorExcluded = settings.translatorExcludedAppBundleIDs
        settings.addTranslatorExcludedApp(bundleID: "com.apple.Terminal")
        XCTAssertTrue(settings.translatorExcludedAppBundleIDs.contains("com.apple.Terminal"))
        settings.removeTranslatorExcludedApp(bundleID: "com.apple.Terminal")
        XCTAssertFalse(settings.translatorExcludedAppBundleIDs.contains("com.apple.Terminal"))
        settings.translatorExcludedAppBundleIDs = origTranslatorExcluded

        // Verify network tab was removed
        XCTAssertEqual(SettingsTab.allCases.count, 3)
        XCTAssertEqual(SettingsTab.allCases, [.clipboard, .translator, .general])
    }

    func testTranslationHistoryRecordingAndClearing() {
        let service = TranslationService.shared
        service.clearHistory()

        let r1 = TranslationResult(originalText: "Hello", translatedText: "สวัสดี", sourceLanguage: "en", targetLanguage: "th", engineUsed: .google)
        let r2 = TranslationResult(originalText: "World", translatedText: "โลก", sourceLanguage: "en", targetLanguage: "th", engineUsed: .google)
        service.recordHistory(r1)
        service.recordHistory(r2)
        service.recordHistory(r1) // duplicate moves to top

        XCTAssertEqual(service.history.count, 2)
        XCTAssertEqual(service.history.first?.originalText, "Hello")

        service.clearHistory()
        XCTAssertTrue(service.history.isEmpty)
    }
}
