import Foundation
import Combine
import AppKit
import CryptoKit

public enum ClipboardActiveTab: String, CaseIterable {
    case clipboard
    case emoji
}

public enum ClipboardCategoryFilter: String, CaseIterable, Identifiable {
    case all
    case text
    case image
    case pinned

    public var id: String { rawValue }

    public func title(loc: LocalizationManager) -> String {
        switch self {
        case .all: return loc["tab_all"]
        case .text: return loc["tab_text"]
        case .image: return loc["tab_image"]
        case .pinned: return loc["tab_pinned"]
        }
    }
}

public final class ClipboardManager: ObservableObject {
    public static let shared = ClipboardManager()

    @Published public private(set) var items: [ClipboardItem] = []
    @Published public var searchQuery: String = "" {
        didSet {
            selectedIndex = 0
        }
    }
    @Published public var selectedIndex: Int = 0
    @Published public var activeTab: ClipboardActiveTab = .clipboard
    @Published public var selectedFilter: ClipboardCategoryFilter = .all {
        didSet {
            selectedIndex = 0
        }
    }
    @Published public var maxHistoryCount: Int = 100

    private let storage: ClipboardStorage

    public init(storage: ClipboardStorage = .shared) {
        self.storage = storage
        self.items = storage.load()
        let savedMax = UserDefaults.standard.object(forKey: "app_max_history") as? Int
        self.maxHistoryCount = savedMax ?? 100

        // Background migration: generate missing thumbnails for legacy images
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.generateMissingThumbnails()
        }
    }

    /// Scans history for image items lacking a thumbnail and generates them in the background
    private func generateMissingThumbnails() {
        var updated = false
        var currentItems = items

        for index in currentItems.indices {
            let item = currentItems[index]
            if item.type == .image && item.thumbnailFileName == nil, let imgName = item.imageFileName {
                let imageURL = storage.imagesDirectory.appendingPathComponent(imgName)
                if let (_, thumbData) = ClipboardStorage.generateThumbnail(from: imageURL, maxPixelSize: 360),
                   !thumbData.isEmpty {
                    let thumbName = "thumb_\(UUID().uuidString).jpg"
                    storage.saveImageData(thumbData, fileName: thumbName)
                    currentItems[index].thumbnailFileName = thumbName
                    updated = true
                }
            }
        }

        if updated {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if self.items.count == currentItems.count {
                    self.items = currentItems
                    self.storage.save(items: currentItems)
                }
            }
        }
    }

    /// Computed property returning filtered items based on current search query.
    /// Pinned items always appear before unpinned items.
    public var filteredItems: [ClipboardItem] {
        let baseItems: [ClipboardItem]
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        var itemsToFilter = items
        switch selectedFilter {
        case .all:
            break
        case .text:
            itemsToFilter = itemsToFilter.filter { $0.type == .text }
        case .image:
            itemsToFilter = itemsToFilter.filter { $0.type == .image }
        case .pinned:
            itemsToFilter = itemsToFilter.filter { $0.isPinned }
        }

        if query.isEmpty {
            baseItems = itemsToFilter
        } else {
            let lowerQuery = query.lowercased()
            baseItems = itemsToFilter.filter { item in
                switch item.type {
                case .text:
                    return item.text?.localizedCaseInsensitiveContains(query) == true
                case .image:
                    // Match image keyword in English or Thai, or dimension
                    if "image".contains(lowerQuery) || "รูป".contains(lowerQuery) || "img".contains(lowerQuery) {
                        return true
                    }
                    if let w = item.imageWidth, let h = item.imageHeight {
                        let dim = "\(w)x\(h)"
                        return dim.contains(lowerQuery)
                    }
                    return false
                }
            }
        }

        // Pinned first, then sorted by timestamp descending
        var pinned: [ClipboardItem] = []
        var unpinned: [ClipboardItem] = []
        for item in baseItems {
            if item.isPinned {
                pinned.append(item)
            } else {
                unpinned.append(item)
            }
        }
        pinned.sort { $0.timestamp > $1.timestamp }
        unpinned.sort { $0.timestamp > $1.timestamp }
        pinned.append(contentsOf: unpinned)
        return pinned
    }

    /// Add a new text string copied from clipboard
    @discardableResult
    public func add(text: String) -> ClipboardItem? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Check if an item with exact same text exists
        if let existingIndex = items.firstIndex(where: { $0.type == .text && $0.text == text }) {
            var existing = items.remove(at: existingIndex)
            existing.timestamp = Date()
            items.insert(existing, at: 0)
            storage.save(items: items)
            selectedIndex = 0
            return existing
        }

        let newItem = ClipboardItem(
            type: .text,
            text: text,
            timestamp: Date(),
            isPinned: false
        )
        insertAndPrune(newItem)
        return newItem
    }

    /// Add a new image copied from clipboard
    @discardableResult
    public func addImage(nsImage: NSImage, data: Data) -> ClipboardItem? {
        let hash = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()

        // Check if exact same image already exists
        if let existingIndex = items.firstIndex(where: { $0.type == .image && $0.dataHash == hash }) {
            var existing = items.remove(at: existingIndex)
            existing.timestamp = Date()
            items.insert(existing, at: 0)
            storage.save(items: items)
            selectedIndex = 0
            return existing
        }

        let imageUUID = UUID().uuidString
        let fileName = "\(imageUUID).png"
        storage.saveImageData(data, fileName: fileName)

        // Generate downscaled thumbnail (~15-30 KB) for instant 120fps UI rendering
        var thumbFileName: String? = nil
        if let thumbData = ClipboardStorage.generateThumbnail(from: data, nsImage: nsImage, maxPixelSize: 360) {
            let name = "thumb_\(imageUUID).jpg"
            storage.saveImageData(thumbData, fileName: name)
            thumbFileName = name
        }

        let width = Int(nsImage.size.width)
        let height = Int(nsImage.size.height)

        let newItem = ClipboardItem(
            type: .image,
            imageFileName: fileName,
            thumbnailFileName: thumbFileName,
            imageWidth: width,
            imageHeight: height,
            dataHash: hash,
            timestamp: Date(),
            isPinned: false
        )
        insertAndPrune(newItem)
        return newItem
    }

    private func insertAndPrune(_ newItem: ClipboardItem) {
        items.insert(newItem, at: 0)

        // Enforce maxHistoryCount for unpinned items
        let pinnedCount = items.filter { $0.isPinned }.count
        let unpinnedAllowed = max(10, maxHistoryCount - pinnedCount)

        var unpinnedCount = 0
        items = items.filter { item in
            if item.isPinned {
                return true
            }
            unpinnedCount += 1
            return unpinnedCount <= unpinnedAllowed
        }

        storage.save(items: items)
        storage.cleanupUnusedImages(retainedItems: items)
        selectedIndex = 0
    }

    /// Toggle pin state for an item
    public func togglePin(for item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        storage.save(items: items)
    }

    /// Delete an item from history
    public func delete(item: ClipboardItem) {
        if item.type == .image {
            storage.deleteImageFiles(imageFileName: item.imageFileName, thumbnailFileName: item.thumbnailFileName)
        }
        items.removeAll { $0.id == item.id }
        storage.save(items: items)
        if selectedIndex >= filteredItems.count && !filteredItems.isEmpty {
            selectedIndex = filteredItems.count - 1
        }
    }

    /// Clear all unpinned items (or all items if includingPinned is true)
    public func clearAll(includingPinned: Bool = false) {
        if includingPinned {
            items.removeAll()
        } else {
            items.removeAll { !$0.isPinned }
        }
        storage.save(items: items)
        storage.cleanupUnusedImages(retainedItems: items)
        selectedIndex = 0
    }

    /// Select previous item (up arrow key)
    public func selectPrevious() {
        let count = filteredItems.count
        guard count > 0 else { return }
        if selectedIndex <= 0 || selectedIndex >= count {
            selectedIndex = count - 1
        } else {
            selectedIndex -= 1
        }
    }

    /// Select next item (down arrow key)
    public func selectNext() {
        let count = filteredItems.count
        guard count > 0 else { return }
        if selectedIndex < 0 || selectedIndex >= count - 1 {
            selectedIndex = 0
        } else {
            selectedIndex += 1
        }
    }

    /// Get currently selected item if any
    public var selectedItem: ClipboardItem? {
        let list = filteredItems
        guard !list.isEmpty else { return nil }
        let clampedIndex = max(0, min(selectedIndex, list.count - 1))
        return list[clampedIndex]
    }
}
