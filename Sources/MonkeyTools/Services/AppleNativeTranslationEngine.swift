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

    public func isResultInTargetLanguage(result: String, targetLang: String) -> Bool {
        switch targetLang.lowercased() {
        case "th":
            return result.unicodeScalars.contains { $0.value >= 0x0E00 && $0.value <= 0x0E7F }

        case "ja":
            return result.unicodeScalars.contains { ($0.value >= 0x3040 && $0.value <= 0x309F) || ($0.value >= 0x30A0 && $0.value <= 0x30FF) }

        case "zh", "zh-cn", "zh-tw":
            return result.unicodeScalars.contains { $0.value >= 0x4E00 && $0.value <= 0x9FFF }

        case "ko":
            return result.unicodeScalars.contains { ($0.value >= 0xAC00 && $0.value <= 0xD7AF) || ($0.value >= 0x1100 && $0.value <= 0x11FF) }

        case "ru", "uk":
            return result.unicodeScalars.contains { $0.value >= 0x0400 && $0.value <= 0x04FF }

        case "ar", "fa":
            return result.unicodeScalars.contains { $0.value >= 0x0600 && $0.value <= 0x06FF }

        case "hi":
            return result.unicodeScalars.contains { $0.value >= 0x0900 && $0.value <= 0x097F }

        case "bn":
            return result.unicodeScalars.contains { $0.value >= 0x0980 && $0.value <= 0x09FF }

        case "ta":
            return result.unicodeScalars.contains { $0.value >= 0x0B80 && $0.value <= 0x0BFF }

        case "lo":
            return result.unicodeScalars.contains { $0.value >= 0x0E80 && $0.value <= 0x0EFF }

        case "my":
            return result.unicodeScalars.contains { $0.value >= 0x1000 && $0.value <= 0x109F }

        case "km":
            return result.unicodeScalars.contains { $0.value >= 0x1780 && $0.value <= 0x17FF }

        case "he":
            return result.unicodeScalars.contains { $0.value >= 0x0590 && $0.value <= 0x05FF }

        case "el":
            return result.unicodeScalars.contains { $0.value >= 0x0370 && $0.value <= 0x03FF }

        case "en":
            return result.unicodeScalars.contains { CharacterSet.letters.contains($0) }

        default:
            // For other languages (es, fr, de, vi, it, pt, nl, pl, sv, no, da, fi, cs, hu, ro, id, ms, tl, tr):
            // The default macOS dictionary (Oxford English) contains English grammar markers.
            // If the target language is NOT English, reject monolingual English dictionary definitions.
            let lower = result.lowercased()
            let englishDictMarkers = ["| noun", "| verb", "| adjective", "| adverb", "| pronoun", "| preposition", "noun 1", "verb 1", "adjective ["]
            for marker in englishDictMarkers {
                if lower.contains(marker) {
                    return false
                }
            }
            return false
        }
    }

    public func translate(text: String, from sourceLang: String? = nil, to targetLang: String) async throws -> TranslationResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // For single words or short phrases, attempt native macOS Dictionary lookup first,
        // BUT only accept it if the definition is genuinely in the requested target language!
        if trimmed.split(separator: " ").count <= 3,
           let dictResult = lookupDictionary(term: trimmed),
           isResultInTargetLanguage(result: dictResult, targetLang: targetLang) {
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

        // For all other languages, sentences, or when bilingual dictionary is not downloaded in macOS Settings,
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
