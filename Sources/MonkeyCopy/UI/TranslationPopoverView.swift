import SwiftUI
import AppKit

public struct TranslationPopoverView: View {
    public let originalText: String
    public var onClose: () -> Void
    public var onReplace: (String) -> Void

    @ObservedObject var settings = AppSettings.shared
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
            // Header: Languages, Engine Switcher, Close
            headerBar
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 8)

            Divider()
                .background(Color.white.opacity(0.10))

            // Body: Original Text & Translation
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    // Original Text
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ข้อความต้นฉบับ")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.50))
                            .textCase(.uppercase)

                        Text(originalText)
                            .font(.system(size: 11))
                            .foregroundColor(Color.white.opacity(0.70))
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                    // Translated Result
                    VStack(alignment: .leading, spacing: 4) {
                        Text("คำแปล (\(settings.translationEngineMode.title))")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.50))
                            .textCase(.uppercase)

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
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .padding(12)
            }

            Divider()
                .background(Color.white.opacity(0.10))

            // Footer: Copy, Replace, Done
            footerBar
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .frame(width: 310, height: 230)
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
            performTranslation()
        }
    }

    private var headerBar: some View {
        HStack(spacing: 8) {
            // Language direction tag
            HStack(spacing: 4) {
                let isThai = originalText.unicodeScalars.contains { $0.value >= 0x0E00 && $0.value <= 0x0E7F }
                Text(isThai ? "ไทย" : "English")
                    .font(.system(size: 10, weight: .bold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 8))
                    .foregroundColor(Color.white.opacity(0.50))
                Text(isThai ? "English" : "ไทย")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 4))

            Spacer()

            // Engine Mode Switcher Pill
            Button(action: toggleEngineMode) {
                HStack(spacing: 4) {
                    Image(systemName: settings.translationEngineMode == .google ? "globe" : "apple.logo")
                        .font(.system(size: 10))
                    Text(settings.translationEngineMode == .google ? "Google" : "Apple")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(Color.white.opacity(0.85))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help("สลับโหมดเครื่องมือแปลภาษา (Google Translate / Apple Native)")

            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.70))
                    .frame(width: 20, height: 20)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("ปิด (Esc)")
        }
    }

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
                .padding(.horizontal, 10)
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
                .padding(.horizontal, 10)
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

    private func performTranslation() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let result = try await TranslationService.shared.translate(
                    text: originalText,
                    mode: settings.translationEngineMode
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
        onReplace(translated)
        onClose()
    }
}
