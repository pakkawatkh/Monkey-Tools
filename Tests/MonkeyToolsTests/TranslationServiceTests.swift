import XCTest
@testable import MonkeyTools

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

    func testAppleNativeTargetLanguageValidation() {
        let engine = AppleNativeTranslationEngine()
        let englishDictEntry = "setting set·ting | ˈsediNG | noun 1 the place or type of surroundings where something is positioned."
        XCTAssertFalse(engine.isResultInTargetLanguage(result: englishDictEntry, targetLang: "es"))
        XCTAssertFalse(engine.isResultInTargetLanguage(result: englishDictEntry, targetLang: "fr"))
        XCTAssertFalse(engine.isResultInTargetLanguage(result: englishDictEntry, targetLang: "de"))
        XCTAssertFalse(engine.isResultInTargetLanguage(result: englishDictEntry, targetLang: "th"))
        XCTAssertFalse(engine.isResultInTargetLanguage(result: englishDictEntry, targetLang: "ja"))
        XCTAssertFalse(engine.isResultInTargetLanguage(result: englishDictEntry, targetLang: "zh-CN"))
        XCTAssertFalse(engine.isResultInTargetLanguage(result: englishDictEntry, targetLang: "ko"))
        XCTAssertFalse(engine.isResultInTargetLanguage(result: englishDictEntry, targetLang: "ru"))
        XCTAssertTrue(engine.isResultInTargetLanguage(result: englishDictEntry, targetLang: "en"))
    }

    func testAppleNativeTranslatesToSpanishWithoutDictPollution() async throws {
        let engine = AppleNativeTranslationEngine()
        let result = try await engine.translate(text: "Settings", from: "auto", to: "es")
        XCTAssertEqual(result.targetLanguage, "es")
        XCTAssertFalse(result.translatedText.contains("noun 1"))
        XCTAssertFalse(result.translatedText.contains("the place or type"))
        XCTAssertTrue(result.translatedText.lowercased().contains("ajuste") || result.translatedText.lowercased().contains("configuraci"))
    }

    func testTargetLanguageMajorityResolution() {
        let service = TranslationService.shared
        XCTAssertEqual(service.resolveTargetLanguage(for: "Existing"), "th")
        XCTAssertEqual(service.resolveTargetLanguage(for: "ดึง Existing Unit Test จาก repo"), "th")
        XCTAssertEqual(service.resolveTargetLanguage(for: "สรุปผล (ทุก card)"), "en")
        XCTAssertEqual(service.resolveTargetLanguage(for: "สวัสดี"), "en")
    }

    func testGoogleTranslateBinariesWord() async throws {
        let engine = GoogleTranslationEngine()
        let result = try await engine.translate(text: "binaries", from: "auto", to: "th")
        XCTAssertEqual(result.targetLanguage, "th")
        XCTAssertFalse(result.translatedText.isEmpty)
        XCTAssertTrue(result.translatedText.contains("ไบนารี") || result.translatedText.contains("ฐานสอง"))
    }

    func testAppleNativeTranslateBinariesWord() async throws {
        let engine = AppleNativeTranslationEngine()
        let result = try await engine.translate(text: "binaries", from: "auto", to: "th")
        XCTAssertEqual(result.targetLanguage, "th")
        XCTAssertFalse(result.translatedText.isEmpty)
        XCTAssertTrue(result.translatedText.contains("ไบนารี") || result.translatedText.contains("ฐานสอง"))
    }

    func testPreTranslationCancelAndClearLeavesNoResidualState() {
        let service = TranslationService.shared
        service.clearCache()

        // Start pre-translation with a long settle delay so it stays pending, then cancel immediately
        service.startPreTranslation(
            for: "Transient selection text",
            mode: .google,
            sourceLang: "auto",
            preferredTarget: "th",
            settleDelayNanoseconds: 2_000_000_000
        )
        XCTAssertTrue(service.hasActivePreTranslation)

        // Simulating bubble dismiss without tapping Translate must wipe all state immediately
        service.cancelPreTranslation(clearCachedEntry: true)
        XCTAssertFalse(service.hasActivePreTranslation)

        let consumed = service.consumePreTranslation(
            for: "Transient selection text",
            mode: .google,
            sourceLang: "auto",
            targetLang: "th"
        )
        XCTAssertNil(consumed.result)
        XCTAssertNil(consumed.inFlightTask)
    }

    func testPreTranslationSkipsExcessivelyLongText() {
        let service = TranslationService.shared
        service.clearCache()

        let hugeText = String(repeating: "a", count: TranslationService.maxPreTranslationLength + 100)
        service.startPreTranslation(for: hugeText, mode: .google, sourceLang: "auto", preferredTarget: "th")
        XCTAssertFalse(service.hasActivePreTranslation)
    }

    func testPreTranslationReturnsInstantResultAfterCompletion() async throws {
        let service = TranslationService.shared
        service.clearCache()

        // Start pre-translation with 0ms delay and wait briefly for completion
        service.startPreTranslation(
            for: "hello",
            mode: .google,
            sourceLang: "auto",
            preferredTarget: "th",
            settleDelayNanoseconds: 0
        )

        // Consume either ready result or join in-flight task cleanly
        let consumed = service.consumePreTranslation(
            for: "hello",
            mode: .google,
            sourceLang: "auto",
            targetLang: "th"
        )
        let finalResult: TranslationResult
        if let ready = consumed.result {
            finalResult = ready
        } else if let task = consumed.inFlightTask {
            finalResult = try await task.value
        } else {
            XCTFail("Expected either ready pre-translated result or active in-flight task")
            return
        }

        XCTAssertFalse(finalResult.translatedText.isEmpty)
        XCTAssertEqual(finalResult.targetLanguage, "th")
        XCTAssertFalse(service.hasActivePreTranslation)
    }
}
