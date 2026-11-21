import Foundation
import Combine

public final class UpdateCheckService: ObservableObject {
    public static let shared = UpdateCheckService()

    private enum Keys {
        static let lastUpdateCheckDate = "app_last_update_check_date"
    }

    public static let primaryManifestURL = URL(string: "https://pakkawatkh.github.io/tiffy-app/monkey-tools/version.json")!
    public static let fallbackManifestURL = URL(string: "https://raw.githubusercontent.com/pakkawatkh/tiffy-app/main/monkey-tools/version.json")!

    @Published public private(set) var isChecking: Bool = false
    @Published public private(set) var updateAvailable: Bool = false
    @Published public private(set) var latestUpdateInfo: UpdateInfo? = nil
    @Published public private(set) var lastCheckDate: Date? = nil
    @Published public private(set) var checkErrorMessage: String? = nil

    public var currentAppVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.1.10"
    }

    public init() {
        self.lastCheckDate = UserDefaults.standard.object(forKey: Keys.lastUpdateCheckDate) as? Date
    }

    public func shouldCheck(now: Date = Date(), lastCheck: Date?) -> Bool {
        guard let last = lastCheck else { return true }
        // 24 hours = 86,400 seconds
        return now.timeIntervalSince(last) >= 86400
    }

    public func checkForUpdates(force: Bool = false, completion: ((Bool) -> Void)? = nil) {
        let now = Date()
        if !force && !shouldCheck(now: now, lastCheck: lastCheckDate) {
            completion?(updateAvailable)
            return
        }

        guard !isChecking else {
            completion?(updateAvailable)
            return
        }

        isChecking = true
        checkErrorMessage = nil

        fetchManifest(from: Self.primaryManifestURL) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let info):
                self.handleSuccessfulUpdateInfo(info, checkDate: now)
                completion?(self.updateAvailable)
            case .failure:
                // Try fallback
                self.fetchManifest(from: Self.fallbackManifestURL) { [weak self] fallbackResult in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        self.isChecking = false
                        switch fallbackResult {
                        case .success(let info):
                            self.handleSuccessfulUpdateInfo(info, checkDate: now)
                            completion?(self.updateAvailable)
                        case .failure(let error):
                            self.checkErrorMessage = error.localizedDescription
                            completion?(false)
                        }
                    }
                }
            }
        }
    }

    private func handleSuccessfulUpdateInfo(_ info: UpdateInfo, checkDate: Date) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isChecking = false
            self.lastCheckDate = checkDate
            UserDefaults.standard.set(checkDate, forKey: Keys.lastUpdateCheckDate)

            self.latestUpdateInfo = info
            self.updateAvailable = UpdateInfo.isVersion(info.latestVersion, newerThan: self.currentAppVersion)
        }
    }

    private func fetchManifest(from url: URL, completion: @escaping (Result<UpdateInfo, Error>) -> Void) {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 10.0

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(URLError(.badServerResponse)))
                return
            }

            do {
                let info = try JSONDecoder().decode(UpdateInfo.self, from: data)
                completion(.success(info))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
