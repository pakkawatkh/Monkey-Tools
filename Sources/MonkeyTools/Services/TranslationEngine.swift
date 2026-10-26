import Foundation

public enum TranslationEngineMode: String, CaseIterable, Identifiable, Codable {
    case google = "google"
    case appleNative = "apple_native"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .google:
            return "Google Translate"
        case .appleNative:
            return "Apple Native"
        }
    }

    public var description: String {
        switch self {
        case .google:
            return "แปลภาษาผ่าน Google Translate ฟรี รวดเร็ว และตรวจจับภาษาอัตโนมัติ"
        case .appleNative:
            return "แปลภาษาด้วยระบบ Dictionary / Language Service ภายในเครื่องของ macOS"
        }
    }
}

public struct TranslationResult: Equatable {
    public let originalText: String
    public let translatedText: String
    public let sourceLanguage: String
    public let targetLanguage: String
    public let engineUsed: TranslationEngineMode

    public init(
        originalText: String,
        translatedText: String,
        sourceLanguage: String,
        targetLanguage: String,
        engineUsed: TranslationEngineMode
    ) {
        self.originalText = originalText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.engineUsed = engineUsed
    }
}

public protocol TranslationEngine {
    var mode: TranslationEngineMode { get }
    func translate(text: String, from sourceLang: String?, to targetLang: String) async throws -> TranslationResult
}
