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
    @ObservedObject var translationService = TranslationService.shared

    @State private var sourceLanguage: String = "auto"
    @State private var targetLanguage: String = "th"
    @State private var translationResult: TranslationResult?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var copiedConfirmation = false
    @State private var editableText: String
    @State private var debounceTask: Task<Void, Never>?
    @State private var translationTask: Task<Void, Never>?
    @State private var showingHistory = false
    @FocusState private var isInputFocused: Bool

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
        self._editableText = State(initialValue: originalText)
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

            // Body: Translation History OR Original Text & Translation
            if showingHistory {
                historyListView
            } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    // Original Text Card (Editable)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            HStack(spacing: 4) {
                                Text(loc["trans_original"])
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(Color.white.opacity(0.50))
                                    .textCase(.uppercase)
                                Image(systemName: "pencil")
                                    .font(.system(size: 8))
                                    .foregroundColor(Color.white.opacity(0.35))
                            }

                            Spacer()

                            // Clear button for Original Text
                            if !editableText.isEmpty {
                                Button(action: {
                                    editableText = ""
                                    debounceTranslation(for: "")
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(Color.white.opacity(0.40))
                                }
                                .buttonStyle(.plain)
                                .help(loc["trans_clear"])
                            }

                            // Speaker button for Original Text
                            Button(action: speakOriginalText) {
                                HStack(spacing: 3) {
                                    Image(systemName: speech.currentlySpeakingText == editableText ? "speaker.wave.3.fill" : "speaker.wave.2")
                                        .font(.system(size: 10))
                                        .foregroundColor(speech.currentlySpeakingText == editableText ? Color(red: 0.4, green: 0.7, blue: 1.0) : Color.white.opacity(0.65))
                                    if speech.currentlySpeakingText == editableText {
                                        Text(loc["trans_reading"])
                                            .font(.system(size: 9))
                                            .foregroundColor(Color(red: 0.4, green: 0.7, blue: 1.0))
                                    }
                                }
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(speech.currentlySpeakingText == editableText ? Color.blue.opacity(0.2) : Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            .buttonStyle(.plain)
                            .disabled(editableText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .help(loc["trans_listen_orig"])
                        }

                        ZStack(alignment: .topLeading) {
                            if editableText.isEmpty {
                                Text(loc["trans_edit_placeholder"])
                                    .font(.system(size: 11))
                                    .foregroundColor(Color.white.opacity(0.30))
                                    .padding(.top, 2)
                                    .padding(.leading, 1)
                                    .allowsHitTesting(false)
                            }

                            TextField("", text: $editableText, axis: .vertical)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11))
                                .foregroundColor(Color.white.opacity(0.85))
                                .lineLimit(1...8)
                                .focused($isInputFocused)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )

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
                                Text(loc["trans_loading"])
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
                                Button(loc["trans_retry"]) {
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
            targetLanguage = TranslationService.shared.resolveTargetLanguage(for: editableText, preferredTarget: savedTarget)
            sourceLanguage = "auto"
            if editableText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isInputFocused = true
                }
            } else {
                performTranslation()
            }
        }
        .onChange(of: editableText) { newText in
            debounceTranslation(for: newText)
        }
        .onDisappear {
            speech.stop()
            debounceTask?.cancel()
            translationTask?.cancel()
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
                    targetLanguage = TranslationService.shared.resolveTargetLanguage(for: editableText, preferredTarget: "auto")
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

            // History toggle button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.12)) {
                    showingHistory.toggle()
                }
            }) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(showingHistory ? Color(red: 0.4, green: 0.7, blue: 1.0) : Color.white.opacity(0.70))
                    .frame(width: 18, height: 18)
                    .background(showingHistory ? Color.blue.opacity(0.22) : Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .fixedSize()
            .help(loc["trans_history"])

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

        if let translated = translationResult?.translatedText, !translated.isEmpty {
            editableText = translated
            debounceTranslation(for: translated)
        } else {
            performTranslation()
        }
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

    private var historyListView: some View {
        VStack(spacing: 0) {
            HStack {
                Text(loc["trans_history"])
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                if !translationService.history.isEmpty {
                    Button(loc["trans_history_clear"]) {
                        translationService.clearHistory()
                    }
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            if translationService.history.isEmpty {
                Spacer()
                Text(loc["trans_history_empty"])
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.45))
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(translationService.history) { entry in
                            Button(action: {
                                showingHistory = false
                                sourceLanguage = entry.sourceLanguage
                                targetLanguage = entry.targetLanguage
                                editableText = entry.originalText
                                translationResult = TranslationResult(
                                    originalText: entry.originalText,
                                    translatedText: entry.translatedText,
                                    sourceLanguage: entry.sourceLanguage,
                                    targetLanguage: entry.targetLanguage,
                                    engineUsed: settings.translationEngineMode
                                )
                            }) {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text("\(entry.sourceLanguage.uppercased()) → \(entry.targetLanguage.uppercased())")
                                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                                            .foregroundColor(Color(red: 0.4, green: 0.7, blue: 1.0))
                                        Spacer()
                                    }
                                    Text(entry.originalText)
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.75))
                                        .lineLimit(1)
                                    Text(entry.translatedText)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white)
                                        .lineLimit(2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                }
            }
        }
    }

    // MARK: - Actions

    private func performTranslation(textToTranslate: String? = nil) {
        debounceTask?.cancel()
        translationTask?.cancel()

        let text = (textToTranslate ?? editableText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            translationResult = nil
            isLoading = false
            errorMessage = nil
            return
        }

        isLoading = true
        errorMessage = nil

        let currentEngine = settings.translationEngineMode
        let currentSource = sourceLanguage
        let currentTarget = targetLanguage

        translationTask = Task {
            do {
                let result = try await TranslationService.shared.translate(
                    text: text,
                    mode: currentEngine,
                    sourceLang: currentSource,
                    targetLang: currentTarget
                )
                guard !Task.isCancelled else { return }
                TranslationService.shared.recordHistory(result)
                await MainActor.run {
                    self.translationResult = result
                    self.isLoading = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func debounceTranslation(for text: String) {
        debounceTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            translationResult = nil
            isLoading = false
            errorMessage = nil
            return
        }

        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000) // 400ms debounce
            if !Task.isCancelled {
                await MainActor.run {
                    performTranslation(textToTranslate: trimmed)
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
        let text = editableText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let langCode = (sourceLanguage == "auto" ? (translationResult?.sourceLanguage ?? "en") : sourceLanguage)
        speech.speak(text: text, languageCode: langCode)
    }

    private func speakTranslatedText(_ text: String) {
        speech.speak(text: text, languageCode: targetLanguage)
    }

    private func copyTranslation() {
        guard let translated = translationResult?.translatedText else { return }
        ClipboardMonitor.shared.markProgrammaticWrite(text: translated)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(translated, forType: .string)
        ClipboardManager.shared.add(text: translated)

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
            .help(LocalizationManager.shared["trans_resize"])
    }
}
