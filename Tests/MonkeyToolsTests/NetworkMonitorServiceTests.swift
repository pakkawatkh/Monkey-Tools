import XCTest
@testable import MonkeyTools

final class NetworkMonitorServiceTests: XCTestCase {
    func testCalculateRatesNormal() {
        let service = NetworkMonitorService()
        let rates = service.calculateRates(
            previousIn: 1_000_000, currentIn: 2_048_576,
            previousOut: 500_000, currentOut: 602_400,
            timeDelta: 1.0
        )
        XCTAssertEqual(rates.downSpeed, 1_048_576, accuracy: 1.0)
        XCTAssertEqual(rates.upSpeed, 102_400, accuracy: 1.0)
    }

    func testCalculateRatesWrapAroundOrReset() {
        let service = NetworkMonitorService()
        let rates = service.calculateRates(
            previousIn: 10_000_000, currentIn: 500,
            previousOut: 5_000_000, currentOut: 200,
            timeDelta: 1.0
        )
        XCTAssertEqual(rates.downSpeed, 0)
        XCTAssertEqual(rates.upSpeed, 0)
    }

    func testCalculateRatesLarge64BitValues() {
        let service = NetworkMonitorService()
        // 80 GB previously, 85 GB currently (5 GB downloaded over 2.0s = 2.5 GB/s)
        let eightyGB: UInt64 = 80 * 1024 * 1024 * 1024
        let eightyFiveGB: UInt64 = 85 * 1024 * 1024 * 1024
        let rates = service.calculateRates(
            previousIn: eightyGB, currentIn: eightyFiveGB,
            previousOut: 1_000_000_000, currentOut: 1_050_000_000,
            timeDelta: 2.0
        )
        XCTAssertEqual(rates.downSpeed, 2.5 * 1024 * 1024 * 1024, accuracy: 1.0)
        XCTAssertEqual(rates.upSpeed, 25_000_000, accuracy: 1.0)
    }

    func testSampleInterfaceBytesDoesNotCrash() {
        let service = NetworkMonitorService()
        let sample = service.sampleInterfaceBytes()
        XCTAssertGreaterThanOrEqual(sample.ibytes, 0)
        XCTAssertGreaterThanOrEqual(sample.obytes, 0)
    }

    func testStartAndStopMonitoringLifecycle() {
        let service = NetworkMonitorService()
        service.startMonitoring()
        XCTAssertTrue(service.isMonitoring)
        service.stopMonitoring()
        XCTAssertFalse(service.isMonitoring)
        XCTAssertEqual(service.downloadSpeed, 0)
        XCTAssertEqual(service.uploadSpeed, 0)
    }
}
