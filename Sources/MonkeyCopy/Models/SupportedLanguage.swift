import Foundation

public struct SupportedLanguage: Identifiable, Hashable {
    public let code: String
    public let name: String
    public let flag: String
    public let bcp47Tag: String

    public var id: String { code }

    public init(code: String, name: String, flag: String, bcp47Tag: String) {
        self.code = code
        self.name = name
        self.flag = flag
        self.bcp47Tag = bcp47Tag
    }

    public static let languages: [SupportedLanguage] = [
        SupportedLanguage(code: "th", name: "ไทย", flag: "🇹🇭", bcp47Tag: "th-TH"),
        SupportedLanguage(code: "en", name: "English", flag: "🇺🇸", bcp47Tag: "en-US"),
        SupportedLanguage(code: "ja", name: "日本語", flag: "🇯🇵", bcp47Tag: "ja-JP"),
        SupportedLanguage(code: "zh-CN", name: "中文 (简体)", flag: "🇨🇳", bcp47Tag: "zh-CN"),
        SupportedLanguage(code: "zh-TW", name: "中文 (繁體)", flag: "🇹🇼", bcp47Tag: "zh-TW"),
        SupportedLanguage(code: "ko", name: "한국어", flag: "🇰🇷", bcp47Tag: "ko-KR"),
        SupportedLanguage(code: "fr", name: "Français", flag: "🇫🇷", bcp47Tag: "fr-FR"),
        SupportedLanguage(code: "de", name: "Deutsch", flag: "🇩🇪", bcp47Tag: "de-DE"),
        SupportedLanguage(code: "es", name: "Español", flag: "🇪🇸", bcp47Tag: "es-ES"),
        SupportedLanguage(code: "ru", name: "Русский", flag: "🇷🇺", bcp47Tag: "ru-RU"),
        SupportedLanguage(code: "vi", name: "Tiếng Việt", flag: "🇻🇳", bcp47Tag: "vi-VN")
    ]

    public static func find(byCode code: String) -> SupportedLanguage? {
        return languages.first { $0.code.lowercased() == code.lowercased() }
    }
}
