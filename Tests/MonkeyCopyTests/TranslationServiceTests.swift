import XCTest
@testable import MonkeyCopy

final class TranslationServiceTests: XCTestCase {
    func testTranslationEngineModeEnum() {
        XCTAssertEqual(TranslationEngineMode.allCases.count, 2)
        XCTAssertEqual(TranslationEngineMode.google.title, "Google Translate")
        XCTAssertEqual(TranslationEngineMode.appleNative.title, "Apple Native")
    }

    func testGoogleTranslationURLQueryEncoding() {
        let engine = GoogleTranslationEngine()
        let text = "Hello world"
        let url = engine.makeTranslateURL(text: text, from: "auto", to: "th")
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains("translate.googleapis.com"))
        XCTAssertTrue(url!.absoluteString.contains("tl=th"))
    }

    func testGoogleTranslationResponseParsing() throws {
        let sampleJSON = "[[[\"สวัสดีชาวโลก\",\"Hello world\",null,null,10]],null,\"en\",null,null,null,null,[]]"
        let engine = GoogleTranslationEngine()
        let result = try engine.parseResponse(jsonString: sampleJSON, originalText: "Hello world", targetLang: "th")
        XCTAssertEqual(result.translatedText, "สวัสดีชาวโลก")
        XCTAssertEqual(result.sourceLanguage, "en")
        XCTAssertEqual(result.engineUsed, .google)
    }

    func testAppleNativeFallback() async {
        let engine = AppleNativeTranslationEngine()
        let text = "test"
        let result = try? await engine.translate(text: text, from: "en", to: "th")
        XCTAssertNotNil(result)
    }
}
