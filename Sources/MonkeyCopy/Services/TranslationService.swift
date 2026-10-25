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

    /// Auto-detects target language: if source contains Thai characters, targets English ("en"); otherwise targets Thai ("th").
    public func resolveTargetLanguage(for text: String, preferredTarget: String = "auto") -> String {
        if preferredTarget != "auto" && !preferredTarget.isEmpty {
            return preferredTarget
        }

        let hasThai = text.unicodeScalars.contains { scalar in
            scalar.value >= 0x0E00 && scalar.value <= 0x0E7F
        }

        return hasThai ? "en" : "th"
    }

    public func translate(
        text: String,
        mode: TranslationEngineMode = .google,
        targetLang: String = "auto"
    ) async throws -> TranslationResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(domain: "TranslationService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Text is empty"])
        }

        let resolvedTarget = resolveTargetLanguage(for: trimmed, preferredTarget: targetLang)
        let cacheKey = "\(mode.rawValue):\(resolvedTarget):\(trimmed)"

        let cachedResult = lock.withLock {
            cache[cacheKey]
        }
        if let cached = cachedResult {
            return cached
        }

        let selectedEngine = engine(for: mode)
        let result = try await selectedEngine.translate(text: trimmed, from: "auto", to: resolvedTarget)

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
