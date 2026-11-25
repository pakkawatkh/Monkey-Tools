import AppKit
import SwiftUI

struct MonkeyFrontmostAppSnapshot: Equatable {
    let name: String
    let bundleID: String
}

enum MonkeyPopoverSection: Equatable {
    case history
    case currentApp
    case language
}

@MainActor
final class MonkeyPopoverViewModel: ObservableObject {
    @Published var frontmostApp: MonkeyFrontmostAppSnapshot?
    @Published var isAccessibilityGranted: Bool = true
    @Published var expandedSection: MonkeyPopoverSection? = nil

    func refreshState() {
        isAccessibilityGranted = AutoPaster.shared.isAccessibilityGranted

        let ownBundleID = Bundle.main.bundleIdentifier
        if let app = NSWorkspace.shared.frontmostApplication,
           let name = app.localizedName,
           let bundleID = app.bundleIdentifier,
           bundleID != ownBundleID {
            frontmostApp = MonkeyFrontmostAppSnapshot(name: name, bundleID: bundleID)
        } else {
            frontmostApp = nil
        }
    }

    func toggleSection(_ section: MonkeyPopoverSection) {
        withAnimation(.easeInOut(duration: 0.14)) {
            if expandedSection == section {
                expandedSection = nil
            } else {
                expandedSection = section
            }
        }
    }
}

struct MonkeyStatusPopoverView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var monitor: ClipboardMonitor
    @ObservedObject var clipboard: ClipboardManager
    @ObservedObject var localization: LocalizationManager
    @ObservedObject var updateChecker: UpdateCheckService
    @ObservedObject var updateInstaller: UpdateInstallerService
    @ObservedObject var viewModel: MonkeyPopoverViewModel

    let onShowClipboard: () -> Void
    let onOpenAccessibility: () -> Void
    let onOpenSettings: () -> Void
    let onOpenUpdateDownload: () -> Void
    let onCheckUpdates: () -> Void
    let onQuit: () -> Void

    private var currentVersion: String {
        updateChecker.currentAppVersion
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if !viewModel.isAccessibilityGranted {
                accessibilitySection
                menuDivider
            }

            if updateInstaller.isInstalling {
                let pct = Int(updateInstaller.downloadProgress * 100)
                MonkeyIconMenuRow(
                    symbol: "arrow.down.circle",
                    title: "\(localization["update_downloading"]) (\(pct)%)"
                ) {
                    onOpenUpdateDownload()
                }
                menuDivider
            } else if updateChecker.updateAvailable {
                let version = updateChecker.latestUpdateInfo?.latestVersion ?? ""
                MonkeyIconMenuRow(
                    symbol: "sparkles",
                    title: "\(localization["menu_update_available"]) (v\(version))"
                ) {
                    onOpenUpdateDownload()
                }
                menuDivider
            }

            // Section 1: Core toggles (stays open on click)
            MonkeyCheckmarkMenuRow(
                title: localization["popover_clipboard_capture"],
                isChecked: !monitor.isPaused
            ) {
                monitor.togglePause()
            }

            MonkeyCheckmarkMenuRow(
                title: localization["popover_auto_paste"],
                isChecked: settings.autoPasteEnabled
            ) {
                settings.autoPasteEnabled.toggle()
            }

            MonkeyCheckmarkMenuRow(
                title: localization["popover_selection_translate"],
                isChecked: settings.selectionTranslateEnabled
            ) {
                settings.selectionTranslateEnabled.toggle()
            }

            menuDivider

            // Section 2: Quick clipboard & expandable sections
            MonkeyIconMenuRow(
                symbol: "doc.on.clipboard",
                title: localization["menu_show_monkey"],
                shortcut: settings.hotkeyDisplayString
            ) {
                onShowClipboard()
            }

            historySection

            if let app = viewModel.frontmostApp {
                currentAppSection(app)
            }

            menuDivider

            // Section 3: App controls
            MonkeyIconMenuRow(
                symbol: "gearshape",
                title: localization["menu_settings_item"],
                shortcut: "⌘,"
            ) {
                onOpenSettings()
            }

            languageSection

            menuDivider

            // Section 4: Updates & Quit
            MonkeyPlainMenuRow(
                title: "v\(currentVersion) · \(localization["menu_check_updates"])"
            ) {
                onCheckUpdates()
            }

            MonkeyPlainMenuRow(
                title: localization["menu_quit_item"],
                shortcut: "⌘Q"
            ) {
                onQuit()
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .frame(width: 268)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Sections

    private var accessibilitySection: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 13))
                    .foregroundStyle(.orange)
                    .frame(width: 16, alignment: .center)
                Text(localization["popover_access_required"])
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)

            MonkeyIconMenuRow(
                symbol: "lock.shield",
                title: localization["menu_access_enable"]
            ) {
                onOpenAccessibility()
            }
        }
    }

    private var historySection: some View {
        let isExpanded = viewModel.expandedSection == .history
        let count = clipboard.items.count
        let title = "\(localization["popover_history"]) (\(count))"

        return VStack(alignment: .leading, spacing: 2) {
            MonkeyExpandableMenuRow(
                symbol: "clock.arrow.circlepath",
                title: title,
                isExpanded: isExpanded
            ) {
                viewModel.toggleSection(.history)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    MonkeySubActionRow(
                        symbol: "trash",
                        title: localization["menu_clear_unpinned"],
                        isEnabled: count > 0
                    ) {
                        clipboard.clearAll(includingPinned: false)
                    }

                    MonkeySubActionRow(
                        symbol: "trash.fill",
                        title: localization["menu_clear_all"],
                        isDestructive: true,
                        isEnabled: count > 0
                    ) {
                        clipboard.clearAll(includingPinned: true)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )
                .padding(.horizontal, 4)
                .padding(.bottom, 2)
            }
        }
    }

    private func currentAppSection(_ app: MonkeyFrontmostAppSnapshot) -> some View {
        let isExpanded = viewModel.expandedSection == .currentApp
        let isClipboardExcluded = settings.excludedAppBundleIDs.contains(app.bundleID)
        let isTranslateExcluded = settings.translatorExcludedAppBundleIDs.contains(app.bundleID)

        return VStack(alignment: .leading, spacing: 2) {
            MonkeyExpandableMenuRow(
                symbol: "macwindow",
                title: app.name,
                isExpanded: isExpanded
            ) {
                viewModel.toggleSection(.currentApp)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    MonkeyCheckmarkMenuRow(
                        title: localization["popover_ignore_clipboard"],
                        isChecked: isClipboardExcluded,
                        compact: true
                    ) {
                        toggleExcludedBundle(app.bundleID, in: &settings.excludedAppBundleIDs)
                    }

                    MonkeyCheckmarkMenuRow(
                        title: localization["popover_ignore_translate"],
                        isChecked: isTranslateExcluded,
                        compact: true
                    ) {
                        toggleExcludedBundle(app.bundleID, in: &settings.translatorExcludedAppBundleIDs)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )
                .padding(.horizontal, 4)
                .padding(.bottom, 2)
            }
        }
    }

    private var languageSection: some View {
        let isExpanded = viewModel.expandedSection == .language
        let code = localization.effectiveLanguageCode
        let badge: String = {
            switch code {
            case "th": return "ไทย"
            case "zh": return "中文"
            default: return "EN"
            }
        }()

        return VStack(alignment: .leading, spacing: 2) {
            MonkeyExpandableMenuRow(
                symbol: "globe",
                title: localization["popover_language"],
                trailingText: badge,
                isExpanded: isExpanded
            ) {
                viewModel.toggleSection(.language)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    MonkeyCheckmarkMenuRow(
                        title: "ไทย",
                        isChecked: code == "th",
                        compact: true
                    ) {
                        settings.appLanguage = "th"
                    }

                    MonkeyCheckmarkMenuRow(
                        title: "English",
                        isChecked: code == "en",
                        compact: true
                    ) {
                        settings.appLanguage = "en"
                    }

                    MonkeyCheckmarkMenuRow(
                        title: "中文",
                        isChecked: code == "zh",
                        compact: true
                    ) {
                        settings.appLanguage = "zh"
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )
                .padding(.horizontal, 4)
                .padding(.bottom, 2)
            }
        }
    }

    private var menuDivider: some View {
        Divider()
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
    }

    private func toggleExcludedBundle(_ bundleID: String, in list: inout [String]) {
        if let idx = list.firstIndex(of: bundleID) {
            list.remove(at: idx)
        } else {
            list.append(bundleID)
        }
    }
}

// MARK: - Reusable Native-Style Menu Rows

private struct MonkeyCheckmarkMenuRow: View {
    let title: String
    let isChecked: Bool
    var isEnabled: Bool = true
    var compact: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: compact ? 11 : 12, weight: .semibold))
                    .opacity(isChecked ? 1 : 0)
                    .frame(width: 16, alignment: .center)

                Text(title)
                    .font(.system(size: compact ? 12.5 : 13))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, compact ? 4 : 5)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isHovered && isEnabled ? Color.accentColor : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var foregroundColor: Color {
        if !isEnabled {
            return .secondary.opacity(0.5)
        }
        return isHovered ? .white : .primary
    }
}

private struct MonkeyIconMenuRow: View {
    let symbol: String
    let title: String
    var shortcut: String? = nil
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 13))
                    .frame(width: 16, alignment: .center)

                Text(title)
                    .font(.system(size: 13))
                    .lineLimit(1)

                Spacer(minLength: 8)

                if let shortcut {
                    Text(shortcut)
                        .font(.system(size: 12))
                        .foregroundStyle(isHovered ? Color.white.opacity(0.85) : Color.secondary)
                }
            }
            .foregroundStyle(isHovered ? .white : .primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isHovered ? Color.accentColor : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

private struct MonkeySubActionRow: View {
    let symbol: String
    let title: String
    var isDestructive: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 11.5))
                    .frame(width: 16, alignment: .center)

                Text(title)
                    .font(.system(size: 12.5))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(hoverBackground)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var foregroundColor: Color {
        if !isEnabled {
            return .secondary.opacity(0.5)
        }
        if isHovered {
            return .white
        }
        return isDestructive ? .red : .primary
    }

    private var hoverBackground: Color {
        guard isHovered && isEnabled else { return .clear }
        return isDestructive ? .red : Color.accentColor
    }
}

private struct MonkeyExpandableMenuRow: View {
    let symbol: String
    let title: String
    var trailingText: String? = nil
    let isExpanded: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 13))
                    .frame(width: 16, alignment: .center)

                Text(title)
                    .font(.system(size: 13))
                    .lineLimit(1)

                Spacer(minLength: 8)

                if let trailingText {
                    Text(trailingText)
                        .font(.system(size: 11.5))
                        .foregroundStyle(isHovered ? Color.white.opacity(0.85) : Color.secondary)
                }

                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(isHovered ? Color.white.opacity(0.9) : Color.secondary)
                    .frame(width: 12, alignment: .center)
            }
            .foregroundStyle(isHovered ? .white : .primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isHovered ? Color.accentColor : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

private struct MonkeyPlainMenuRow: View {
    let title: String
    var shortcut: String? = nil
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Color.clear
                    .frame(width: 16, height: 1)

                Text(title)
                    .font(.system(size: 13))
                    .lineLimit(1)

                Spacer(minLength: 8)

                if let shortcut {
                    Text(shortcut)
                        .font(.system(size: 12))
                        .foregroundStyle(isHovered ? Color.white.opacity(0.85) : Color.secondary)
                }
            }
            .foregroundStyle(isHovered ? .white : .primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isHovered ? Color.accentColor : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
