import XCTest
@testable import MonkeyTools

final class SpeechAndLanguageTests: XCTestCase {
    func testSupportedLanguagesList() {
        XCTAssertEqual(SupportedLanguage.languages.count, 37)
        XCTAssertEqual(SupportedLanguage.popularLanguages.count, 11)
        XCTAssertEqual(SupportedLanguage.asianLanguages.count, 9)
        XCTAssertEqual(SupportedLanguage.europeanLanguages.count, 14)
        XCTAssertEqual(SupportedLanguage.middleEasternLanguages.count, 3)

        let th = SupportedLanguage.find(byCode: "th")
        XCTAssertNotNil(th)
        XCTAssertEqual(th?.name, "ไทย")
        XCTAssertEqual(th?.bcp47Tag, "th-TH")

        let it = SupportedLanguage.find(byCode: "IT")
        XCTAssertNotNil(it)
        XCTAssertEqual(it?.name, "Italiano")
        XCTAssertEqual(it?.bcp47Tag, "it-IT")

        let ar = SupportedLanguage.find(byCode: "ar")
        XCTAssertNotNil(ar)
        XCTAssertEqual(ar?.bcp47Tag, "ar-SA")

        let lo = SupportedLanguage.find(byCode: "lo")
        XCTAssertNotNil(lo)
        XCTAssertEqual(lo?.bcp47Tag, "lo-LA")
    }

    func testBCP47LanguageResolution() {
        let service = SpeechService.shared
        XCTAssertEqual(service.resolveBCPTag(for: "th"), "th-TH")
        XCTAssertEqual(service.resolveBCPTag(for: "en"), "en-US")
        XCTAssertEqual(service.resolveBCPTag(for: "ja"), "ja-JP")
        XCTAssertEqual(service.resolveBCPTag(for: "zh-CN"), "zh-CN")
        XCTAssertEqual(service.resolveBCPTag(for: "ko"), "ko-KR")
        XCTAssertEqual(service.resolveBCPTag(for: "it"), "it-IT")
        XCTAssertEqual(service.resolveBCPTag(for: "pt"), "pt-PT")
        XCTAssertEqual(service.resolveBCPTag(for: "ar"), "ar-SA")
        XCTAssertEqual(service.resolveBCPTag(for: "id"), "id-ID")
        XCTAssertEqual(service.resolveBCPTag(for: "lo"), "lo-LA")
    }

    func testTranslationServiceWithCustomTarget() async throws {
        let service = TranslationService.shared
        let text = "Hello"
        let result = try await service.translate(text: text, mode: .google, sourceLang: "en", targetLang: "th")
        XCTAssertEqual(result.targetLanguage, "th")
        XCTAssertFalse(result.translatedText.isEmpty)

        let itResult = try await service.translate(text: text, mode: .google, sourceLang: "en", targetLang: "it")
        XCTAssertEqual(itResult.targetLanguage, "it")
        XCTAssertFalse(itResult.translatedText.isEmpty)
    }
}
