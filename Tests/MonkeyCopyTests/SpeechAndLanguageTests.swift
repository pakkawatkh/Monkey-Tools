import XCTest
@testable import MonkeyCopy

final class SpeechAndLanguageTests: XCTestCase {
    func testSupportedLanguagesList() {
        XCTAssertTrue(SupportedLanguage.languages.count >= 8)
        let th = SupportedLanguage.languages.first(where: { $0.code == "th" })
        XCTAssertNotNil(th)
        XCTAssertEqual(th?.name, "ไทย")
        XCTAssertEqual(th?.bcp47Tag, "th-TH")
    }

    func testBCP47LanguageResolution() {
        let service = SpeechService.shared
        XCTAssertEqual(service.resolveBCPTag(for: "th"), "th-TH")
        XCTAssertEqual(service.resolveBCPTag(for: "en"), "en-US")
        XCTAssertEqual(service.resolveBCPTag(for: "ja"), "ja-JP")
        XCTAssertEqual(service.resolveBCPTag(for: "zh-CN"), "zh-CN")
        XCTAssertEqual(service.resolveBCPTag(for: "ko"), "ko-KR")
    }

    func testTranslationServiceWithCustomTarget() async throws {
        let service = TranslationService.shared
        let text = "Hello"
        let result = try await service.translate(text: text, mode: .google, sourceLang: "en", targetLang: "th")
        XCTAssertEqual(result.targetLanguage, "th")
        XCTAssertFalse(result.translatedText.isEmpty)
    }
}
