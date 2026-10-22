import AppKit
import Foundation

public final class ClipboardMonitor {
    public static let shared = ClipboardMonitor()

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?
    private var lastProgrammaticString: String?
    private var isProgrammaticImageWrite = false

    public init() {
        self.lastChangeCount = pasteboard.changeCount
    }

    public func startMonitoring(interval: TimeInterval = 0.35) {
        stopMonitoring()
        lastChangeCount = pasteboard.changeCount

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    public func markProgrammaticWrite(text: String) {
        lastProgrammaticString = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            self.lastChangeCount = self.pasteboard.changeCount
        }
    }

    public func markProgrammaticImageWrite() {
        isProgrammaticImageWrite = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            self.lastChangeCount = self.pasteboard.changeCount
        }
    }

    private func checkPasteboard() {
        let currentChangeCount = pasteboard.changeCount
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        // 1. Ignore if programmatic image write from ourselves
        if isProgrammaticImageWrite {
            isProgrammaticImageWrite = false
            return
        }

        // 2. Ignore if programmatic text write from ourselves
        if let programmatic = lastProgrammaticString, programmatic == pasteboard.string(forType: .string) {
            lastProgrammaticString = nil
            return
        }

        // 3. Check for direct Image Data (PNG or TIFF)
        let hasDirectImage = pasteboard.types?.contains(where: { $0 == .png || $0 == .tiff }) ?? false
        if hasDirectImage {
            // Check if there is also plain text
            let plainText = pasteboard.string(forType: .string)

            // If plain text is absent or pasteboard specifically has PNG data
            if plainText == nil || pasteboard.types?.contains(.png) == true {
                if let pngData = pasteboard.data(forType: .png), let img = NSImage(data: pngData) {
                    DispatchQueue.main.async {
                        ClipboardManager.shared.addImage(nsImage: img, data: pngData)
                    }
                    return
                } else if let tiffData = pasteboard.data(forType: .tiff), let img = NSImage(data: tiffData) {
                    // Convert TIFF to PNG data for lightweight storage
                    let rep = NSBitmapImageRep(data: tiffData)
                    let pngData = rep?.representation(using: .png, properties: [:]) ?? tiffData
                    DispatchQueue.main.async {
                        ClipboardManager.shared.addImage(nsImage: img, data: pngData)
                    }
                    return
                }
            }
        }

        // 4. Check for Copied Image Files (from Finder or Desktop)
        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let firstURL = fileURLs.first {
            let ext = firstURL.pathExtension.lowercased()
            let imageExtensions = ["png", "jpg", "jpeg", "webp", "gif", "tiff", "heic", "bmp"]
            if imageExtensions.contains(ext),
               let img = NSImage(contentsOf: firstURL),
               let data = try? Data(contentsOf: firstURL) {
                // If it's a valid image file, capture as image
                let rep = NSBitmapImageRep(data: data)
                let pngData = rep?.representation(using: .png, properties: [:]) ?? data
                DispatchQueue.main.async {
                    ClipboardManager.shared.addImage(nsImage: img, data: pngData)
                }
                return
            }
        }

        // 5. Fallback to Text
        if let string = pasteboard.string(forType: .string) {
            DispatchQueue.main.async {
                ClipboardManager.shared.add(text: string)
            }
        }
    }
}
