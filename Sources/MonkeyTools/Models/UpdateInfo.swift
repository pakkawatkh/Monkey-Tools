import Foundation

public struct UpdateInfo: Codable, Equatable {
    public let latestVersion: String
    public let releaseDate: String
    public let downloadUrl: String
    public let zipUrl: String?
    public let pageUrl: String?
    public let releaseNotes: String

    public var preferredDownloadURL: URL? {
        if let zip = zipUrl, let url = URL(string: zip) {
            return url
        }
        return URL(string: downloadUrl)
    }

    public init(
        latestVersion: String,
        releaseDate: String,
        downloadUrl: String,
        zipUrl: String? = nil,
        pageUrl: String? = nil,
        releaseNotes: String
    ) {
        self.latestVersion = latestVersion
        self.releaseDate = releaseDate
        self.downloadUrl = downloadUrl
        self.zipUrl = zipUrl
        self.pageUrl = pageUrl
        self.releaseNotes = releaseNotes
    }

    public static func isVersion(_ remote: String, newerThan local: String) -> Bool {
        let cleanRemote = remote.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
        let cleanLocal = local.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))

        let vRemote = cleanRemote.split(separator: ".").compactMap { Int($0) }
        let vLocal = cleanLocal.split(separator: ".").compactMap { Int($0) }

        let maxCount = max(vRemote.count, vLocal.count)
        guard maxCount > 0 else { return false }

        for i in 0..<maxCount {
            let r = i < vRemote.count ? vRemote[i] : 0
            let l = i < vLocal.count ? vLocal[i] : 0
            if r > l { return true }
            if r < l { return false }
        }
        return false
    }
}
