import Foundation
import Combine
import AppKit

public final class UpdateInstallerService: NSObject, ObservableObject, URLSessionDownloadDelegate {
    public static let shared = UpdateInstallerService()

    @Published public var downloadProgress: Double = 0.0
    @Published public var isInstalling: Bool = false
    @Published public var installStatusText: String = ""
    @Published public var installError: String? = nil

    private var downloadTask: URLSessionDownloadTask?
    private var session: URLSession?
    private var activeCompletion: ((Result<Void, Error>) -> Void)?
    private var updateInfo: UpdateInfo?

    public override init() {
        super.init()
    }

    public func resolveTargetAppPath() -> String {
        let bundlePath = Bundle.main.bundleURL.path
        if bundlePath.hasSuffix(".app") {
            return bundlePath
        }
        return "/Applications/monkey-tools.app"
    }

    public func generateRelaunchScript(
        currentPID: Int32,
        targetAppPath: String,
        newAppPath: String,
        cleanupDir: String
    ) -> String {
        return """
        #!/bin/bash
        while kill -0 \(currentPID) 2>/dev/null; do sleep 0.1; done
        rm -rf "\(targetAppPath)"
        cp -R "\(newAppPath)" "\(targetAppPath)"
        xattr -d -r com.apple.quarantine "\(targetAppPath)" 2>/dev/null || true
        open "\(targetAppPath)"
        rm -rf "\(cleanupDir)"
        """
    }

    public func startUpdate(with info: UpdateInfo, completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard !isInstalling else { return }

        guard let targetURL = info.preferredDownloadURL else {
            let err = NSError(domain: "UpdateInstallerService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid download URL"])
            self.installError = err.localizedDescription
            completion?(.failure(err))
            return
        }

        self.isInstalling = true
        self.downloadProgress = 0.0
        self.installError = nil
        self.installStatusText = LocalizationManager.shared["update_downloading"]
        self.updateInfo = info
        self.activeCompletion = completion

        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
        self.session = session

        var request = URLRequest(url: targetURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 60.0

        let task = session.downloadTask(with: request)
        self.downloadTask = task
        task.resume()
    }

    public func cancelUpdate() {
        downloadTask?.cancel()
        downloadTask = nil
        session?.invalidateAndCancel()
        session = nil
        isInstalling = false
        downloadProgress = 0.0
        installStatusText = ""
    }

    // MARK: - URLSessionDownloadDelegate

    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        if totalBytesExpectedToWrite > 0 {
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            DispatchQueue.main.async {
                self.downloadProgress = min(1.0, max(0.0, progress))
            }
        }
    }

    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // MUST copy file synchronously before this delegate method returns,
        // because URLSession purges the temporary file at `location` immediately upon return!
        let fileManager = FileManager.default
        let updateUUID = UUID().uuidString
        let tempWorkingDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("monkey-tools-update-\(updateUUID)")

        do {
            try fileManager.createDirectory(at: tempWorkingDir, withIntermediateDirectories: true)
            let isZip = updateInfo?.preferredDownloadURL?.pathExtension.lowercased() == "zip"
            let stagedPayload = tempWorkingDir.appendingPathComponent(isZip ? "payload.zip" : "payload.dmg")
            try fileManager.copyItem(at: location, to: stagedPayload)

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                self.processDownloadedPayload(at: stagedPayload, workingDir: tempWorkingDir, isZip: isZip)
            }
        } catch {
            failWithError(error)
        }
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error = error {
            failWithError(error)
        }
    }

    // MARK: - Payload Extraction & Installation

    private func processDownloadedPayload(at payloadFile: URL, workingDir: URL, isZip: Bool) {
        DispatchQueue.main.async {
            self.installStatusText = LocalizationManager.shared["update_extracting"]
        }

        let fileManager = FileManager.default
        var extractedAppPath: String?

        if isZip {
            let success = extractZip(at: payloadFile.path, destination: workingDir.path)
            if success {
                extractedAppPath = workingDir.appendingPathComponent("monkey-tools.app").path
            }
        } else {
            // DMG Fallback
            extractedAppPath = extractDmg(at: payloadFile.path, destinationDir: workingDir)
        }

        guard let finalAppPath = extractedAppPath, fileManager.fileExists(atPath: finalAppPath) else {
            let err = NSError(domain: "UpdateInstallerService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to extract valid monkey-tools.app bundle"])
            failWithError(err)
            return
        }

        // Verify executable inside bundle
        let execPath = (finalAppPath as NSString).appendingPathComponent("Contents/MacOS/monkey-tools")
        guard fileManager.isExecutableFile(atPath: execPath) else {
            let err = NSError(domain: "UpdateInstallerService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Extracted app has no executable"])
            failWithError(err)
            return
        }

        DispatchQueue.main.async {
            self.installStatusText = LocalizationManager.shared["update_relaunching"]
        }

        // Relaunch
        let targetAppPath = resolveTargetAppPath()
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let script = generateRelaunchScript(
            currentPID: currentPID,
            targetAppPath: targetAppPath,
            newAppPath: finalAppPath,
            cleanupDir: workingDir.path
        )

        let scriptURL = workingDir.appendingPathComponent("relaunch.sh")
        do {
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        } catch {
            failWithError(error)
            return
        }

        // Launch detached script
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/bash")
        proc.arguments = [scriptURL.path]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice

        do {
            try proc.run()
        } catch {
            failWithError(error)
            return
        }

        DispatchQueue.main.async {
            self.activeCompletion?(.success(()))
            // Terminate current app to let script swap bundle and relaunch
            NSApp.terminate(nil)
        }
    }

    private func extractZip(at zipPath: String, destination: String) -> Bool {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        proc.arguments = ["-xk", zipPath, destination]
        do {
            try proc.run()
            proc.waitUntilExit()
            return proc.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func extractDmg(at dmgPath: String, destinationDir: URL) -> String? {
        let mountPoint = destinationDir.appendingPathComponent("dmg_mount")
        try? FileManager.default.createDirectory(at: mountPoint, withIntermediateDirectories: true)

        let attachProc = Process()
        attachProc.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        attachProc.arguments = ["attach", "-nobrowse", "-readonly", dmgPath, "-mountpoint", mountPoint.path]
        do {
            try attachProc.run()
            attachProc.waitUntilExit()
            guard attachProc.terminationStatus == 0 else { return nil }
        } catch {
            return nil
        }

        defer {
            let detachProc = Process()
            detachProc.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            detachProc.arguments = ["detach", mountPoint.path, "-force"]
            try? detachProc.run()
            detachProc.waitUntilExit()
        }

        let mountedApp = mountPoint.appendingPathComponent("monkey-tools.app")
        let extractedApp = destinationDir.appendingPathComponent("monkey-tools.app")

        if FileManager.default.fileExists(atPath: mountedApp.path) {
            let cpProc = Process()
            cpProc.executableURL = URL(fileURLWithPath: "/bin/cp")
            cpProc.arguments = ["-R", mountedApp.path, extractedApp.path]
            try? cpProc.run()
            cpProc.waitUntilExit()
            return extractedApp.path
        }

        return nil
    }

    private func failWithError(_ error: Error) {
        DispatchQueue.main.async {
            self.isInstalling = false
            self.installError = error.localizedDescription
            self.installStatusText = LocalizationManager.shared["update_failed"]
            self.activeCompletion?(.failure(error))
        }
    }
}
