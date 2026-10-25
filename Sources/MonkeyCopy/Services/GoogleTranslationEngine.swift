import Foundation

public final class GoogleTranslationEngine: TranslationEngine {
    public let mode: TranslationEngineMode = .google

    public init() {}

    public func makeTranslateURL(text: String, from sourceLang: String = "auto", to targetLang: String) -> URL? {
        guard let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        let urlString = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=\(sourceLang)&tl=\(targetLang)&dt=t&q=\(encodedText)"
        return URL(string: urlString)
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

    public func translate(text: String, from sourceLang: String? = nil, to targetLang: String) async throws -> TranslationResult {
        let source = sourceLang ?? "auto"
        guard let url = makeTranslateURL(text: text, from: source, to: targetLang) else {
            throw NSError(domain: "GoogleTranslationEngine", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot construct URL"])
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8.0
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "GoogleTranslationEngine", code: 4, userInfo: [NSLocalizedDescriptionKey: "Server error or no internet connection"])
        }

        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "GoogleTranslationEngine", code: 5, userInfo: [NSLocalizedDescriptionKey: "Cannot decode response"])
        }

        return try parseResponse(jsonString: jsonString, originalText: text, targetLang: targetLang)
    }
}
