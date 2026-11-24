import SwiftUI

public struct ClipboardView: View {
    @ObservedObject var manager: ClipboardManager = .shared
    @ObservedObject var monitor: ClipboardMonitor = .shared
    @ObservedObject var autoPaster: AutoPaster = .shared
    @ObservedObject var settings: AppSettings = .shared
    @ObservedObject var emojiManager: EmojiManager = .shared
    @ObservedObject var loc: LocalizationManager = .shared
    @Environment(\.colorScheme) private var colorScheme

    public var onSelect: (ClipboardItem) -> Void
    public var onClose: () -> Void

    @FocusState private var isSearchFocused: Bool
    @State private var showingClearConfirmation = false
    @State private var toastMessage: String? = nil
    @State private var isExtractingOCR = false

    public init(onSelect: @escaping (ClipboardItem) -> Void, onClose: @escaping () -> Void) {
        self.onSelect = onSelect
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header with Tab Switcher & Search Bar
            headerView
                .padding(.horizontal, 10)
                .padding(.top, 10)
                .padding(.bottom, 8)

            customDivider

            // Accessibility banner: ONLY shown when Auto-Paste is enabled AND accessibility is NOT granted yet!
            if settings.autoPasteEnabled && !autoPaster.isAccessibilityGranted {
                accessibilityBanner
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                customDivider
            }

            // Paused banner when user paused clipboard capture
            if monitor.isPaused {
                pausedBanner
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                customDivider
            }

            // Main Content Area
            ZStack {
                if manager.activeTab == .clipboard {
                    let items = manager.filteredItems
                    if items.isEmpty {
                        emptyStateView
                    } else {
                        itemsListView(items: items)
                    }
                } else {
                    EmojiPickerView { emoji in
                        AutoPaster.shared.pasteEmoji(emoji)
                    }
                }

                // Quick Preview Overlay
                if let previewItem = manager.previewItem {
                    quickPreviewOverlay(for: previewItem)
                        .transition(.opacity)
                }

                // Transient Toast Notification (e.g. OCR result)
                if let toast = toastMessage {
                    VStack {
                        Spacer()
                        HStack(spacing: 6) {
                            if isExtractingOCR {
                                ProgressView()
                                    .controlSize(.mini)
                                    .scaleEffect(0.8)
                            }
                            Text(toast)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.black.opacity(0.85))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
                        .padding(.bottom, 10)
                    }
                    .transition(.opacity)
                }
            }

            customDivider

            // Bottom status bar
            bottomBar
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
        }
        .frame(width: 340, height: 540)
        .background(
            ZStack {
                AdaptiveVisualEffectView(material: .popover, cornerRadius: 18)
                ModernTheme.panelTint(for: colorScheme)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ModernTheme.glassRimGradient(for: colorScheme), lineWidth: 1)
        )
        .onAppear {
            isSearchFocused = true
            autoPaster.refreshAccessibilityStatus()
        }
        .alert(loc["clear_history_alert_title"], isPresented: $showingClearConfirmation) {
            Button(loc["cancel"], role: .cancel) {}
            Button(loc["clear_keep_pinned"], role: .none) {
                manager.clearAll(includingPinned: false)
            }
            Button(loc["clear_everything"], role: .destructive) {
                manager.clearAll(includingPinned: true)
            }
        } message: {
            Text(loc["clear_history_alert_msg"])
        }
    }

    // MARK: - Subviews

    private var customDivider: some View {
        Rectangle()
            .fill(ModernTheme.divider(for: colorScheme))
            .frame(height: 1)
    }

    private var headerView: some View {
        VStack(spacing: 9) {
            // Top Row: Tabs + Window Controls
            HStack(spacing: 6) {
                // Tab Switcher (Clipboard vs Emoji)
                HStack(spacing: 2) {
                    tabButton(title: loc["tab_clipboard"], icon: "doc.on.clipboard", tab: .clipboard)
                    tabButton(title: loc["tab_emoji"], icon: "face.smiling", tab: .emoji)
                }
                .padding(3)
                .background(ModernTheme.controlFill(for: colorScheme))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(ModernTheme.controlBorder(for: colorScheme), lineWidth: 0.75))

                Spacer()

                // Settings button
                Button(action: {
                    SettingsWindowController.shared.showSettings()
                }) {
                    Image(systemName: "gearshape")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 11.5, weight: .medium))
                        .frame(width: 26, height: 26)
                        .background(ModernTheme.controlFill(for: colorScheme))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(ModernTheme.controlBorder(for: colorScheme), lineWidth: 0.75))
                }
                .buttonStyle(.plain)
                .help(loc["menu_settings_item"])

                // Close button
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 26, height: 26)
                        .background(ModernTheme.controlFill(for: colorScheme))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(ModernTheme.controlBorder(for: colorScheme), lineWidth: 0.75))
                }
                .buttonStyle(.plain)
                .help(loc["shortcut_esc"])
            }

            // Search Bar
            searchField

            // Category Filter Pills
            if manager.activeTab == .clipboard {
                filterPillsView
            }
        }
    }

    private var filterPillsView: some View {
        HStack(spacing: 5) {
            ForEach(ClipboardCategoryFilter.allCases) { filter in
                let isSelected = manager.selectedFilter == filter
                Button(action: {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                        manager.selectedFilter = filter
                    }
                }) {
                    Text(filter.title(loc: loc))
                        .font(.system(size: 10.5, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? AnyShapeStyle(Color.white) : AnyShapeStyle(.secondary))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3.5)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.accentColor : ModernTheme.controlFill(for: colorScheme))
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private func tabButton(title: String, icon: String, tab: ClipboardActiveTab) -> some View {
        let isActive = manager.activeTab == tab
        return Button(action: {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                manager.activeTab = tab
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: isActive ? .semibold : .medium))
                Text(title)
                    .font(.system(size: 11, weight: isActive ? .semibold : .medium))
            }
            .foregroundStyle(isActive ? AnyShapeStyle(Color.primary) : AnyShapeStyle(.secondary))
            .padding(.horizontal, 10)
            .padding(.vertical, 4.5)
            .background(
                Capsule()
                    .fill(isActive ? (colorScheme == .dark ? Color.white.opacity(0.18) : Color.white.opacity(0.92)) : Color.clear)
                    .shadow(color: isActive ? Color.black.opacity(0.08) : .clear, radius: 2, y: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 12, weight: .medium))

            if manager.activeTab == .clipboard {
                ZStack(alignment: .leading) {
                    if manager.searchQuery.isEmpty {
                        Text(loc["search_placeholder"])
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                    TextField("", text: $manager.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.primary)
                        .focused($isSearchFocused)
                }

                if !manager.searchQuery.isEmpty {
                    Button(action: { manager.searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                ZStack(alignment: .leading) {
                    if emojiManager.searchQuery.isEmpty {
                        Text(loc["search_emoji_placeholder"])
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                    TextField("", text: $emojiManager.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.primary)
                        .focused($isSearchFocused)
                }

                if !emojiManager.searchQuery.isEmpty {
                    Button(action: { emojiManager.searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6.5)
        .background(ModernTheme.controlFill(for: colorScheme))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(ModernTheme.controlBorder(for: colorScheme), lineWidth: 0.75)
        )
    }

    private var pausedBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "pause.circle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 11))

            Text(loc["clipboard_paused_banner"])
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.primary)

            Spacer()

            Button(loc["clipboard_resume_btn"]) {
                monitor.togglePause()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.mini)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(colorScheme == .dark ? 0.18 : 0.14))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.orange.opacity(0.35), lineWidth: 0.75)
        )
    }

    private func quickPreviewOverlay(for item: ClipboardItem) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                if let appIcon = item.loadSourceAppIcon() {
                    Image(nsImage: appIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                }
                Text(item.sourceAppName ?? (item.type == .image ? "Image" : loc["tab_text"]))
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text("• \(item.localizedRelativeTime(loc: loc))")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        manager.previewItem = nil
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(ModernTheme.controlFill(for: colorScheme))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help(loc["preview_close"])
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)

            customDivider

            ScrollView {
                if item.type == .image {
                    if let fullImg = item.loadImage() {
                        Image(nsImage: fullImg)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .padding(10)
                    }
                } else if let text = item.text {
                    VStack(alignment: .leading, spacing: 8) {
                        if let nsColor = item.detectedHexColor {
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color(nsColor: nsColor))
                                    .frame(width: 32, height: 32)
                                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(ModernTheme.controlBorder(for: colorScheme), lineWidth: 1))
                                Text(text.trimmingCharacters(in: .whitespacesAndNewlines))
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.primary)
                            }
                        }
                        Text(text)
                            .font(.system(size: 12.5))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(12)
                }
            }

            customDivider

            HStack(spacing: 8) {
                Button(action: {
                    manager.previewItem = nil
                    onSelect(item)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 10))
                        Text(loc["preview_paste"])
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                if item.type == .text {
                    Button(action: {
                        manager.previewItem = nil
                        translateClipboardItem(item)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "globe")
                                .font(.system(size: 10))
                            Text(loc["tab_translator"])
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(ModernTheme.controlFill(for: colorScheme))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                } else if item.type == .image {
                    Button(action: {
                        manager.previewItem = nil
                        extractTextFromImage(item)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text.viewfinder")
                                .font(.system(size: 10))
                            Text("OCR")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(ModernTheme.controlFill(for: colorScheme))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button(loc["preview_close"]) {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        manager.previewItem = nil
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(.regularMaterial)
    }

    private func translateClipboardItem(_ item: ClipboardItem) {
        guard let text = item.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        onClose()
        DispatchQueue.main.async {
            TranslationPopoverPanel.shared.show(text: text, near: NSEvent.mouseLocation, sourceAppPID: 0, isEditable: false)
        }
    }

    private func extractTextFromImage(_ item: ClipboardItem) {
        guard item.type == .image, let data = item.loadImageData() else { return }
        isExtractingOCR = true
        showToast(loc["ocr_processing"], autoDismiss: false)

        Task {
            let extracted = await OCRService.shared.extractText(from: data)
            await MainActor.run {
                self.isExtractingOCR = false
                if let text = extracted, !text.isEmpty {
                    ClipboardMonitor.shared.markProgrammaticWrite(text: text)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    ClipboardManager.shared.add(text: text, sourceAppBundleID: Bundle.main.bundleIdentifier, sourceAppName: "OCR")
                    self.showToast(loc["ocr_copied"], autoDismiss: true)
                } else {
                    self.showToast(loc["ocr_no_text"], autoDismiss: true)
                }
            }
        }
    }

    private func showToast(_ message: String, autoDismiss: Bool) {
        withAnimation(.easeInOut(duration: 0.15)) {
            toastMessage = message
        }
        if autoDismiss {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if self.toastMessage == message {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.toastMessage = nil
                    }
                }
            }
        }
    }

    private var accessibilityBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Color.accentColor)
                .font(.system(size: 11))

            Text(loc["enable_accessibility"])
                .font(.system(size: 10.5))
                .foregroundStyle(.primary)

            Spacer()

            Button(loc["enable_btn"]) {
                AutoPaster.shared.openAccessibilitySettings()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    autoPaster.refreshAccessibilityStatus()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.mini)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(colorScheme == .dark ? 0.18 : 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.accentColor.opacity(0.30), lineWidth: 0.75)
        )
    }

    private func itemsListView(items: [ClipboardItem]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        ClipboardItemRow(
                            item: item,
                            index: index,
                            isSelected: index == manager.selectedIndex,
                            onSelect: {
                                manager.selectedIndex = index
                                onSelect(item)
                            },
                            onTogglePin: {
                                manager.togglePin(for: item)
                            },
                            onDelete: {
                                manager.delete(item: item)
                            },
                            onPreview: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    manager.previewItem = item
                                }
                            },
                            onTranslate: item.type == .text ? {
                                translateClipboardItem(item)
                            } : nil,
                            onOCR: item.type == .image ? {
                                extractTextFromImage(item)
                            } : nil
                        )
                        .id(item.id)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .onChange(of: manager.selectedIndex) { newIndex in
                if newIndex >= 0 && newIndex < items.count {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        proxy.scrollTo(items[newIndex].id, anchor: .center)
                    }
                }
            }
            .onChange(of: manager.searchQuery) { _ in
                if let first = items.first {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        proxy.scrollTo(first.id, anchor: .top)
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 34))
                .foregroundStyle(.tertiary)

            if manager.searchQuery.isEmpty {
                Text(loc["clipboard_empty"])
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(loc["clipboard_empty_hint"])
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            } else {
                Text(loc["no_results"])
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(loc["no_results_hint"])
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 8) {
            if manager.activeTab == .clipboard {
                Text("\(manager.filteredItems.count) \(loc["items_count"])")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: 4) {
                    Text("↑↓")
                    Text("•")
                    Text("⌘1-9")
                    Text("•")
                    Text(loc["shortcut_enter_paste"])
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)

                Spacer()

                Button(action: {
                    showingClearConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(manager.items.isEmpty ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.secondary))
                        .frame(width: 24, height: 24)
                        .background(ModernTheme.controlFill(for: colorScheme))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(ModernTheme.controlBorder(for: colorScheme), lineWidth: 0.75)
                        )
                }
                .buttonStyle(.plain)
                .disabled(manager.items.isEmpty)
                .help(loc["clear_history"])
            } else {
                HStack(spacing: 4) {
                    Text("💡")
                    Text(loc["click_emoji_hint"])
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(loc["shortcut_esc"])
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
