import SwiftUI
import Carbon
import AppKit

public struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var autoPaster = AutoPaster.shared
    @ObservedObject var loc = LocalizationManager.shared
    @ObservedObject var networkMonitor = NetworkMonitorService.shared
    @State private var isRecordingCustom = false
    @State private var localMonitor: Any?

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Text("🐵")
                    .font(.system(size: 22))
                Text(loc["settings_title"])
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color.primary.opacity(0.04))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // MARK: - Hotkey Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text(loc["settings_hotkey_heading"])
                            .font(.system(size: 13, weight: .bold))

                        // Current active shortcut badge
                        HStack(spacing: 12) {
                            Text(loc["settings_custom_hotkey"] + ":")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)

                            Text(settings.hotkeyDisplayString)
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundColor(.accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                                )

                            Spacer()

                            Button(action: {
                                toggleRecording()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: isRecordingCustom ? "record.circle.fill" : "keyboard")
                                    Text(isRecordingCustom ? loc["settings_press_shortcut"] : loc["settings_click_to_record"])
                                }
                                .font(.system(size: 12, weight: .medium))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(isRecordingCustom ? .orange : .accentColor)
                        }

                        if isRecordingCustom {
                            Text("👉 กำลังรอรับปุ่ม... ลองกดปุ่มผสมที่ต้องการ เช่น Option + V, Cmd + Shift + V หรือ Ctrl + Option + Space")
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.orange.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }

                        Divider().padding(.vertical, 4)

                        // Quick Presets
                        Text("หรือเลือกคีย์ลัดยอดนิยม:")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)

                        VStack(spacing: 6) {
                            ForEach(AppSettings.presets) { preset in
                                Button(action: {
                                    settings.setHotKey(
                                        keyCode: preset.keyCode,
                                        modifiers: preset.modifiers,
                                        display: preset.display
                                    )
                                }) {
                                    HStack {
                                        Text(preset.name)
                                            .font(.system(size: 12))
                                        Spacer()
                                        Text(preset.display)
                                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                            .foregroundColor(.secondary)

                                        if settings.hotkeyDisplayString == preset.display {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(settings.hotkeyDisplayString == preset.display ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.03))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding()
                    .background(Color.primary.opacity(0.02))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08), lineWidth: 1))

                    // MARK: - General Section
                    VStack(alignment: .leading, spacing: 14) {
                        Text(loc["settings_general"])
                            .font(.system(size: 13, weight: .bold))

                        // App UI Language Picker
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(loc["app_language"])
                                    .font(.system(size: 13))
                                Text(loc["app_language_desc"])
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Picker("", selection: $settings.appLanguage) {
                                ForEach(AppLanguage.allCases) { lang in
                                    Text(lang.displayName).tag(lang.rawValue)
                                }
                            }
                            .frame(width: 200)
                        }

                        Divider()

                        // Max history count
                        HStack {
                            Text(loc["settings_max_records"])
                                .font(.system(size: 13))
                            Spacer()
                            Picker("", selection: $settings.maxHistoryCount) {
                                Text("50 \(loc["records_count_suffix"])").tag(50)
                                Text("100 \(loc["records_count_suffix"])").tag(100)
                                Text("200 \(loc["records_count_suffix"])").tag(200)
                                Text("500 \(loc["records_count_suffix"])").tag(500)
                            }
                            .frame(width: 140)
                        }

                        Divider()

                        // Auto paste toggle
                        Toggle(isOn: $settings.autoPasteEnabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(loc["settings_auto_paste"])
                                    .font(.system(size: 13))
                                Text(loc["settings_auto_paste_desc"])
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }

                        Divider()

                        // Launch at Login
                        Toggle(isOn: $settings.launchAtLogin) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(loc["settings_launch_login"])
                                    .font(.system(size: 13))
                                Text(loc["settings_launch_login_desc"])
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color.primary.opacity(0.02))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08), lineWidth: 1))

                    // MARK: - Network Monitor Section
                    VStack(alignment: .leading, spacing: 14) {
                        Text(loc["settings_network_heading"])
                            .font(.system(size: 13, weight: .bold))

                        Toggle(isOn: $settings.networkMonitorEnabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(loc["settings_network_enable"])
                                    .font(.system(size: 13))
                            }
                        }

                        if settings.networkMonitorEnabled {
                            Divider()

                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(loc["settings_network_unit"])
                                        .font(.system(size: 13))
                                }
                                Spacer()
                                Picker("", selection: $settings.networkSpeedUnit) {
                                    Text(loc["unit_auto_bytes"]).tag(NetworkSpeedUnit.autoBytes)
                                    Text(loc["unit_bits"]).tag(NetworkSpeedUnit.bits)
                                    Text(loc["unit_fixed_kb"]).tag(NetworkSpeedUnit.fixedKB)
                                    Text(loc["unit_fixed_mb"]).tag(NetworkSpeedUnit.fixedMB)
                                }
                                .pickerStyle(.menu)
                                .frame(width: 190)
                            }

                            // Live speed preview badge
                            HStack(spacing: 8) {
                                Text("⚡")
                                Text(networkMonitor.formattedSpeedString.isEmpty ? "⬇ 0 B/s  ⬆ 0 B/s" : networkMonitor.formattedSpeedString)
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.primary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    .padding()
                    .background(Color.primary.opacity(0.02))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08), lineWidth: 1))

                    // MARK: - Translation Section
                    VStack(alignment: .leading, spacing: 14) {
                        Text(loc["settings_translator"])
                            .font(.system(size: 13, weight: .bold))

                        // Selection translate toggle
                        Toggle(isOn: $settings.selectionTranslateEnabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(loc["settings_bubble_toggle"])
                                    .font(.system(size: 13))
                                Text(loc["settings_bubble_desc"])
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }

                        if settings.selectionTranslateEnabled {
                            Divider()

                            // Translation Engine Mode
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(loc["settings_engine_label"])
                                        .font(.system(size: 13))
                                    Text(settings.translationEngineMode.description)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Picker("", selection: $settings.translationEngineMode) {
                                    ForEach(TranslationEngineMode.allCases) { mode in
                                        Text(mode.title).tag(mode)
                                    }
                                }
                                .frame(width: 150)
                            }

                            Divider()

                            // Target Language
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(loc["settings_target_label"])
                                        .font(.system(size: 13))
                                    Text(loc["settings_target_desc"])
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Picker("", selection: $settings.translationTargetLang) {
                                    Text(loc["trans_auto"]).tag("auto")
                                    Divider()
                                    Section(header: Text(loc["cat_popular"])) {
                                        ForEach(SupportedLanguage.popularLanguages) { lang in
                                            Text("\(lang.flag) \(lang.name)").tag(lang.code)
                                        }
                                    }
                                    Section(header: Text(loc["cat_asia"])) {
                                        ForEach(SupportedLanguage.asianLanguages) { lang in
                                            Text("\(lang.flag) \(lang.name)").tag(lang.code)
                                        }
                                    }
                                    Section(header: Text(loc["cat_europe"])) {
                                        ForEach(SupportedLanguage.europeanLanguages) { lang in
                                            Text("\(lang.flag) \(lang.name)").tag(lang.code)
                                        }
                                    }
                                    Section(header: Text(loc["cat_middle_east"])) {
                                        ForEach(SupportedLanguage.middleEasternLanguages) { lang in
                                            Text("\(lang.flag) \(lang.name)").tag(lang.code)
                                        }
                                    }
                                }
                                .frame(width: 190)
                            }

                            Text(loc["settings_tip_text"])
                                .font(.system(size: 11))
                                .foregroundColor(Color(red: 0.4, green: 0.7, blue: 1.0))
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.blue.opacity(0.10))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    .padding()
                    .background(Color.primary.opacity(0.02))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08), lineWidth: 1))

                    // MARK: - Permissions Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("สิทธิ์การควบคุมระบบ (System Permissions)")
                            .font(.system(size: 13, weight: .bold))

                        HStack {
                            Image(systemName: autoPaster.isAccessibilityGranted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(autoPaster.isAccessibilityGranted ? .green : .orange)
                                .font(.system(size: 16))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Accessibility Permission (สำหรับการวางอัตโนมัติ)")
                                    .font(.system(size: 12, weight: .medium))
                                Text(autoPaster.isAccessibilityGranted ? "อนุญาตสิทธิ์เรียบร้อยแล้ว" : "ยังไม่ได้รับสิทธิ์ - จำเป็นต้องเปิดเพื่อให้ Auto-Paste ทำงาน")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button("เปิด System Settings") {
                                AutoPaster.shared.openAccessibilitySettings()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding()
                    .background(Color.primary.opacity(0.02))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08), lineWidth: 1))
                }
                .padding(16)
            }
        }
        .frame(width: 480, height: 660)
        .preferredColorScheme(.dark)
        .onAppear {
            autoPaster.refreshAccessibilityStatus()
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func toggleRecording() {
        if isRecordingCustom {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecordingCustom = true

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            var carbonMods: UInt32 = 0
            var display = ""

            let flags = event.modifierFlags
            if flags.contains(.control) {
                carbonMods |= UInt32(controlKey)
                display += "⌃"
            }
            if flags.contains(.option) {
                carbonMods |= UInt32(optionKey)
                display += "⌥"
            }
            if flags.contains(.shift) {
                carbonMods |= UInt32(shiftKey)
                display += "⇧"
            }
            if flags.contains(.command) {
                carbonMods |= UInt32(cmdKey)
                display += "⌘"
            }

            let char = event.charactersIgnoringModifiers?.uppercased() ?? ""
            if !char.isEmpty {
                display += char
            }

            // Must have at least one modifier key and a non-empty character
            if carbonMods != 0 && !char.isEmpty {
                settings.setHotKey(
                    keyCode: UInt32(event.keyCode),
                    modifiers: carbonMods,
                    display: display
                )
                stopRecording()
                return nil
            }

            return event
        }
    }

    private func stopRecording() {
        isRecordingCustom = false
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
}
