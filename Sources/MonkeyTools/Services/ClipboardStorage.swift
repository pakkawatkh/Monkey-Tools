import Foundation

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

    public func cleanupUnusedImages(retainedItems: [ClipboardItem]) {
        let activeImageFileNames = Set(retainedItems.compactMap { $0.imageFileName })
        guard let files = try? fileManager.contentsOfDirectory(atPath: imagesDirectory.path) else { return }

        for file in files {
            if !activeImageFileNames.contains(file) {
                let fileURL = imagesDirectory.appendingPathComponent(file)
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }
}
