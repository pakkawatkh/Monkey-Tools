import Foundation
import Combine
import AppKit
import CryptoKit

public final class ClipboardManager: ObservableObject {
    public static let shared = ClipboardManager()

    @Published public private(set) var items: [ClipboardItem] = []
    @Published public var searchQuery: String = ""
    @Published public var selectedIndex: Int = 0
    @Published public var maxHistoryCount: Int = 100

    private let storage: ClipboardStorage

    public init(storage: ClipboardStorage = .shared) {
        self.storage = storage
        self.items = storage.load()
    }

    /// Computed property returning filtered items based on current search query.
    /// Pinned items always appear before unpinned items.
    public var filteredItems: [ClipboardItem] {
        let baseItems: [ClipboardItem]
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        if query.isEmpty {
            baseItems = items
        } else {
            let lowerQuery = query.lowercased()
            baseItems = items.filter { item in
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

        let fileName = "\(UUID().uuidString).png"
        storage.saveImageData(data, fileName: fileName)

        let width = Int(nsImage.size.width)
        let height = Int(nsImage.size.height)

        let newItem = ClipboardItem(
            type: .image,
            imageFileName: fileName,
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
        if item.type == .image, let fileName = item.imageFileName {
            storage.deleteImageFile(fileName: fileName)
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
        selectedIndex = (selectedIndex - 1 + count) % count
    }

    /// Select next item (down arrow key)
    public func selectNext() {
        let count = filteredItems.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex + 1) % count
    }

    /// Get currently selected item if any
    public var selectedItem: ClipboardItem? {
        let list = filteredItems
        guard selectedIndex >= 0 && selectedIndex < list.count else { return nil }
        return list[selectedIndex]
    }
}
