import AppKit
import Foundation

public enum ClipboardItemType: String, Codable {
    case text
    case image
}

public struct ClipboardItem: Identifiable, Codable, Equatable, Hashable {
    public let id: UUID
    public let type: ClipboardItemType
    public let text: String?
    public let imageFileName: String?
    public var thumbnailFileName: String?
    public let imageWidth: Int?
    public let imageHeight: Int?
    public let dataHash: String?
    public var timestamp: Date
    public var isPinned: Bool

    public init(
        id: UUID = UUID(),
        type: ClipboardItemType = .text,
        text: String? = nil,
        imageFileName: String? = nil,
        thumbnailFileName: String? = nil,
        imageWidth: Int? = nil,
        imageHeight: Int? = nil,
        dataHash: String? = nil,
        timestamp: Date = Date(),
        isPinned: Bool = false
    ) {
        self.id = id
        self.type = type
        self.text = text
        self.imageFileName = imageFileName
        self.thumbnailFileName = thumbnailFileName
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.dataHash = dataHash
        self.timestamp = timestamp
        self.isPinned = isPinned
    }

    enum CodingKeys: String, CodingKey {
        case id, type, text, imageFileName, thumbnailFileName, imageWidth, imageHeight, dataHash, timestamp, isPinned
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decodeIfPresent(ClipboardItemType.self, forKey: .type) ?? .text
        text = try container.decodeIfPresent(String.self, forKey: .text)
        imageFileName = try container.decodeIfPresent(String.self, forKey: .imageFileName)
        thumbnailFileName = try container.decodeIfPresent(String.self, forKey: .thumbnailFileName)
        imageWidth = try container.decodeIfPresent(Int.self, forKey: .imageWidth)
        imageHeight = try container.decodeIfPresent(Int.self, forKey: .imageHeight)
        dataHash = try container.decodeIfPresent(String.self, forKey: .dataHash)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }

    public var characterCount: Int {
        return text?.count ?? 0
    }

    public var previewText: String {
        guard let text = text else { return "" }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? text : trimmed
    }

    public var relativeTime: String {
        let seconds = -timestamp.timeIntervalSinceNow
        if seconds < 5 {
            return "Just now"
        } else if seconds < 60 {
            return "\(Int(seconds))s ago"
        } else if seconds < 3600 {
            let minutes = Int(seconds / 60)
            return "\(minutes)m ago"
        } else if seconds < 86400 {
            let hours = Int(seconds / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(seconds / 86400)
            return "\(days)d ago"
        }
    }

    /// In-memory cache for decoded thumbnails to guarantee 120fps scrolling and eliminate repeated disk I/O
    private static let thumbnailCache = NSCache<NSString, NSImage>()

    /// Load thumbnail NSImage from disk or cache. Falls back gracefully if thumbnail hasn't been generated yet.
    public func loadThumbnail() -> NSImage? {
        guard type == .image else { return nil }

        // 1. Try dedicated thumbnail file from cache or disk
        if let thumbName = thumbnailFileName {
            if let cached = ClipboardItem.thumbnailCache.object(forKey: thumbName as NSString) {
                return cached
            }
            let thumbURL = ClipboardStorage.shared.imagesDirectory.appendingPathComponent(thumbName)
            if let image = NSImage(contentsOf: thumbURL) {
                ClipboardItem.thumbnailCache.setObject(image, forKey: thumbName as NSString)
                return image
            }
        }

        // 2. Legacy fallback: if thumbnail doesn't exist yet, attempt fast ImageIO thumbnail directly from imageFileName
        if let fileName = imageFileName {
            let cacheKey = ("fast_thumb_" + fileName) as NSString
            if let cached = ClipboardItem.thumbnailCache.object(forKey: cacheKey) {
                return cached
            }

            let imageURL = ClipboardStorage.shared.imagesDirectory.appendingPathComponent(fileName)
            if let (thumbImage, _) = ClipboardStorage.generateThumbnail(from: imageURL, maxPixelSize: 360) {
                ClipboardItem.thumbnailCache.setObject(thumbImage, forKey: cacheKey)
                return thumbImage
            }

            // Ultimate fallback: full image load
            if let fullImage = loadImage() {
                ClipboardItem.thumbnailCache.setObject(fullImage, forKey: cacheKey)
                return fullImage
            }
        }

        return nil
    }

    /// Load NSImage from disk if this is an image item (100% full quality)
    public func loadImage() -> NSImage? {
        guard type == .image, let fileName = imageFileName else { return nil }
        let imageURL = ClipboardStorage.shared.imagesDirectory.appendingPathComponent(fileName)
        return NSImage(contentsOf: imageURL)
    }

    /// Load raw image Data from disk (100% full quality for pasteboard)
    public func loadImageData() -> Data? {
        guard type == .image, let fileName = imageFileName else { return nil }
        let imageURL = ClipboardStorage.shared.imagesDirectory.appendingPathComponent(fileName)
        return try? Data(contentsOf: imageURL)
    }
}
