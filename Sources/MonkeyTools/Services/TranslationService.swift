import Foundation
import os

public struct TranslationHistoryItem: Identifiable, Codable, Equatable {
    public let id: UUID
    public let originalText: String
    public let translatedText: String
    public let sourceLanguage: String
    public let targetLanguage: String
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        originalText: String,
        translatedText: String,
        sourceLanguage: String,
        targetLanguage: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.originalText = originalText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.timestamp = timestamp
    }
}

public final class TranslationService: ObservableObject {
    public static let shared = TranslationService()

    @Published public private(set) var history: [TranslationHistoryItem] = []

    private let googleEngine = GoogleTranslationEngine()
    private let appleEngine = AppleNativeTranslationEngine()
    private let historyKey = "monkey_translation_history_v1"
    private let maxHistoryItems = 25

    private var cache = [String: TranslationResult]()
    private let lock = OSAllocatedUnfairLock()

    private init() {
        loadHistory()
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let decoded = try? JSONDecoder().decode([TranslationHistoryItem].self, from: data) else {
            return
        }
        self.history = decoded
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    public func recordHistory(_ result: TranslationResult) {
        let orig = result.originalText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trans = result.translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !orig.isEmpty, !trans.isEmpty else { return }

        let entry = TranslationHistoryItem(
            originalText: orig,
            translatedText: trans,
            sourceLanguage: result.sourceLanguage,
            targetLanguage: result.targetLanguage
        )

        let updateBlock = { [weak self] in
            guard let self = self else { return }
            self.history.removeAll { $0.originalText == orig && $0.targetLanguage == result.targetLanguage }
            self.history.insert(entry, at: 0)
            if self.history.count > self.maxHistoryItems {
                self.history = Array(self.history.prefix(self.maxHistoryItems))
            }
            self.saveHistory()
        }

        if Thread.isMainThread {
            updateBlock()
        } else {
            DispatchQueue.main.async(execute: updateBlock)
        }
    }

    public func clearHistory() {
        let clearBlock = { [weak self] in
            guard let self = self else { return }
            self.history.removeAll()
            UserDefaults.standard.removeObject(forKey: self.historyKey)
        }
        if Thread.isMainThread {
            clearBlock()
        } else {
            DispatchQueue.main.async(execute: clearBlock)
        }
    }

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
