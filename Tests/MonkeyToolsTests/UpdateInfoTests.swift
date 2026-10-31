import XCTest
@testable import MonkeyTools

final class UpdateInfoTests: XCTestCase {
    func testSemverComparison() {
        XCTAssertTrue(UpdateInfo.isVersion("2.1.1", newerThan: "2.1.0"))
        XCTAssertTrue(UpdateInfo.isVersion("v2.2.0", newerThan: "2.1.0"))
        XCTAssertTrue(UpdateInfo.isVersion("3.0.0", newerThan: "v2.1.0"))
        XCTAssertFalse(UpdateInfo.isVersion("2.1.0", newerThan: "2.1.0"))
        XCTAssertFalse(UpdateInfo.isVersion("2.0.1", newerThan: "2.1.0"))
        XCTAssertFalse(UpdateInfo.isVersion("2.1", newerThan: "2.1.0"))
        XCTAssertTrue(UpdateInfo.isVersion("2.1.1", newerThan: "2.1"))
    }

    func testUpdateInfoJSONDecoding() throws {
        let json = """
        {
            "latestVersion": "2.2.0",
            "releaseDate": "2026-11-01",
            "downloadUrl": "https://pakkawatkh.github.io/tiffy-app/monkey-tools/monkey-tools-Installer.dmg",
            "pageUrl": "https://pakkawatkh.github.io/tiffy-app/monkey-tools/",
            "releaseNotes": "Bug fixes and improvements"
        }
        """.data(using: .utf8)!

        let info = try JSONDecoder().decode(UpdateInfo.self, from: json)
        XCTAssertEqual(info.latestVersion, "2.2.0")
        XCTAssertEqual(info.releaseDate, "2026-11-01")
        XCTAssertEqual(info.downloadUrl, "https://pakkawatkh.github.io/tiffy-app/monkey-tools/monkey-tools-Installer.dmg")
    }
}
