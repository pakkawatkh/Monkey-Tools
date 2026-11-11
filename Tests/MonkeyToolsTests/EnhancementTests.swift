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
            "settings_network_fixed_slot_tip"
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
}
