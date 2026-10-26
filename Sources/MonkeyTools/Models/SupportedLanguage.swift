import Foundation

public struct SupportedLanguage: Identifiable, Hashable {
    public let code: String
    public let name: String
    public let shortName: String
    public let flag: String
    public let bcp47Tag: String

    public var id: String { code }

    public init(code: String, name: String, shortName: String? = nil, flag: String, bcp47Tag: String) {
        self.code = code
        self.name = name
        self.shortName = shortName ?? name
        self.flag = flag
        self.bcp47Tag = bcp47Tag
    }

    // MARK: - Popular Languages (ภาษาหลักยอดนิยม)
    public static let popularLanguages: [SupportedLanguage] = [
        SupportedLanguage(code: "th", name: "ไทย", flag: "🇹🇭", bcp47Tag: "th-TH"),
        SupportedLanguage(code: "en", name: "English", flag: "🇺🇸", bcp47Tag: "en-US"),
        SupportedLanguage(code: "ja", name: "日本語", flag: "🇯🇵", bcp47Tag: "ja-JP"),
        SupportedLanguage(code: "zh-CN", name: "中文 (简体)", shortName: "中文", flag: "🇨🇳", bcp47Tag: "zh-CN"),
        SupportedLanguage(code: "zh-TW", name: "中文 (繁體)", shortName: "繁體", flag: "🇹🇼", bcp47Tag: "zh-TW"),
        SupportedLanguage(code: "ko", name: "한국어", flag: "🇰🇷", bcp47Tag: "ko-KR"),
        SupportedLanguage(code: "fr", name: "Français", flag: "🇫🇷", bcp47Tag: "fr-FR"),
        SupportedLanguage(code: "de", name: "Deutsch", flag: "🇩🇪", bcp47Tag: "de-DE"),
        SupportedLanguage(code: "es", name: "Español", flag: "🇪🇸", bcp47Tag: "es-ES"),
        SupportedLanguage(code: "ru", name: "Русский", flag: "🇷🇺", bcp47Tag: "ru-RU"),
        SupportedLanguage(code: "vi", name: "Tiếng Việt", flag: "🇻🇳", bcp47Tag: "vi-VN")
    ]

    // MARK: - Asia & ASEAN (เอเชียและอาเซียน)
    public static let asianLanguages: [SupportedLanguage] = [
        SupportedLanguage(code: "lo", name: "ລາວ (Lao)", shortName: "ລາວ", flag: "🇱🇦", bcp47Tag: "lo-LA"),
        SupportedLanguage(code: "my", name: "မြန်မာ (Burmese)", shortName: "မြန်မာ", flag: "🇲🇲", bcp47Tag: "my-MM"),
        SupportedLanguage(code: "km", name: "ខ្មែរ (Khmer)", shortName: "ខ្មែរ", flag: "🇰🇭", bcp47Tag: "km-KH"),
        SupportedLanguage(code: "id", name: "Bahasa Indonesia", shortName: "Indonesia", flag: "🇮🇩", bcp47Tag: "id-ID"),
        SupportedLanguage(code: "ms", name: "Bahasa Melayu", shortName: "Melayu", flag: "🇲🇾", bcp47Tag: "ms-MY"),
        SupportedLanguage(code: "tl", name: "Filipino (Tagalog)", shortName: "Filipino", flag: "🇵🇭", bcp47Tag: "fil-PH"),
        SupportedLanguage(code: "hi", name: "हिन्दी (Hindi)", shortName: "हिन्दी", flag: "🇮🇳", bcp47Tag: "hi-IN"),
        SupportedLanguage(code: "bn", name: "বাংলা (Bengali)", shortName: "বাংলা", flag: "🇧🇩", bcp47Tag: "bn-BD"),
        SupportedLanguage(code: "ta", name: "தமிழ் (Tamil)", shortName: "தமிழ்", flag: "🇮🇳", bcp47Tag: "ta-IN")
    ]

    // MARK: - Europe (ยุโรป - รวมทุกภาษาทางการที่ Apple Translate & Google รองรับ)
    public static let europeanLanguages: [SupportedLanguage] = [
        SupportedLanguage(code: "it", name: "Italiano", flag: "🇮🇹", bcp47Tag: "it-IT"),
        SupportedLanguage(code: "pt", name: "Português", flag: "🇵🇹", bcp47Tag: "pt-PT"),
        SupportedLanguage(code: "nl", name: "Nederlands", flag: "🇳🇱", bcp47Tag: "nl-NL"),
        SupportedLanguage(code: "pl", name: "Polski", flag: "🇵🇱", bcp47Tag: "pl-PL"),
        SupportedLanguage(code: "uk", name: "Українська", shortName: "Українська", flag: "🇺🇦", bcp47Tag: "uk-UA"),
        SupportedLanguage(code: "tr", name: "Türkçe", flag: "🇹🇷", bcp47Tag: "tr-TR"),
        SupportedLanguage(code: "sv", name: "Svenska", flag: "🇸🇪", bcp47Tag: "sv-SE"),
        SupportedLanguage(code: "no", name: "Norsk", flag: "🇳🇴", bcp47Tag: "nb-NO"),
        SupportedLanguage(code: "da", name: "Dansk", flag: "🇩🇰", bcp47Tag: "da-DK"),
        SupportedLanguage(code: "fi", name: "Suomi", flag: "🇫🇮", bcp47Tag: "fi-FI"),
        SupportedLanguage(code: "el", name: "Ελληνικά", shortName: "Ελληνικά", flag: "🇬🇷", bcp47Tag: "el-GR"),
        SupportedLanguage(code: "cs", name: "Čeština", flag: "🇨🇿", bcp47Tag: "cs-CZ"),
        SupportedLanguage(code: "hu", name: "Magyar", flag: "🇭🇺", bcp47Tag: "hu-HU"),
        SupportedLanguage(code: "ro", name: "Română", flag: "🇷🇴", bcp47Tag: "ro-RO")
    ]

    // MARK: - Middle East & Others (ตะวันออกกลางและอื่นๆ)
    public static let middleEasternLanguages: [SupportedLanguage] = [
        SupportedLanguage(code: "ar", name: "العربية (Arabic)", shortName: "العربية", flag: "🇸🇦", bcp47Tag: "ar-SA"),
        SupportedLanguage(code: "he", name: "עברית (Hebrew)", shortName: "עברית", flag: "🇮🇱", bcp47Tag: "he-IL"),
        SupportedLanguage(code: "fa", name: "فارسی (Persian)", shortName: "فارسی", flag: "🇮🇷", bcp47Tag: "fa-IR")
    ]

    // All supported languages (37 languages in total)
    public static let languages: [SupportedLanguage] = popularLanguages + asianLanguages + europeanLanguages + middleEasternLanguages

    private static let lookupByCode: [String: SupportedLanguage] = {
        var map = [String: SupportedLanguage](minimumCapacity: languages.count)
        for lang in languages {
            map[lang.code.lowercased()] = lang
        }
        return map
    }()

    public static func find(byCode code: String) -> SupportedLanguage? {
        return lookupByCode[code.lowercased()]
    }
}
