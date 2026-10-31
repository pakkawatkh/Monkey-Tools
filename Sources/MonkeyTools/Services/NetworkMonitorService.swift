import Foundation
import Combine
import Darwin

public final class NetworkMonitorService: ObservableObject {
    public static let shared = NetworkMonitorService()

    @Published public private(set) var downloadSpeed: Double = 0
    @Published public private(set) var uploadSpeed: Double = 0
    @Published public private(set) var sessionDownloadBytes: UInt64 = 0
    @Published public private(set) var sessionUploadBytes: UInt64 = 0
    @Published public private(set) var formattedSpeedString: String = ""
    @Published public private(set) var isMonitoring: Bool = false

    public var currentUnit: NetworkSpeedUnit = .autoBytes {
        didSet {
            refreshFormatting()
        }
    }

    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.monkeytools.networkmonitor", qos: .utility)
    private var previousInBytes: UInt64 = 0
    private var previousOutBytes: UInt64 = 0
    private var lastSampleTime: Date?

    public init() {}

    public func sampleInterfaceBytes() -> (ibytes: UInt64, obytes: UInt64) {
        var ifap: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifap) == 0, let first = ifap else {
            return (0, 0)
        }
        defer { freeifaddrs(ifap) }

        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0

        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let current = cursor {
            let ifa = current.pointee
            let flags = Int32(ifa.ifa_flags)
            // Interface must be up and running, but not loopback
            if (flags & IFF_UP) != 0 && (flags & IFF_RUNNING) != 0 && (flags & IFF_LOOPBACK) == 0 {
                if let addr = ifa.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK) {
                    if let data = ifa.ifa_data {
                        let ifData = data.assumingMemoryBound(to: if_data.self)
                        totalIn += UInt64(ifData.pointee.ifi_ibytes)
                        totalOut += UInt64(ifData.pointee.ifi_obytes)
                    }
                }
            }
            cursor = ifa.ifa_next
        }

        return (totalIn, totalOut)
    }

    public func calculateRates(
        previousIn: UInt64, currentIn: UInt64,
        previousOut: UInt64, currentOut: UInt64,
        timeDelta: Double
    ) -> (downSpeed: Double, upSpeed: Double) {
        guard timeDelta > 0 else { return (0, 0) }

        let downDelta = (currentIn >= previousIn) ? (currentIn - previousIn) : 0
        let upDelta = (currentOut >= previousOut) ? (currentOut - previousOut) : 0

        let downRate = Double(downDelta) / timeDelta
        let upRate = Double(upDelta) / timeDelta

        return (downRate, upRate)
    }

    public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        let initial = sampleInterfaceBytes()
        previousInBytes = initial.ibytes
        previousOutBytes = initial.obytes
        lastSampleTime = Date()

        let timerSource = DispatchSource.makeTimerSource(queue: queue)
        timerSource.schedule(deadline: .now() + 1.0, repeating: 1.0)
        timerSource.setEventHandler { [weak self] in
            self?.tick()
        }
        timer = timerSource
        timerSource.resume()
    }

    public func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        timer?.cancel()
        timer = nil

        DispatchQueue.main.async { [weak self] in
            self?.downloadSpeed = 0
            self?.uploadSpeed = 0
            self?.formattedSpeedString = ""
        }
    }

    private func tick() {
        let current = sampleInterfaceBytes()
        let now = Date()
        let timeDelta = lastSampleTime.map { now.timeIntervalSince($0) } ?? 1.0

        let (downRate, upRate) = calculateRates(
            previousIn: previousInBytes, currentIn: current.ibytes,
            previousOut: previousOutBytes, currentOut: current.obytes,
            timeDelta: timeDelta
        )

        let downDelta = (current.ibytes >= previousInBytes) ? (current.ibytes - previousInBytes) : 0
        let upDelta = (current.obytes >= previousOutBytes) ? (current.obytes - previousOutBytes) : 0

        previousInBytes = current.ibytes
        previousOutBytes = current.obytes
        lastSampleTime = now

        let unit = currentUnit

        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isMonitoring else { return }
            self.downloadSpeed = downRate
            self.uploadSpeed = upRate
            self.sessionDownloadBytes += downDelta
            self.sessionUploadBytes += upDelta

            let downStr = unit.formatSpeed(bytesPerSec: downRate)
            let upStr = unit.formatSpeed(bytesPerSec: upRate)
            self.formattedSpeedString = "⬇ \(downStr)  ⬆ \(upStr)"
        }
    }

    public func refreshFormatting() {
        let unit = currentUnit
        let downStr = unit.formatSpeed(bytesPerSec: downloadSpeed)
        let upStr = unit.formatSpeed(bytesPerSec: uploadSpeed)
        self.formattedSpeedString = "⬇ \(downStr)  ⬆ \(upStr)"
    }
}
