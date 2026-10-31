import Foundation

public enum NetworkSpeedUnit: String, CaseIterable, Identifiable {
    case autoBytes = "auto_bytes"
    case bits = "bits"
    case fixedKB = "fixed_kb"
    case fixedMB = "fixed_mb"

    public var id: String { rawValue }

    public func formatSpeed(bytesPerSec: Double) -> String {
        let safeRate = max(0, bytesPerSec)

        switch self {
        case .autoBytes:
            if safeRate < 1024 {
                return String(format: "%.0f B/s", safeRate)
            } else if safeRate < 1024 * 1024 {
                return String(format: "%.1f KB/s", safeRate / 1024.0)
            } else if safeRate < 1024 * 1024 * 1024 {
                return String(format: "%.1f MB/s", safeRate / (1024.0 * 1024.0))
            } else {
                return String(format: "%.1f GB/s", safeRate / (1024.0 * 1024.0 * 1024.0))
            }

        case .bits:
            let bitsPerSec = safeRate * 8.0
            if bitsPerSec < 1000 {
                return String(format: "%.0f bps", bitsPerSec)
            } else if bitsPerSec < 1_000_000 {
                return String(format: "%.1f Kbps", bitsPerSec / 1000.0)
            } else if bitsPerSec < 1_000_000_000 {
                return String(format: "%.1f Mbps", bitsPerSec / 1_000_000.0)
            } else {
                return String(format: "%.1f Gbps", bitsPerSec / 1_000_000_000.0)
            }

        case .fixedKB:
            return String(format: "%.1f KB/s", safeRate / 1024.0)

        case .fixedMB:
            return String(format: "%.2f MB/s", safeRate / (1024.0 * 1024.0))
        }
    }

    public static func formatDataSize(bytes: UInt64) -> String {
        let d = Double(bytes)
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.0f KB", d / 1024.0)
        } else if bytes < 1024 * 1024 * 1024 {
            return String(format: "%.0f MB", d / (1024.0 * 1024.0))
        } else {
            return String(format: "%.1f GB", d / (1024.0 * 1024.0 * 1024.0))
        }
    }
}
