import XCTest
@testable import MonkeyTools

final class NetworkSpeedUnitTests: XCTestCase {
    func testAutoBytesFormatting() {
        XCTAssertEqual(NetworkSpeedUnit.autoBytes.formatSpeed(bytesPerSec: 0), "0 B/s")
        XCTAssertEqual(NetworkSpeedUnit.autoBytes.formatSpeed(bytesPerSec: 512), "512 B/s")
        XCTAssertEqual(NetworkSpeedUnit.autoBytes.formatSpeed(bytesPerSec: 1024 * 1.5), "1.5 KB/s")
        XCTAssertEqual(NetworkSpeedUnit.autoBytes.formatSpeed(bytesPerSec: 1024 * 1024 * 2.4), "2.4 MB/s")
        XCTAssertEqual(NetworkSpeedUnit.autoBytes.formatSpeed(bytesPerSec: 1024 * 1024 * 1024 * 1.2), "1.2 GB/s")
    }

    func testBitsFormatting() {
        XCTAssertEqual(NetworkSpeedUnit.bits.formatSpeed(bytesPerSec: 0), "0 bps")
        XCTAssertEqual(NetworkSpeedUnit.bits.formatSpeed(bytesPerSec: 125), "1.0 Kbps") // 125 * 8 = 1000 bits
        XCTAssertEqual(NetworkSpeedUnit.bits.formatSpeed(bytesPerSec: 125_000), "1.0 Mbps")
    }

    func testFixedUnitsFormatting() {
        XCTAssertEqual(NetworkSpeedUnit.fixedKB.formatSpeed(bytesPerSec: 2048), "2.0 KB/s")
        XCTAssertEqual(NetworkSpeedUnit.fixedMB.formatSpeed(bytesPerSec: 2_097_152), "2.00 MB/s")
    }

    func testCumulativeDataSizeFormatting() {
        XCTAssertEqual(NetworkSpeedUnit.formatDataSize(bytes: 0), "0 B")
        XCTAssertEqual(NetworkSpeedUnit.formatDataSize(bytes: 1024 * 500), "500 KB")
        XCTAssertEqual(NetworkSpeedUnit.formatDataSize(bytes: 1024 * 1024 * 150), "150 MB")
        XCTAssertEqual(NetworkSpeedUnit.formatDataSize(bytes: 1024 * 1024 * 1024 * 3), "3.0 GB")
    }
}
