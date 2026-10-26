import Foundation

public final class GoogleTranslationEngine: TranslationEngine {
    public let mode: TranslationEngineMode = .google

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8.0
        config.timeoutIntervalForResource = 12.0
        config.httpCookieAcceptPolicy = .never
        config.httpShouldSetCookies = false
        return URLSession(configuration: config)
    }()

    private let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

    public init() {}

    public func makeTranslateURL(text: String, from sourceLang: String = "auto", to targetLang: String) -> URL? {
        var components = URLComponents(string: "https://translate.googleapis.com/translate_a/single")
        components?.queryItems = [
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "sl", value: sourceLang),
            URLQueryItem(name: "tl", value: targetLang),
            URLQueryItem(name: "dt", value: "t"),
            URLQueryItem(name: "q", value: text)
        ]
        return components?.url
    }

    public func parseResponse(jsonString: String, originalText: String, targetLang: String) throws -> TranslationResult {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [Any] else {
            throw NSError(domain: "GoogleTranslationEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"])
        }

        var translatedText = ""
        if let segments = json.first as? [[Any]] {
            for segment in segments {
                if let part = segment.first as? String {
                    translatedText += part
                }
            }
        }

        if translatedText.isEmpty {
            throw NSError(domain: "GoogleTranslationEngine", code: 2, userInfo: [NSLocalizedDescriptionKey: "No translation found"])
        }

        let detectedSource = (json.count > 2 ? (json[2] as? String) : nil) ?? "auto"

        return TranslationResult(
            originalText: originalText,
            translatedText: translatedText,
            sourceLanguage: detectedSource,
            targetLanguage: targetLang,
            engineUsed: .google
        )
    }

    // TIER 1: Chrome Extension translation endpoint (highest reliability and rate limits)
    private func translateWithClients5(text: String, sourceLang: String, targetLang: String) async throws -> TranslationResult {
        var components = URLComponents(string: "https://clients5.google.com/translate_a/t")
        components?.queryItems = [
            URLQueryItem(name: "client", value: "dict-chrome-ex"),
            URLQueryItem(name: "sl", value: sourceLang),
            URLQueryItem(name: "tl", value: targetLang),
            URLQueryItem(name: "q", value: text)
        ]
        guard let url = components?.url else {
            throw NSError(domain: "GoogleTranslationEngine", code: 10, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 500
            throw NSError(domain: "GoogleTranslationEngine", code: status, userInfo: [NSLocalizedDescriptionKey: "Clients5 error \(status)"])
        }

        guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) else {
            throw NSError(domain: "GoogleTranslationEngine", code: 11, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON"])
        }

        var translated = ""
        var detectedSource = sourceLang

        if let array = jsonObject as? [[Any]] {
            for pair in array {
                if let part = pair.first as? String {
                    translated += part
                }
                if pair.count > 1, let src = pair[1] as? String, detectedSource == "auto" {
                    detectedSource = src
                }
            }
        } else if let array = jsonObject as? [Any] {
            if let first = array.first as? String {
                translated = first
            }
        }

        if translated.isEmpty {
            throw NSError(domain: "GoogleTranslationEngine", code: 12, userInfo: [NSLocalizedDescriptionKey: "Empty translation"])
        }

        return TranslationResult(
            originalText: text,
            translatedText: translated,
            sourceLanguage: detectedSource,
            targetLanguage: targetLang,
            engineUsed: .google
        )
    }

    // TIER 2: Google Translate Single endpoint (classic gtx)
    private func translateWithGtx(text: String, sourceLang: String, targetLang: String) async throws -> TranslationResult {
        guard let url = makeTranslateURL(text: text, from: sourceLang, to: targetLang) else {
            throw NSError(domain: "GoogleTranslationEngine", code: 20, userInfo: [NSLocalizedDescriptionKey: "Cannot construct URL"])
        }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 500
            throw NSError(domain: "GoogleTranslationEngine", code: status, userInfo: [NSLocalizedDescriptionKey: "GTX error \(status)"])
        }

        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "GoogleTranslationEngine", code: 21, userInfo: [NSLocalizedDescriptionKey: "Cannot decode response"])
        }

        return try parseResponse(jsonString: jsonString, originalText: text, targetLang: targetLang)
    }

    // TIER 3: MyMemory Fallback Translation (independent third-party service)
    private func translateWithMyMemory(text: String, sourceLang: String, targetLang: String) async throws -> TranslationResult {
        let src = (sourceLang == "auto" || sourceLang.isEmpty) ? "en" : sourceLang
        let pair = "\(src)|\(targetLang)"

        var components = URLComponents(string: "https://api.mymemory.translated.net/get")
        components?.queryItems = [
            URLQueryItem(name: "q", value: text),
            URLQueryItem(name: "langpair", value: pair)
        ]
        guard let url = components?.url else {
            throw NSError(domain: "GoogleTranslationEngine", code: 30, userInfo: [NSLocalizedDescriptionKey: "Invalid MyMemory URL"])
        }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 500
            throw NSError(domain: "GoogleTranslationEngine", code: status, userInfo: [NSLocalizedDescriptionKey: "MyMemory error \(status)"])
        }

        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let responseData = json["responseData"] as? [String: Any],
              let translatedText = responseData["translatedText"] as? String,
              !translatedText.isEmpty else {
            throw NSError(domain: "GoogleTranslationEngine", code: 31, userInfo: [NSLocalizedDescriptionKey: "No MyMemory translation"])
        }

        return TranslationResult(
            originalText: text,
            translatedText: translatedText,
            sourceLanguage: src,
            targetLanguage: targetLang,
            engineUsed: .google
        )
    }

    public func translate(text: String, from sourceLang: String? = nil, to targetLang: String) async throws -> TranslationResult {
        let source = sourceLang ?? "auto"

        // Attempt 1: Google Chrome Extension official translation endpoint
        do {
            return try await translateWithClients5(text: text, sourceLang: source, targetLang: targetLang)
        } catch {
            // Attempt 2: Fallback to Google GTX endpoint
            do {
                return try await translateWithGtx(text: text, sourceLang: source, targetLang: targetLang)
            } catch {
                // Attempt 3: Fallback to MyMemory translation
                do {
                    return try await translateWithMyMemory(text: text, sourceLang: source, targetLang: targetLang)
                } catch {
                    throw NSError(domain: "GoogleTranslationEngine", code: 4, userInfo: [NSLocalizedDescriptionKey: "Server error or no internet connection"])
                }
            }
        }
    }
}
