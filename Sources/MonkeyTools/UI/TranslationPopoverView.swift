import SwiftUI
import AppKit

public struct TranslationPopoverView: View {
    public let originalText: String
    public let isEditable: Bool
    public var onClose: () -> Void
    public var onReplace: (String) -> Void

    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var speech = SpeechService.shared
    @ObservedObject var loc = LocalizationManager.shared

    @State private var sourceLanguage: String = "auto"
    @State private var targetLanguage: String = "th"
    @State private var translationResult: TranslationResult?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var copiedConfirmation = false

    public init(
        originalText: String,
        isEditable: Bool = false,
        onClose: @escaping () -> Void,
        onReplace: @escaping (String) -> Void
    ) {
        self.originalText = originalText
        self.isEditable = isEditable
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
                            Text(loc["trans_original"])
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
                                        Text(loc["trans_reading"])
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
                            .help(loc["trans_listen_orig"])
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
                            Text("\(loc["trans_result"]) (\(settings.translationEngineMode.title))")
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
                                            Text(loc["trans_reading"])
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
                                .help(loc["trans_listen_trans"])
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
        .frame(minWidth: 300, maxWidth: .infinity, minHeight: 200, maxHeight: .infinity)
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
            let savedTarget = settings.translationTargetLang
            targetLanguage = TranslationService.shared.resolveTargetLanguage(for: originalText, preferredTarget: savedTarget)
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
            // Engine Mode Switcher (Icon-only at the front!)
            Button(action: toggleEngineMode) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )

                    Image(systemName: settings.translationEngineMode == .google ? "globe" : "apple.logo")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(settings.translationEngineMode == .google ? Color(red: 0.4, green: 0.7, blue: 1.0) : Color.white.opacity(0.90))
                }
                .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .fixedSize()
            .help(loc["trans_engine_help"])

            // Source Language Picker Menu
            Menu {
                Button(loc["trans_auto"]) {
                    sourceLanguage = "auto"
                    performTranslation()
                }
                Divider()
                languageMenuItems { selectedCode in
                    sourceLanguage = selectedCode
                    performTranslation()
                }
            } label: {
                HStack(spacing: 3) {
                    Text(sourceLanguageDisplayName)
                        .font(.system(size: 10, weight: .semibold))
                        .lineLimit(1)
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

            // Language Swap Button (in the middle between Source and Target!)
            Button(action: swapLanguages) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.80))
                    .frame(width: 20, height: 20)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .fixedSize()
            .help(loc["trans_swap"])

            // Target Language Picker Menu
            Menu {
                Button(loc["trans_auto"]) {
                    settings.translationTargetLang = "auto"
                    targetLanguage = TranslationService.shared.resolveTargetLanguage(for: originalText, preferredTarget: "auto")
                    performTranslation()
                }
                Divider()
                languageMenuItems { selectedCode in
                    settings.translationTargetLang = selectedCode
                    targetLanguage = selectedCode
                    performTranslation()
                }
            } label: {
                HStack(spacing: 3) {
                    Text(targetLanguageDisplayName)
                        .font(.system(size: 10, weight: .semibold))
                        .lineLimit(1)
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

            // Native draggable header area to move the window with zero latency
            WindowDragHandleView()
                .frame(maxWidth: .infinity, maxHeight: 24)
                .overlay(
                    HStack(spacing: 3) {
                        Circle().fill(Color.white.opacity(0.30)).frame(width: 3.5, height: 3.5)
                        Circle().fill(Color.white.opacity(0.30)).frame(width: 3.5, height: 3.5)
                        Circle().fill(Color.white.opacity(0.30)).frame(width: 3.5, height: 3.5)
                    }
                )

            // Close button (at the far right)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.70))
                    .frame(width: 18, height: 18)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .fixedSize()
            .help(loc["shortcut_esc"])
        }
        .background(WindowDragHandleView())
    }

    @ViewBuilder
    private func languageMenuItems(onSelect: @escaping (String) -> Void) -> some View {
        ForEach(SupportedLanguage.popularLanguages) { lang in
            Button("\(lang.flag) \(lang.name)") {
                onSelect(lang.code)
            }
        }
        Divider()
        Menu(loc["cat_asia"]) {
            ForEach(SupportedLanguage.asianLanguages) { lang in
                Button("\(lang.flag) \(lang.name)") {
                    onSelect(lang.code)
                }
            }
        }
        Menu(loc["cat_europe"]) {
            ForEach(SupportedLanguage.europeanLanguages) { lang in
                Button("\(lang.flag) \(lang.name)") {
                    onSelect(lang.code)
                }
            }
        }
        Menu(loc["cat_middle_east"]) {
            ForEach(SupportedLanguage.middleEasternLanguages) { lang in
                Button("\(lang.flag) \(lang.name)") {
                    onSelect(lang.code)
                }
            }
        }
    }

    private var sourceLanguageDisplayName: String {
        if sourceLanguage == "auto" {
            if let detected = translationResult?.sourceLanguage, let lang = SupportedLanguage.find(byCode: detected) {
                return "\(lang.flag) \(lang.shortName)"
            }
            if let detected = translationResult?.sourceLanguage, !detected.isEmpty {
                return "🌐 \(detected.uppercased())"
            }
            return loc["trans_auto_short"]
        }
        if let lang = SupportedLanguage.find(byCode: sourceLanguage) {
            return "\(lang.flag) \(lang.shortName)"
        }
        return sourceLanguage.uppercased()
    }

    private var targetLanguageDisplayName: String {
        if let lang = SupportedLanguage.find(byCode: targetLanguage) {
            return "\(lang.flag) \(lang.shortName)"
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
        settings.translationTargetLang = newTarget
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
                    Text(copiedConfirmation ? loc["trans_copied"] : loc["trans_copy"])
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

            // Replace in active app (only shown if selected element is genuinely editable)
            if isEditable {
                Button(action: replaceOriginalText) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10))
                        Text(loc["trans_replace"])
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
            }

            Spacer()

            Text(loc["shortcut_esc"])
                .font(.system(size: 9))
                .foregroundColor(Color.white.opacity(0.40))

            // Draggable resize grip in bottom-right corner
            ResizeGripHandle()
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

// Native macOS WindowServer drag handle (100% smooth, 0ms latency, glued to mouse)
public struct WindowDragHandleView: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> WindowDragNSView {
        return WindowDragNSView()
    }

    public func updateNSView(_ nsView: WindowDragNSView, context: Context) {}

    public final class WindowDragNSView: NSView {
        public override var mouseDownCanMoveWindow: Bool {
            return true
        }

        public override func mouseDown(with event: NSEvent) {
            // Hands off dragging directly to macOS WindowServer compositor
            self.window?.performDrag(with: event)
        }
    }
}

public struct ResizeGripHandle: View {
    @State private var initialMouseLocation: CGPoint = .zero
    @State private var initialWindowFrame: CGRect = .zero

    public init() {}

    public var body: some View {
        Image(systemName: "arrow.down.right.and.arrow.up.left")
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(Color.white.opacity(0.40))
            .frame(width: 16, height: 16)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        let currentMouse = NSEvent.mouseLocation
                        let panel = TranslationPopoverPanel.shared
                        if initialMouseLocation == .zero {
                            initialMouseLocation = currentMouse
                            initialWindowFrame = panel.frame
                        }
                        let deltaX = currentMouse.x - initialMouseLocation.x
                        let deltaY = currentMouse.y - initialMouseLocation.y

                        let newW = max(300, min(800, initialWindowFrame.width + deltaX))
                        let newH = max(200, min(650, initialWindowFrame.height - deltaY))
                        let newY = initialWindowFrame.maxY - newH

                        panel.setFrame(NSRect(x: initialWindowFrame.minX, y: newY, width: newW, height: newH), display: true)
                    }
                    .onEnded { _ in
                        initialMouseLocation = .zero
                        initialWindowFrame = .zero
                        TranslationPopoverPanel.shared.saveCurrentSize()
                    }
            )
            .help("Drag to resize")
    }
}
