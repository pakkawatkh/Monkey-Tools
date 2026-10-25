import Foundation
import os

public final class TranslationService: ObservableObject {
    public static let shared = TranslationService()

    private let googleEngine = GoogleTranslationEngine()
    private let appleEngine = AppleNativeTranslationEngine()

    private var cache = [String: TranslationResult]()
    private let lock = OSAllocatedUnfairLock()

    private init() {}

    public func engine(for mode: TranslationEngineMode) -> TranslationEngine {
        switch mode {
        case .google:
            return googleEngine
        case .appleNative:
            return appleEngine
        }
    }

    /// Auto-detects target language: if preferredTarget is specified, uses it (unless source is identical pure language, e.g. Thai -> English); otherwise uses majority script detection.
    public func resolveTargetLanguage(for text: String, preferredTarget: String = "auto") -> String {
        var thaiCount = 0
        var latinCount = 0
        for scalar in text.unicodeScalars {
            if scalar.value >= 0x0E00 && scalar.value <= 0x0E7F {
                thaiCount += 1
            } else if CharacterSet.letters.contains(scalar) {
                latinCount += 1
            }
        }

        if preferredTarget != "auto" && !preferredTarget.isEmpty {
            // If user explicitly chose Thai ("th") as target, but the text is pure Thai, target English instead of Thai -> Thai
            if preferredTarget == "th" && thaiCount > 0 && latinCount == 0 {
                return "en"
            }
            // If user explicitly chose English ("en") as target, but the text is pure English, target Thai instead of English -> English
            if preferredTarget == "en" && latinCount > 0 && thaiCount == 0 {
                return "th"
            }
            return preferredTarget
        }

        return thaiCount > latinCount ? "en" : "th"
    }

    public func translate(
        text: String,
        mode: TranslationEngineMode = .google,
        sourceLang: String = "auto",
        targetLang: String = "auto"
    ) async throws -> TranslationResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(domain: "TranslationService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Text is empty"])
        }

        let resolvedTarget = resolveTargetLanguage(for: trimmed, preferredTarget: targetLang)
        let resolvedSource = sourceLang.isEmpty ? "auto" : sourceLang
        let cacheKey = "\(mode.rawValue):\(resolvedSource):\(resolvedTarget):\(trimmed)"

        let cachedResult = lock.withLock {
            cache[cacheKey]
        }
        if let cached = cachedResult {
            return cached
        }

        let selectedEngine = engine(for: mode)
        let result = try await selectedEngine.translate(text: trimmed, from: resolvedSource, to: resolvedTarget)

        lock.withLock {
            if cache.count > 100 {
                cache.removeAll()
            }
            cache[cacheKey] = result
        }

        return result
    }

    public func clearCache() {
        lock.withLock {
            cache.removeAll()
        }
    }
}
