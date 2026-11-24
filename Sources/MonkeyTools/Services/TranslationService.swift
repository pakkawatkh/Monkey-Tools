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

    public static let maxPreTranslationLength = 4000

    private let googleEngine = GoogleTranslationEngine()
    private let appleEngine = AppleNativeTranslationEngine()
    private let historyKey = "monkey_translation_history_v1"
    private let maxHistoryItems = 25

    private var cache = [String: TranslationResult]()
    private var prefetchTask: Task<TranslationResult, Error>?
    private var prefetchKey: String?
    private var prefetchResult: TranslationResult?
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

    private func makeCacheKey(text: String, mode: TranslationEngineMode, sourceLang: String, targetLang: String) -> String {
        let resolvedSource = sourceLang.isEmpty ? "auto" : sourceLang
        return "\(mode.rawValue):\(resolvedSource):\(targetLang):\(text)"
    }

    /// Lightweight background pre-translation triggered while the floating bubble is visible.
    /// Waits a short settle delay (180ms) before hitting the network so quick copy-paste or accidental highlights
    /// cancel before sending any request, and caps text length to protect bandwidth/CPU.
    public func startPreTranslation(
        for text: String,
        mode: TranslationEngineMode,
        sourceLang: String = "auto",
        preferredTarget: String = "auto",
        settleDelayNanoseconds: UInt64 = 180_000_000
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= Self.maxPreTranslationLength else {
            cancelPreTranslation(clearCachedEntry: false)
            return
        }

        let resolvedTarget = resolveTargetLanguage(for: trimmed, preferredTarget: preferredTarget)
        let resolvedSource = sourceLang.isEmpty ? "auto" : sourceLang
        let key = makeCacheKey(text: trimmed, mode: mode, sourceLang: resolvedSource, targetLang: resolvedTarget)

        let existingTaskToCancel: Task<TranslationResult, Error>? = lock.withLock {
            // Already prefetching or holding result for this exact key
            if prefetchKey == key && (prefetchResult != nil || prefetchTask != nil) {
                return nil
            }
            let oldTask = prefetchTask
            prefetchTask = nil
            prefetchKey = key
            prefetchResult = cache[key]
            return oldTask
        }
        existingTaskToCancel?.cancel()

        // If already cached, no background task needed
        let alreadyReady = lock.withLock { prefetchKey == key && prefetchResult != nil }
        if alreadyReady {
            return
        }

        let selectedEngine = engine(for: mode)
        let task = Task<TranslationResult, Error>(priority: .utility) { [weak self] in
            if settleDelayNanoseconds > 0 {
                try await Task.sleep(nanoseconds: settleDelayNanoseconds)
            }
            try Task.checkCancellation()

            let result = try await selectedEngine.translate(text: trimmed, from: resolvedSource, to: resolvedTarget)
            try Task.checkCancellation()

            guard let strongSelf = self else { return result }
            strongSelf.lock.withLock {
                if strongSelf.prefetchKey == key {
                    strongSelf.prefetchResult = result
                    strongSelf.prefetchTask = nil
                }
            }
            return result
        }

        lock.withLock {
            if prefetchKey == key && prefetchResult == nil {
                prefetchTask = task
            } else {
                task.cancel()
            }
        }
    }

    /// Consumes an already-finished pre-translation (instant 0ms result) or hands over the matching
    /// in-flight prefetch task so the popover never sends a duplicate network request.
    public func consumePreTranslation(
        for text: String,
        mode: TranslationEngineMode,
        sourceLang: String = "auto",
        targetLang: String
    ) -> (result: TranslationResult?, inFlightTask: Task<TranslationResult, Error>?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (nil, nil) }

        let resolvedTarget = resolveTargetLanguage(for: trimmed, preferredTarget: targetLang)
        let resolvedSource = sourceLang.isEmpty ? "auto" : sourceLang
        let key = makeCacheKey(text: trimmed, mode: mode, sourceLang: resolvedSource, targetLang: resolvedTarget)

        return lock.withLock {
            if let cached = cache[key] {
                if prefetchKey == key {
                    prefetchResult = nil
                    prefetchTask = nil
                    prefetchKey = nil
                }
                return (cached, nil)
            }

            guard prefetchKey == key else {
                return (nil, nil)
            }

            if let ready = prefetchResult {
                // Promote to regular cache now that the user explicitly opened translation
                if cache.count > 100 {
                    cache.removeAll()
                }
                cache[key] = ready
                prefetchResult = nil
                prefetchTask = nil
                prefetchKey = nil
                return (ready, nil)
            }

            if let task = prefetchTask {
                prefetchTask = nil
                prefetchKey = nil
                return (nil, task)
            }

            return (nil, nil)
        }
    }

    /// Immediately cancels any active background pre-translation and clears its temporary state.
    /// Called whenever the floating bubble disappears without the user clicking Translate.
    public func cancelPreTranslation(clearCachedEntry: Bool = false) {
        let taskToCancel: Task<TranslationResult, Error>? = lock.withLock {
            let task = prefetchTask
            if clearCachedEntry, let key = prefetchKey {
                cache.removeValue(forKey: key)
            }
            prefetchTask = nil
            prefetchKey = nil
            prefetchResult = nil
            return task
        }
        taskToCancel?.cancel()
    }

    public var hasActivePreTranslation: Bool {
        lock.withLock {
            prefetchTask != nil || prefetchResult != nil || prefetchKey != nil
        }
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
        let cacheKey = makeCacheKey(text: trimmed, mode: mode, sourceLang: resolvedSource, targetLang: resolvedTarget)

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
        let taskToCancel: Task<TranslationResult, Error>? = lock.withLock {
            cache.removeAll()
            let task = prefetchTask
            prefetchTask = nil
            prefetchKey = nil
            prefetchResult = nil
            return task
        }
        taskToCancel?.cancel()
    }
}
