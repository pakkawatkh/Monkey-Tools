import XCTest
@testable import MonkeyTools

final class UpdateInstallerServiceTests: XCTestCase {
    func testGenerateRelaunchScriptContainsExpectedCommands() {
        let service = UpdateInstallerService.shared
        let script = service.generateRelaunchScript(
            currentPID: 12345,
            targetAppPath: "/Applications/monkey-tools.app",
            newAppPath: "/tmp/monkey-tools-update/monkey-tools.app",
            cleanupDir: "/tmp/monkey-tools-update"
        )

        // Script must check for PID exit
        XCTAssertTrue(script.contains("while kill -0 12345 2>/dev/null; do sleep 0.1; done"))
        // Script must remove old app and copy new app
        XCTAssertTrue(script.contains("rm -rf \"/Applications/monkey-tools.app\""))
        XCTAssertTrue(script.contains("cp -R \"/tmp/monkey-tools-update/monkey-tools.app\" \"/Applications/monkey-tools.app\""))
        // Script must clear quarantine
        XCTAssertTrue(script.contains("xattr -d -r com.apple.quarantine \"/Applications/monkey-tools.app\" 2>/dev/null || true"))
        // Script must open new app
        XCTAssertTrue(script.contains("open \"/Applications/monkey-tools.app\""))
        // Script must clean up temporary dir
        XCTAssertTrue(script.contains("rm -rf \"/tmp/monkey-tools-update\""))
    }

    func testResolveTargetAppPathFallsBackToApplications() {
        let service = UpdateInstallerService.shared
        let targetPath = service.resolveTargetAppPath()
        XCTAssertFalse(targetPath.isEmpty)
        XCTAssertTrue(targetPath.hasSuffix(".app"))
    }
}
