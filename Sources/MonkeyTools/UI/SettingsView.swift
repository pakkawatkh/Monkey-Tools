import SwiftUI
import Carbon
import AppKit

public enum SettingsTab: String, CaseIterable, Identifiable {
    case clipboard = "clipboard"
    case translator = "translator"
    case network = "network"
    case general = "general"

    public var id: String { rawValue }

    public func title(loc: LocalizationManager) -> String {
        switch self {
        case .clipboard: return loc["tab_clipboard"]
        case .translator: return loc["tab_translator"]
        case .network: return loc["tab_network"]
        case .general: return loc["tab_general"]
        }
    }

    public var icon: String {
        switch self {
        case .clipboard: return "doc.on.clipboard"
        case .translator: return "character.bubble"
        case .network: return "network"
        case .general: return "gearshape"
        }
    }
}

public struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var autoPaster = AutoPaster.shared
    @ObservedObject var loc = LocalizationManager.shared
    @ObservedObject var networkMonitor = NetworkMonitorService.shared
    @ObservedObject var updateService = UpdateCheckService.shared
    @ObservedObject var installer = UpdateInstallerService.shared
    @State private var selectedTab: SettingsTab = .clipboard
    @State private var isRecordingCustom = false
    @State private var isRecordingTranslateCustom = false
    @State private var localMonitor: Any?
    @State private var localTranslateMonitor: Any?

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
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(0.04))

            Divider()

            // Tab Navigation Bar
            HStack(spacing: 8) {
                ForEach(SettingsTab.allCases) { tab in
                    Button(action: {
                        selectedTab = tab
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 12))
                            Text(tab.title(loc: loc))
                                .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .foregroundColor(selectedTab == tab ? .white : .secondary)
                        .background(selectedTab == tab ? Color.accentColor : Color.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.02))

            Divider()

            // Tab Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedTab {
                    case .clipboard:
                        clipboardTabContent
                    case .translator:
                        translatorTabContent
                    case .network:
                        networkTabContent
                    case .general:
                        generalTabContent
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 500, height: 530)
        .preferredColorScheme(.dark)
        .onAppear {
            autoPaster.refreshAccessibilityStatus()
        }
        .onDisappear {
            stopRecording()
            stopTranslateRecording()
        }
    }

    // MARK: - Clipboard Tab
    private var clipboardTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Hotkey Configuration
            VStack(alignment: .leading, spacing: 12) {
                Text(loc["settings_hotkey_heading"])
                    .font(.system(size: 13, weight: .bold))

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
                    Text(loc["settings_recording_hint"])
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                Divider().padding(.vertical, 4)

                // Quick Presets
                Text(loc["settings_popular_presets"])
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

            // Clipboard Behavior Settings
            VStack(alignment: .leading, spacing: 14) {
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
            }
            .padding()
            .background(Color.primary.opacity(0.02))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08), lineWidth: 1))

            // Excluded Apps Section
            VStack(alignment: .leading, spacing: 12) {
                Text(loc["settings_excluded_apps_heading"])
                    .font(.system(size: 13, weight: .bold))
                Text(loc["settings_excluded_apps_desc"])
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                if settings.excludedAppBundleIDs.isEmpty {
                    Text(loc["settings_no_excluded_apps"])
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                } else {
                    VStack(spacing: 6) {
                        ForEach(settings.excludedAppBundleIDs, id: \.self) { bundleID in
                            HStack {
                                Image(systemName: "app.dashed")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Text(bundleID)
                                    .font(.system(size: 12, design: .monospaced))
                                Spacer()
                                Button(loc["settings_remove_excluded_app"]) {
                                    settings.removeExcludedApp(bundleID: bundleID)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }

                Button(action: promptAddExcludedApp) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text(loc["settings_add_excluded_app"])
                    }
                    .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()
            .background(Color.primary.opacity(0.02))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08), lineWidth: 1))
        }
    }

    // MARK: - Translator Tab
    private var translatorTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                Text(loc["settings_translator"])
                .font(.system(size: 13, weight: .bold))

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

        // Quick Translate Hotkey Section
        VStack(alignment: .leading, spacing: 12) {
            Text(loc["settings_translate_hotkey_heading"])
                .font(.system(size: 13, weight: .bold))

            Toggle(isOn: $settings.translateHotkeyEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(loc["settings_translate_hotkey_enable"])
                        .font(.system(size: 13))
                    Text(loc["settings_translate_hotkey_desc"])
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            if settings.translateHotkeyEnabled {
                Divider().padding(.vertical, 2)

                HStack(spacing: 12) {
                    Text(loc["settings_custom_hotkey"] + ":")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    Text(settings.translateHotkeyDisplayString)
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
                        toggleTranslateRecording()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: isRecordingTranslateCustom ? "record.circle.fill" : "keyboard")
                            Text(isRecordingTranslateCustom ? loc["settings_press_shortcut"] : loc["settings_click_to_record"])
                        }
                        .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isRecordingTranslateCustom ? .orange : .accentColor)
                }

                if isRecordingTranslateCustom {
                    Text(loc["settings_recording_hint"])
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                Divider().padding(.vertical, 4)

                // Quick Presets
                Text(loc["settings_popular_presets"])
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                VStack(spacing: 6) {
                    ForEach(AppSettings.translatePresets) { preset in
                        Button(action: {
                            settings.setTranslateHotKey(
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

                                if settings.translateHotkeyDisplayString == preset.display {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(settings.translateHotkeyDisplayString == preset.display ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
            .padding()
            .background(Color.primary.opacity(0.02))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08), lineWidth: 1))
        }
    }

    // MARK: - Network Monitor Tab
    private var networkTabContent: some View {
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

                Text(loc["settings_network_fixed_slot_tip"])
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.primary.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08), lineWidth: 1))
    }

    // MARK: - General Tab
    private var generalTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // General Settings
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

            // Software Update Section
            VStack(alignment: .leading, spacing: 14) {
                Text(loc["update_heading"])
                    .font(.system(size: 13, weight: .bold))

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loc["update_current_version"] + ":")
                            .font(.system(size: 13))
                        Text("v\(updateService.currentAppVersion)")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: {
                        updateService.checkForUpdates(force: true)
                    }) {
                        HStack(spacing: 6) {
                            if updateService.isChecking {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                            Text(updateService.isChecking ? loc["update_checking"] : loc["update_check_button"])
                        }
                        .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(updateService.isChecking)
                }

                if let lastCheck = updateService.lastCheckDate {
                    Text("\(loc["update_last_checked"]): \(formatDate(lastCheck))")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                if updateService.updateAvailable, let info = updateService.latestUpdateInfo {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Text("✨")
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(loc["update_available_title"]) (v\(info.latestVersion))")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.orange)
                                if !info.releaseNotes.isEmpty {
                                    Text(info.releaseNotes)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }

                        if installer.isInstalling {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(installer.installStatusText)
                                        .font(.system(size: 11, weight: .medium))
                                    Spacer()
                                    Text("\(Int(installer.downloadProgress * 100))%")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                                ProgressView(value: installer.downloadProgress, total: 1.0)
                                    .progressViewStyle(.linear)
                            }
                            .padding(.vertical, 4)
                        } else {
                            HStack(spacing: 12) {
                                Button(action: {
                                    installer.startUpdate(with: info)
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                        Text(loc["update_button_install"])
                                    }
                                    .font(.system(size: 12, weight: .semibold))
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.orange)

                                Button(action: {
                                    if let url = URL(string: info.downloadUrl) {
                                        NSWorkspace.shared.open(url)
                                    }
                                }) {
                                    Text(loc["update_download_button"])
                                        .font(.system(size: 11))
                                        .underline()
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if let err = installer.installError {
                            Text(err)
                                .font(.system(size: 11))
                                .foregroundColor(.red)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.3), lineWidth: 1))
                } else if updateService.lastCheckDate != nil && !updateService.isChecking {
                    Text(loc["update_up_to_date"])
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(Color.primary.opacity(0.02))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08), lineWidth: 1))

            // System Permissions
            VStack(alignment: .leading, spacing: 10) {
                Text(loc["settings_permissions_heading"])
                    .font(.system(size: 13, weight: .bold))

                HStack {
                    Image(systemName: autoPaster.isAccessibilityGranted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(autoPaster.isAccessibilityGranted ? .green : .orange)
                        .font(.system(size: 16))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(loc["settings_accessibility_title"])
                            .font(.system(size: 12, weight: .medium))
                        Text(autoPaster.isAccessibilityGranted ? loc["settings_accessibility_granted_desc"] : loc["settings_accessibility_missing_desc"])
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(loc["settings_open_system_settings"]) {
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
    }

    private func toggleRecording() {
        if isRecordingCustom {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        stopTranslateRecording()
        stopRecording()
        isRecordingCustom = true

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            var carbonMods: UInt32 = 0
            var displayParts: [String] = []

            let flags = event.modifierFlags
            if flags.contains(.control) {
                carbonMods |= UInt32(controlKey)
                displayParts.append("⌃")
            }
            if flags.contains(.option) {
                carbonMods |= UInt32(optionKey)
                displayParts.append("⌥")
            }
            if flags.contains(.shift) {
                carbonMods |= UInt32(shiftKey)
                displayParts.append("⇧")
            }
            if flags.contains(.command) {
                carbonMods |= UInt32(cmdKey)
                displayParts.append("⌘")
            }

            // Esc without modifiers cancels recording
            if event.keyCode == 53 && carbonMods == 0 {
                stopRecording()
                return nil
            }

            let keyStr = AppSettings.displayStringForKeyCode(event.keyCode, characters: event.charactersIgnoringModifiers)
            if !keyStr.isEmpty {
                displayParts.append(keyStr)
            }

            if carbonMods != 0 && !keyStr.isEmpty {
                let display = displayParts.joined(separator: " + ")
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

    private func toggleTranslateRecording() {
        if isRecordingTranslateCustom {
            stopTranslateRecording()
        } else {
            startTranslateRecording()
        }
    }

    private func startTranslateRecording() {
        stopRecording()
        stopTranslateRecording()
        isRecordingTranslateCustom = true

        localTranslateMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            var carbonMods: UInt32 = 0
            var displayParts: [String] = []

            let flags = event.modifierFlags
            if flags.contains(.control) {
                carbonMods |= UInt32(controlKey)
                displayParts.append("⌃")
            }
            if flags.contains(.option) {
                carbonMods |= UInt32(optionKey)
                displayParts.append("⌥")
            }
            if flags.contains(.shift) {
                carbonMods |= UInt32(shiftKey)
                displayParts.append("⇧")
            }
            if flags.contains(.command) {
                carbonMods |= UInt32(cmdKey)
                displayParts.append("⌘")
            }

            // Esc without modifiers cancels recording
            if event.keyCode == 53 && carbonMods == 0 {
                stopTranslateRecording()
                return nil
            }

            let keyStr = AppSettings.displayStringForKeyCode(event.keyCode, characters: event.charactersIgnoringModifiers)
            if !keyStr.isEmpty {
                displayParts.append(keyStr)
            }

            if carbonMods != 0 && !keyStr.isEmpty {
                let display = displayParts.joined(separator: " + ")
                settings.setTranslateHotKey(
                    keyCode: UInt32(event.keyCode),
                    modifiers: carbonMods,
                    display: display
                )
                stopTranslateRecording()
                return nil
            }

            return event
        }
    }

    private func stopTranslateRecording() {
        isRecordingTranslateCustom = false
        if let monitor = localTranslateMonitor {
            NSEvent.removeMonitor(monitor)
            localTranslateMonitor = nil
        }
    }

    private func promptAddExcludedApp() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedContentTypes = [.application]
        openPanel.directoryURL = URL(fileURLWithPath: "/Applications")

        if openPanel.runModal() == .OK, let url = openPanel.url {
            if let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier {
                settings.addExcludedApp(bundleID: bundleID)
            }
        }
    }

    private static let checkDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    private func formatDate(_ date: Date) -> String {
        return Self.checkDateFormatter.string(from: date)
    }
}
