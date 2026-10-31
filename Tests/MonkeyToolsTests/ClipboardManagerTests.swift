import XCTest
@testable import MonkeyTools

final class ClipboardManagerTests: XCTestCase {
    var temporaryStorageURL: URL!
    var storage: ClipboardStorage!
    var manager: ClipboardManager!

    override func setUp() {
        super.setUp()
        let tempDir = FileManager.default.temporaryDirectory
        temporaryStorageURL = tempDir.appendingPathComponent("test_history_\(UUID().uuidString).json")
        storage = ClipboardStorage(customURL: temporaryStorageURL)
        manager = ClipboardManager(storage: storage)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: temporaryStorageURL)
        super.tearDown()
    }

    func testAddItem() {
        let text = "Hello, Mac Clipboard!"
        let item = manager.add(text: text)

        XCTAssertNotNil(item)
        XCTAssertEqual(manager.items.count, 1)
        XCTAssertEqual(manager.items.first?.text, text)
    }

    func testIgnoreEmptyString() {
        let item = manager.add(text: "   \n\t  ")
        XCTAssertNil(item)
        XCTAssertEqual(manager.items.count, 0)
    }

    func testDeduplicationAndMoveToTop() {
        manager.add(text: "First text")
        manager.add(text: "Second text")
        XCTAssertEqual(manager.items.count, 2)
        XCTAssertEqual(manager.items[0].text, "Second text")

        // Re-adding "First text" should move it to top and not increase count
        manager.add(text: "First text")
        XCTAssertEqual(manager.items.count, 2)
        XCTAssertEqual(manager.items[0].text, "First text")
    }

    func testPinningMaintainsPriority() {
        manager.add(text: "Item 1")
        manager.add(text: "Item 2")
        let item1 = manager.items.first { $0.text == "Item 1" }!

        manager.togglePin(for: item1)

        let filtered = manager.filteredItems
        XCTAssertTrue(filtered[0].isPinned)
        XCTAssertEqual(filtered[0].text, "Item 1")
    }

    func testSearchFiltering() {
        manager.add(text: "SwiftUI is awesome")
        manager.add(text: "MacBook Pro M-series")
        manager.add(text: "Windows Clipboard history")

        manager.searchQuery = "swift"
        XCTAssertEqual(manager.filteredItems.count, 1)
        XCTAssertEqual(manager.filteredItems.first?.text, "SwiftUI is awesome")

        manager.searchQuery = "clipboard"
        XCTAssertEqual(manager.filteredItems.count, 1)
        XCTAssertEqual(manager.filteredItems.first?.text, "Windows Clipboard history")

        manager.searchQuery = "nonexistent"
        XCTAssertEqual(manager.filteredItems.count, 0)
    }

    func testClearUnpinnedPreservesPinned() {
        manager.add(text: "Unpinned item 1")
        manager.add(text: "Pinned item")
        manager.add(text: "Unpinned item 2")

        let pinnedItem = manager.items.first { $0.text == "Pinned item" }!
        manager.togglePin(for: pinnedItem)

        // Clear unpinned
        manager.clearAll(includingPinned: false)
        XCTAssertEqual(manager.items.count, 1)
        XCTAssertEqual(manager.items.first?.text, "Pinned item")

        // Clear all
        manager.clearAll(includingPinned: true)
        XCTAssertEqual(manager.items.count, 0)
    }

    func testDeleteItem() {
        manager.add(text: "Item A")
        manager.add(text: "Item B")
        let itemA = manager.items.first { $0.text == "Item A" }!

        manager.delete(item: itemA)
        XCTAssertEqual(manager.items.count, 1)
        XCTAssertEqual(manager.items.first?.text, "Item B")
    }

    func testStoragePersistence() {
        let sampleItems = [
            ClipboardItem(text: "Persisted text 1", timestamp: Date(), isPinned: true),
            ClipboardItem(text: "Persisted text 2", timestamp: Date(), isPinned: false)
        ]

        storage.save(items: sampleItems)

        let loadedItems = storage.load()
        XCTAssertEqual(loadedItems.count, 2)
        XCTAssertEqual(loadedItems[0].text, "Persisted text 1")
        XCTAssertTrue(loadedItems[0].isPinned)
        XCTAssertEqual(loadedItems[1].text, "Persisted text 2")
        XCTAssertFalse(loadedItems[1].isPinned)
    }

    func testAddImageItem() {
        let image = NSImage(size: NSSize(width: 200, height: 100))
        let data = "FakeImageData".data(using: .utf8)!

        let item = manager.addImage(nsImage: image, data: data)
        XCTAssertNotNil(item)
        XCTAssertEqual(item?.type, .image)
        XCTAssertEqual(item?.imageWidth, 200)
        XCTAssertEqual(item?.imageHeight, 100)
        XCTAssertEqual(manager.items.count, 1)
    }

    func testThumbnailGenerationAndCleanup() {
        let size = NSSize(width: 800, height: 600)
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        let image = NSImage(size: size)
        image.addRepresentation(rep)
        let validPngData = rep.representation(using: .png, properties: [:])!

        let item = manager.addImage(nsImage: image, data: validPngData)
        XCTAssertNotNil(item)
        XCTAssertNotNil(item?.thumbnailFileName)
        XCTAssertTrue(item?.thumbnailFileName?.hasPrefix("thumb_") == true)

        // Verify thumbnail loads and is cached
        let thumb = item?.loadThumbnail()
        XCTAssertNotNil(thumb)

        // Verify full image data is preserved at 100% fidelity
        let rawData = item?.loadImageData()
        XCTAssertEqual(rawData, validPngData)

        // Verify deleting item also deletes thumbnail and image files
        let thumbPath = storage.imagesDirectory.appendingPathComponent(item!.thumbnailFileName!).path
        let imgPath = storage.imagesDirectory.appendingPathComponent(item!.imageFileName!).path
        XCTAssertTrue(FileManager.default.fileExists(atPath: thumbPath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: imgPath))

        manager.delete(item: item!)
        XCTAssertFalse(FileManager.default.fileExists(atPath: thumbPath))
        XCTAssertFalse(FileManager.default.fileExists(atPath: imgPath))
    }

    func testImageDeduplication() {
        let image = NSImage(size: NSSize(width: 100, height: 100))
        let data = "IdenticalImageData".data(using: .utf8)!

        manager.addImage(nsImage: image, data: data)
        manager.add(text: "Some text in between")
        XCTAssertEqual(manager.items.count, 2)
        XCTAssertEqual(manager.items[0].text, "Some text in between")

        // Adding exact same image should move it back to top without increasing count
        manager.addImage(nsImage: image, data: data)
        XCTAssertEqual(manager.items.count, 2)
        XCTAssertEqual(manager.items[0].type, .image)
    }

    func testImageSearch() {
        let image = NSImage(size: NSSize(width: 800, height: 600))
        let data = "ImageDataForSearch".data(using: .utf8)!
        manager.addImage(nsImage: image, data: data)
        manager.add(text: "Normal text note")

        manager.searchQuery = "image"
        XCTAssertEqual(manager.filteredItems.count, 1)
        XCTAssertEqual(manager.filteredItems.first?.type, .image)

        manager.searchQuery = "800x600"
        XCTAssertEqual(manager.filteredItems.count, 1)
        XCTAssertEqual(manager.filteredItems.first?.type, .image)
    }

    func testStorageDirectoryName() {
        let defaultStorage = ClipboardStorage()
        XCTAssertTrue(defaultStorage.storageURL.path.contains("monkey-tools"))
        XCTAssertTrue(defaultStorage.imagesDirectory.path.contains("monkey-tools"))
    }

    func testKeyboardSelectionNavigation() {
        manager.add(text: "Item 1")
        manager.add(text: "Item 2")
        manager.add(text: "Item 3")
        // Items are in reverse chronological order: [Item 3, Item 2, Item 1]
        XCTAssertEqual(manager.filteredItems.count, 3)
        XCTAssertEqual(manager.selectedIndex, 0)
        XCTAssertEqual(manager.selectedItem?.text, "Item 3")

        // Down arrow: next item
        manager.selectNext()
        XCTAssertEqual(manager.selectedIndex, 1)
        XCTAssertEqual(manager.selectedItem?.text, "Item 2")

        manager.selectNext()
        XCTAssertEqual(manager.selectedIndex, 2)
        XCTAssertEqual(manager.selectedItem?.text, "Item 1")

        // Down arrow at bottom wraps around to top
        manager.selectNext()
        XCTAssertEqual(manager.selectedIndex, 0)
        XCTAssertEqual(manager.selectedItem?.text, "Item 3")

        // Up arrow from top wraps around to bottom
        manager.selectPrevious()
        XCTAssertEqual(manager.selectedIndex, 2)
        XCTAssertEqual(manager.selectedItem?.text, "Item 1")

        // Up arrow: previous item
        manager.selectPrevious()
        XCTAssertEqual(manager.selectedIndex, 1)
        XCTAssertEqual(manager.selectedItem?.text, "Item 2")
    }

    func testSearchQueryResetsSelectedIndex() {
        manager.add(text: "Apple MacBook")
        manager.add(text: "Google Pixel")
        manager.add(text: "Apple iPhone")

        manager.selectedIndex = 2
        XCTAssertEqual(manager.selectedIndex, 2)

        // Typing in search query must reset selectedIndex to 0
        manager.searchQuery = "Apple"
        XCTAssertEqual(manager.selectedIndex, 0)
        XCTAssertEqual(manager.filteredItems.count, 2)
    }
}
