import Foundation
import AVFoundation

public final class SpeechService: NSObject, @unchecked Sendable, ObservableObject, AVSpeechSynthesizerDelegate {
    public static let shared = SpeechService()

    private let synthesizer = AVSpeechSynthesizer()

    @Published public var isSpeaking: Bool = false
    @Published public var currentlySpeakingText: String?

    public override init() {
        super.init()
        synthesizer.delegate = self
    }

    public func resolveBCPTag(for languageCode: String) -> String {
        let code = languageCode.lowercased()
        switch code {
        case "th":
            return "th-TH"
        case "en":
            return "en-US"
        case "ja":
            return "ja-JP"
        case "zh-cn", "zh":
            return "zh-CN"
        case "zh-tw":
            return "zh-TW"
        case "ko":
            return "ko-KR"
        case "fr":
            return "fr-FR"
        case "de":
            return "de-DE"
        case "es":
            return "es-ES"
        case "ru":
            return "ru-RU"
        case "vi":
            return "vi-VN"
        default:
            if let matched = SupportedLanguage.find(byCode: languageCode) {
                return matched.bcp47Tag
            }
            return "en-US"
        }
    }

    public func speak(text: String, languageCode: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // If currently speaking this exact text, toggle off
        if synthesizer.isSpeaking && currentlySpeakingText == trimmed {
            stop()
            return
        }

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate

        let tag = resolveBCPTag(for: languageCode)
        if let voice = AVSpeechSynthesisVoice(language: tag) {
            utterance.voice = voice
        } else if let fallbackVoice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = fallbackVoice
        }

        currentlySpeakingText = trimmed
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    public func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
        currentlySpeakingText = nil
    }

    // MARK: - AVSpeechSynthesizerDelegate

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = false
            self?.currentlySpeakingText = nil
        }
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = false
            self?.currentlySpeakingText = nil
        }
    }
}
