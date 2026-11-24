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
    public let sourceAppBundleID: String?
    public let sourceAppName: String?

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
        isPinned: Bool = false,
        sourceAppBundleID: String? = nil,
        sourceAppName: String? = nil
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
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
    }

    enum CodingKeys: String, CodingKey {
        case id, type, text, imageFileName, thumbnailFileName, imageWidth, imageHeight, dataHash, timestamp, isPinned, sourceAppBundleID, sourceAppName
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
        sourceAppBundleID = try container.decodeIfPresent(String.self, forKey: .sourceAppBundleID)
        sourceAppName = try container.decodeIfPresent(String.self, forKey: .sourceAppName)
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

    public func localizedRelativeTime(loc: LocalizationManager = .shared) -> String {
        let seconds = max(0, -timestamp.timeIntervalSinceNow)
        if seconds < 5 {
            return loc["time_just_now"]
        } else if seconds < 60 {
            return String(format: loc["time_seconds_ago"], Int(seconds))
        } else if seconds < 3600 {
            return String(format: loc["time_minutes_ago"], Int(seconds / 60))
        } else if seconds < 86400 {
            return String(format: loc["time_hours_ago"], Int(seconds / 3600))
        } else {
            return String(format: loc["time_days_ago"], Int(seconds / 86400))
        }
    }

    /// Detects if the text item is a standalone CSS Hex Color (#RGB, #RRGGBB, #RRGGBBAA).
    public var detectedHexColor: NSColor? {
        guard type == .text, let raw = text?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return nil
        }
        guard raw.hasPrefix("#") else { return nil }
        let hex = String(raw.dropFirst())
        guard hex.count == 3 || hex.count == 6 || hex.count == 8 else { return nil }
        let hexChars = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        guard hex.unicodeScalars.allSatisfy({ hexChars.contains($0) }) else { return nil }

        var expanded = hex
        if hex.count == 3 {
            expanded = hex.map { "\($0)\($0)" }.joined()
        }

        var value: UInt64 = 0
        guard Scanner(string: expanded).scanHexInt64(&value) else { return nil }

        if expanded.count == 6 {
            let r = CGFloat((value & 0xFF0000) >> 16) / 255.0
            let g = CGFloat((value & 0x00FF00) >> 8) / 255.0
            let b = CGFloat(value & 0x0000FF) / 255.0
            return NSColor(srgbRed: r, green: g, blue: b, alpha: 1.0)
        } else if expanded.count == 8 {
            let r = CGFloat((value & 0xFF000000) >> 24) / 255.0
            let g = CGFloat((value & 0x00FF0000) >> 16) / 255.0
            let b = CGFloat((value & 0x0000FF00) >> 8) / 255.0
            let a = CGFloat(value & 0x000000FF) / 255.0
            return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
        }
        return nil
    }

    /// Detects if the text item is a single-line HTTP/HTTPS URL.
    public var detectedURL: URL? {
        guard type == .text, let raw = text?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return nil
        }
        guard !raw.contains("\n"), !raw.contains(" ") else { return nil }
        let lower = raw.lowercased()
        guard lower.hasPrefix("http://") || lower.hasPrefix("https://") else { return nil }
        guard let url = URL(string: raw), let host = url.host, !host.isEmpty else { return nil }
        return url
    }

    /// In-memory cache for source app icons
    private static let appIconCache = NSCache<NSString, NSImage>()

    /// Loads and caches the macOS application icon for a bundle identifier.
    public static func icon(forBundleID bundleID: String) -> NSImage? {
        let key = bundleID as NSString
        if let cached = appIconCache.object(forKey: key) {
            return cached
        }
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        icon.size = NSSize(width: 16, height: 16)
        appIconCache.setObject(icon, forKey: key)
        return icon
    }

    /// Resolves the localized display name for a bundle identifier if installed.
    public static func displayName(forBundleID bundleID: String) -> String? {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        if let bundle = Bundle(url: appURL),
           let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                   ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String) {
            return name
        }
        return appURL.deletingPathExtension().lastPathComponent
    }

    public func loadSourceAppIcon() -> NSImage? {
        guard let bundleID = sourceAppBundleID else { return nil }
        return Self.icon(forBundleID: bundleID)
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
