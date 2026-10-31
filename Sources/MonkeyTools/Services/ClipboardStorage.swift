import AppKit
import Foundation
import ImageIO

public final class ClipboardStorage {
    public static let shared = ClipboardStorage()

    private let fileManager = FileManager.default
    public let storageURL: URL
    public let imagesDirectory: URL

    public init(customURL: URL? = nil, customImagesURL: URL? = nil) {
        if let customURL = customURL {
            self.storageURL = customURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let appDir = appSupport.appendingPathComponent("monkey-tools", isDirectory: true)
            let legacyCopyDir = appSupport.appendingPathComponent("monkey-copy", isDirectory: true)
            let bxxsDir = appSupport.appendingPathComponent("bxxs-clipboard", isDirectory: true)
            let macDir = appSupport.appendingPathComponent("MacClipboard", isDirectory: true)

            // Auto-migrate from previous directories if present
            if !fileManager.fileExists(atPath: appDir.path) {
                if fileManager.fileExists(atPath: legacyCopyDir.path) {
                    try? fileManager.copyItem(at: legacyCopyDir, to: appDir)
                } else if fileManager.fileExists(atPath: bxxsDir.path) {
                    try? fileManager.copyItem(at: bxxsDir, to: appDir)
                } else if fileManager.fileExists(atPath: macDir.path) {
                    try? fileManager.copyItem(at: macDir, to: appDir)
                }
            }

            self.storageURL = appDir.appendingPathComponent("history.json")
        }

        if let customImagesURL = customImagesURL {
            self.imagesDirectory = customImagesURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let appDir = appSupport.appendingPathComponent("monkey-tools", isDirectory: true)
            self.imagesDirectory = appDir.appendingPathComponent("images", isDirectory: true)
        }

        ensureDirectoriesExist()
    }

    private func ensureDirectoriesExist() {
        let parentDir = storageURL.deletingLastPathComponent()
        try? fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
    }

    public func load() -> [ClipboardItem] {
        guard fileManager.fileExists(atPath: storageURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let items = try decoder.decode([ClipboardItem].self, from: data)
            return items
        } catch {
            print("[ClipboardStorage] Error loading history: \(error)")
            return []
        }
    }

    public func save(items: [ClipboardItem]) {
        ensureDirectoriesExist()
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(items)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            print("[ClipboardStorage] Error saving history: \(error)")
        }
    }

    public func saveImageData(_ data: Data, fileName: String) {
        ensureDirectoriesExist()
        let fileURL = imagesDirectory.appendingPathComponent(fileName)
        try? data.write(to: fileURL, options: .atomic)
    }

    public func deleteImageFile(fileName: String) {
        let fileURL = imagesDirectory.appendingPathComponent(fileName)
        try? fileManager.removeItem(at: fileURL)
    }

    public func deleteImageFiles(imageFileName: String?, thumbnailFileName: String?) {
        if let img = imageFileName {
            deleteImageFile(fileName: img)
        }
        if let thumb = thumbnailFileName {
            deleteImageFile(fileName: thumb)
        }
    }

    public func cleanupUnusedImages(retainedItems: [ClipboardItem]) {
        var activeImageFileNames = Set<String>()
        for item in retainedItems {
            if let img = item.imageFileName {
                activeImageFileNames.insert(img)
            }
            if let thumb = item.thumbnailFileName {
                activeImageFileNames.insert(thumb)
            }
        }
        guard let files = try? fileManager.contentsOfDirectory(atPath: imagesDirectory.path) else { return }

        for file in files {
            if !activeImageFileNames.contains(file) {
                let fileURL = imagesDirectory.appendingPathComponent(file)
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }

    // MARK: - Thumbnail Generation

    /// Generates high-efficiency downscaled thumbnail JPEG data (max dimension maxPixelSize, quality 0.75)
    public static func generateThumbnail(from data: Data, nsImage: NSImage? = nil, maxPixelSize: CGFloat = 360) -> Data? {
        // Fast path: CoreGraphics ImageIO thumbnail decoder
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        if let source = CGImageSourceCreateWithData(data as CFData, nil),
           let cgThumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
            let rep = NSBitmapImageRep(cgImage: cgThumb)
            if let jpegData = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.75]) {
                return jpegData
            }
        }

        // Fallback: NSImage drawing
        if let img = nsImage ?? NSImage(data: data) {
            let size = img.size
            guard size.width > 0, size.height > 0 else { return nil }
            let scale = min(maxPixelSize / max(size.width, size.height), 1.0)
            let targetSize = NSSize(width: max(1, size.width * scale), height: max(1, size.height * scale))

            let thumb = NSImage(size: targetSize)
            thumb.lockFocus()
            img.draw(in: NSRect(origin: .zero, size: targetSize),
                     from: NSRect(origin: .zero, size: size),
                     operation: .copy,
                     fraction: 1.0)
            thumb.unlockFocus()

            if let tiff = thumb.tiffRepresentation,
               let rep = NSBitmapImageRep(data: tiff),
               let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.75]) {
                return jpeg
            }
        }

        return nil
    }

    /// Fast thumbnail extraction directly from file on disk via ImageIO without loading full bitmap into memory
    public static func generateThumbnail(from fileURL: URL, maxPixelSize: CGFloat = 360) -> (image: NSImage, data: Data)? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
              let cgThumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        let thumbImage = NSImage(cgImage: cgThumb, size: NSSize(width: cgThumb.width, height: cgThumb.height))
        let rep = NSBitmapImageRep(cgImage: cgThumb)
        let jpegData = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.75]) ?? Data()
        return (thumbImage, jpegData)
    }
}
