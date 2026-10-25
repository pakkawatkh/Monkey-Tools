import Foundation
import CoreServices

public final class AppleNativeTranslationEngine: TranslationEngine {
    public let mode: TranslationEngineMode = .appleNative

    private let fallbackGoogle = GoogleTranslationEngine()

    public init() {}

    public func lookupDictionary(term: String) -> String? {
        let range = CFRangeMake(0, term.utf16.count)
        guard let definition = DCSCopyTextDefinition(nil, term as CFString, range) else {
            return nil
        }
        let result = definition.takeRetainedValue() as String
        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public func translate(text: String, from sourceLang: String? = nil, to targetLang: String) async throws -> TranslationResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // For single words or short phrases, attempt native macOS Dictionary lookup first
        if trimmed.split(separator: " ").count <= 3, let dictResult = lookupDictionary(term: trimmed) {
            // Verify definition contains characters of the requested target language
            // If target is Thai ("th"), definition MUST contain Thai characters (from an EN-TH dictionary),
            // otherwise it is a monolingual English dictionary definition and should fall back to translator.
            let isValidForTarget: Bool
            if targetLang == "th" {
                isValidForTarget = dictResult.unicodeScalars.contains { $0.value >= 0x0E00 && $0.value <= 0x0E7F }
            } else if targetLang == "en" {
                isValidForTarget = dictResult.unicodeScalars.contains { CharacterSet.letters.contains($0) }
            } else {
                isValidForTarget = true
            }

            if isValidForTarget {
                let lines = dictResult.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                let summary = lines.prefix(3).joined(separator: "\n")
                return TranslationResult(
                    originalText: text,
                    translatedText: summary,
                    sourceLanguage: sourceLang ?? "en",
                    targetLanguage: targetLang,
                    engineUsed: .appleNative
                )
            }
        }

        // For longer sentences or if bilingual dictionary is not downloaded in macOS Settings,
        // use fallback translator while labeling the engine mode
        do {
            let res = try await fallbackGoogle.translate(text: text, from: sourceLang, to: targetLang)
            return TranslationResult(
                originalText: res.originalText,
                translatedText: res.translatedText,
                sourceLanguage: res.sourceLanguage,
                targetLanguage: res.targetLanguage,
                engineUsed: .appleNative
            )
        } catch {
            throw error
        }
    }
}
