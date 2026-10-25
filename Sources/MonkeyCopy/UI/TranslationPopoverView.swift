import SwiftUI
import AppKit

public struct TranslationPopoverView: View {
    public let originalText: String
    public var onClose: () -> Void
    public var onReplace: (String) -> Void

    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var speech = SpeechService.shared

    @State private var sourceLanguage: String = "auto"
    @State private var targetLanguage: String = "th"
    @State private var translationResult: TranslationResult?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var copiedConfirmation = false

    public init(
        originalText: String,
        onClose: @escaping () -> Void,
        onReplace: @escaping (String) -> Void
    ) {
        self.originalText = originalText
        self.onClose = onClose
        self.onReplace = onReplace
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header: Language Pickers, Engine Switcher, Close
            headerBar
                .padding(.horizontal, 10)
                .padding(.top, 10)
                .padding(.bottom, 8)

            Divider()
                .background(Color.white.opacity(0.10))

            // Body: Original Text & Translation with Audio Speaker buttons
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    // Original Text Card
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("ข้อความต้นฉบับ")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.50))
                                .textCase(.uppercase)

                            Spacer()

                            // Speaker button for Original Text
                            Button(action: speakOriginalText) {
                                HStack(spacing: 3) {
                                    Image(systemName: speech.currentlySpeakingText == originalText ? "speaker.wave.3.fill" : "speaker.wave.2")
                                        .font(.system(size: 10))
                                        .foregroundColor(speech.currentlySpeakingText == originalText ? Color(red: 0.4, green: 0.7, blue: 1.0) : Color.white.opacity(0.65))
                                    if speech.currentlySpeakingText == originalText {
                                        Text("กำลังอ่าน...")
                                            .font(.system(size: 9))
                                            .foregroundColor(Color(red: 0.4, green: 0.7, blue: 1.0))
                                    }
                                }
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(speech.currentlySpeakingText == originalText ? Color.blue.opacity(0.2) : Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            .buttonStyle(.plain)
                            .help("ฟังเสียงอ่านข้อความต้นฉบับ")
                        }

                        Text(originalText)
                            .font(.system(size: 11))
                            .foregroundColor(Color.white.opacity(0.75))
                            .lineLimit(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 7))

                    // Translated Result Card
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("คำแปล (\(settings.translationEngineMode.title))")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.50))
                                .textCase(.uppercase)

                            Spacer()

                            if let result = translationResult, !isLoading {
                                // Speaker button for Translated Text
                                Button(action: {
                                    speakTranslatedText(result.translatedText)
                                }) {
                                    HStack(spacing: 3) {
                                        Image(systemName: speech.currentlySpeakingText == result.translatedText ? "speaker.wave.3.fill" : "speaker.wave.2")
                                            .font(.system(size: 10))
                                            .foregroundColor(speech.currentlySpeakingText == result.translatedText ? Color(red: 0.4, green: 0.7, blue: 1.0) : Color.white.opacity(0.65))
                                        if speech.currentlySpeakingText == result.translatedText {
                                            Text("กำลังอ่าน...")
                                                .font(.system(size: 9))
                                                .foregroundColor(Color(red: 0.4, green: 0.7, blue: 1.0))
                                        }
                                    }
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(speech.currentlySpeakingText == result.translatedText ? Color.blue.opacity(0.2) : Color.white.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                                .buttonStyle(.plain)
                                .help("ฟังเสียงอ่านคำแปล")
                            }
                        }

                        if isLoading {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("กำลังแปลภาษา...")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.white.opacity(0.65))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                        } else if let error = errorMessage {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(error)
                                    .font(.system(size: 11))
                                    .foregroundColor(.orange)
                                Button("ลองใหม่อีกครั้ง") {
                                    performTranslation()
                                }
                                .font(.system(size: 10, weight: .medium))
                                .buttonStyle(.bordered)
                            }
                            .padding(.vertical, 4)
                        } else if let result = translationResult {
                            Text(result.translatedText)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .padding(10)
            }

            Divider()
                .background(Color.white.opacity(0.10))

            // Footer: Copy, Replace, Done
            footerBar
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
        }
        .frame(width: 320, height: 250)
        .background(
            ZStack {
                VisualEffectBackground()
                Color(red: 0.10, green: 0.10, blue: 0.13).opacity(0.92)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .preferredColorScheme(.dark)
        .onAppear {
            let hasThai = originalText.unicodeScalars.contains { $0.value >= 0x0E00 && $0.value <= 0x0E7F }
            targetLanguage = hasThai ? "en" : "th"
            sourceLanguage = "auto"
            performTranslation()
        }
        .onDisappear {
            speech.stop()
        }
    }

    // MARK: - Header Bar with Language Selectors

    private var headerBar: some View {
        HStack(spacing: 6) {
            // Source Language Picker Menu
            Menu {
                Button("🌐 ตรวจจับอัตโนมัติ (Auto)") {
                    sourceLanguage = "auto"
                    performTranslation()
                }
                Divider()
                ForEach(SupportedLanguage.languages) { lang in
                    Button("\(lang.flag) \(lang.name)") {
                        sourceLanguage = lang.code
                        performTranslation()
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Text(sourceLanguageDisplayName)
                        .font(.system(size: 10, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7))
                        .opacity(0.6)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            // Swap Button
            Button(action: swapLanguages) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 9))
                    .foregroundColor(Color.white.opacity(0.70))
                    .frame(width: 18, height: 18)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("สลับภาษาต้นทางและปลายทาง")

            // Target Language Picker Menu
            Menu {
                ForEach(SupportedLanguage.languages) { lang in
                    Button("\(lang.flag) \(lang.name)") {
                        targetLanguage = lang.code
                        performTranslation()
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Text(targetLanguageDisplayName)
                        .font(.system(size: 10, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7))
                        .opacity(0.6)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer()

            // Engine Mode Switcher Pill
            Button(action: toggleEngineMode) {
                HStack(spacing: 3) {
                    Image(systemName: settings.translationEngineMode == .google ? "globe" : "apple.logo")
                        .font(.system(size: 9))
                    Text(settings.translationEngineMode == .google ? "Google" : "Apple")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundColor(Color.white.opacity(0.85))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help("สลับโหมดเครื่องมือแปลภาษา (Google Translate / Apple Native)")

            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.70))
                    .frame(width: 18, height: 18)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("ปิด (Esc)")
        }
    }

    private var sourceLanguageDisplayName: String {
        if sourceLanguage == "auto" {
            if let detected = translationResult?.sourceLanguage, let lang = SupportedLanguage.find(byCode: detected) {
                return "\(lang.flag) \(lang.name)"
            }
            return "🌐 ตรวจจับ"
        }
        if let lang = SupportedLanguage.find(byCode: sourceLanguage) {
            return "\(lang.flag) \(lang.name)"
        }
        return sourceLanguage
    }

    private var targetLanguageDisplayName: String {
        if let lang = SupportedLanguage.find(byCode: targetLanguage) {
            return "\(lang.flag) \(lang.name)"
        }
        return targetLanguage.uppercased()
    }

    private func swapLanguages() {
        let currentTarget = targetLanguage
        let newTarget: String
        if sourceLanguage == "auto" {
            newTarget = translationResult?.sourceLanguage ?? "en"
        } else {
            newTarget = sourceLanguage
        }
        sourceLanguage = currentTarget
        targetLanguage = newTarget
        performTranslation()
    }

    // MARK: - Footer Bar

    private var footerBar: some View {
        HStack(spacing: 8) {
            // Copy Translation
            Button(action: copyTranslation) {
                HStack(spacing: 4) {
                    Image(systemName: copiedConfirmation ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10))
                    Text(copiedConfirmation ? "คัดลอกแล้ว!" : "คัดลอก")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(copiedConfirmation ? .green : .white)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .disabled(translationResult == nil)

            // Replace in active app
            Button(action: replaceOriginalText) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 10))
                    Text("แทนที่คำเดิม")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(Color(red: 0.4, green: 0.7, blue: 1.0))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color(red: 0.2, green: 0.4, blue: 0.8).opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .disabled(translationResult == nil)

            Spacer()

            Text("Esc ปิด")
                .font(.system(size: 9))
                .foregroundColor(Color.white.opacity(0.40))
        }
    }

    // MARK: - Actions

    private func performTranslation() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let result = try await TranslationService.shared.translate(
                    text: originalText,
                    mode: settings.translationEngineMode,
                    sourceLang: sourceLanguage,
                    targetLang: targetLanguage
                )
                await MainActor.run {
                    self.translationResult = result
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func toggleEngineMode() {
        if settings.translationEngineMode == .google {
            settings.translationEngineMode = .appleNative
        } else {
            settings.translationEngineMode = .google
        }
        performTranslation()
    }

    private func speakOriginalText() {
        let langCode = (sourceLanguage == "auto" ? (translationResult?.sourceLanguage ?? "en") : sourceLanguage)
        speech.speak(text: originalText, languageCode: langCode)
    }

    private func speakTranslatedText(_ text: String) {
        speech.speak(text: text, languageCode: targetLanguage)
    }

    private func copyTranslation() {
        guard let translated = translationResult?.translatedText else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(translated, forType: .string)

        withAnimation {
            copiedConfirmation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                copiedConfirmation = false
            }
        }
    }

    private func replaceOriginalText() {
        guard let translated = translationResult?.translatedText else { return }
        speech.stop()
        onReplace(translated)
        onClose()
    }
}
