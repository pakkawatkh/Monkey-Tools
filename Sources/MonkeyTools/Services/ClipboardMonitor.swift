import AppKit
import Combine
import Foundation

public final class ClipboardMonitor: ObservableObject {
    public static let shared = ClipboardMonitor()

    @Published public var isPaused: Bool = false

    private let pasteboard = NSPasteboard.general
    public var lastChangeCount: Int
    public var isCapturingSuppressed: Bool = false
    private var timer: Timer?
    private var lastProgrammaticString: String?
    private var isProgrammaticImageWrite = false

    public init() {
        self.lastChangeCount = pasteboard.changeCount
    }

    public func togglePause() {
        isPaused.toggle()
        if !isPaused {
            lastChangeCount = pasteboard.changeCount
        }
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

        // Ignore if paused by user or temporarily suppressed for translation probe
        if isPaused || isCapturingSuppressed {
            return
        }

        // Capture frontmost application metadata
        let frontApp = NSWorkspace.shared.frontmostApplication
        let sourceBundleID = frontApp?.bundleIdentifier
        let sourceAppName = frontApp?.localizedName

        // Ignore if frontmost app is in user's excluded list
        if let frontAppId = sourceBundleID {
            if AppSettings.shared.excludedAppBundleIDs.contains(frontAppId) {
                return
            }
        }

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
                        ClipboardManager.shared.addImage(nsImage: img, data: pngData, sourceAppBundleID: sourceBundleID, sourceAppName: sourceAppName)
                    }
                    return
                } else if let tiffData = pasteboard.data(forType: .tiff), let img = NSImage(data: tiffData) {
                    // Convert TIFF to PNG data for lightweight storage
                    let rep = NSBitmapImageRep(data: tiffData)
                    let pngData = rep?.representation(using: .png, properties: [:]) ?? tiffData
                    DispatchQueue.main.async {
                        ClipboardManager.shared.addImage(nsImage: img, data: pngData, sourceAppBundleID: sourceBundleID, sourceAppName: sourceAppName)
                    }
                    return
                }
            }
        }

        // 4. Check for Copied Image Files (from Finder or Desktop) — encode off main thread to prevent UI stutter
        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let firstURL = fileURLs.first {
            let ext = firstURL.pathExtension.lowercased()
            let imageExtensions = ["png", "jpg", "jpeg", "webp", "gif", "tiff", "heic", "bmp"]
            if imageExtensions.contains(ext) {
                DispatchQueue.global(qos: .utility).async {
                    guard let data = try? Data(contentsOf: firstURL),
                          let img = NSImage(data: data) else { return }
                    let rep = NSBitmapImageRep(data: data)
                    let pngData = rep?.representation(using: .png, properties: [:]) ?? data
                    DispatchQueue.main.async {
                        ClipboardManager.shared.addImage(nsImage: img, data: pngData, sourceAppBundleID: sourceBundleID, sourceAppName: sourceAppName)
                    }
                }
                return
            }
        }

        // 5. Fallback to Text
        if let string = pasteboard.string(forType: .string) {
            DispatchQueue.main.async {
                ClipboardManager.shared.add(text: string, sourceAppBundleID: sourceBundleID, sourceAppName: sourceAppName)
            }
        }
    }
}
