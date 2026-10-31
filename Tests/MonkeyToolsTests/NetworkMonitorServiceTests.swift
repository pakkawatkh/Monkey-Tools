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
