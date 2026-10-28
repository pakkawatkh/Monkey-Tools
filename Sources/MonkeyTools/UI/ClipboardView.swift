import SwiftUI

public struct ClipboardView: View {
    @ObservedObject var manager: ClipboardManager = .shared
    @ObservedObject var autoPaster: AutoPaster = .shared
    @ObservedObject var settings: AppSettings = .shared
    @ObservedObject var emojiManager: EmojiManager = .shared
    @ObservedObject var loc: LocalizationManager = .shared

    public var onSelect: (ClipboardItem) -> Void
    public var onClose: () -> Void

    @FocusState private var isSearchFocused: Bool
    @State private var showingClearConfirmation = false

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

            // Main Content Area
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

            customDivider

            // Bottom status bar
            bottomBar
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
        }
        .frame(width: 320, height: 520)
        .background(
            ZStack {
                VisualEffectBackground()
                Color(red: 0.10, green: 0.10, blue: 0.12).opacity(0.85)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .preferredColorScheme(.dark)
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
            .fill(Color.white.opacity(0.10))
            .frame(height: 1)
    }

    private var headerView: some View {
        VStack(spacing: 8) {
            // Top Row: Tabs + Window Controls
            HStack(spacing: 6) {
                // Tab Switcher (Clipboard vs Emoji)
                HStack(spacing: 2) {
                    tabButton(title: loc["tab_clipboard"], icon: "doc.on.clipboard", tab: .clipboard)
                    tabButton(title: loc["tab_emoji"], icon: "face.smiling", tab: .emoji)
                }
                .padding(2)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 7))

                Spacer()

                // Settings button
                Button(action: {
                    SettingsWindowController.shared.showSettings()
                }) {
                    Image(systemName: "gearshape")
                        .foregroundColor(Color.white.opacity(0.80))
                        .font(.system(size: 11))
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help(loc["menu_settings_item"])

                // Close button
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .foregroundColor(Color.white.opacity(0.80))
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help(loc["shortcut_esc"])
            }

            // Search Bar
            searchField
        }
    }

    private func tabButton(title: String, icon: String, tab: ClipboardActiveTab) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                manager.activeTab = tab
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: manager.activeTab == tab ? .semibold : .medium))
                Text(title)
                    .font(.system(size: 11, weight: manager.activeTab == tab ? .semibold : .medium))
            }
            .foregroundColor(manager.activeTab == tab ? .white : Color.white.opacity(0.70))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(manager.activeTab == tab ? Color.white.opacity(0.18) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.white.opacity(0.65))
                .font(.system(size: 12, weight: .medium))

            if manager.activeTab == .clipboard {
                ZStack(alignment: .leading) {
                    if manager.searchQuery.isEmpty {
                        Text(loc["search_placeholder"])
                            .font(.system(size: 12))
                            .foregroundColor(Color.white.opacity(0.55))
                    }
                    TextField("", text: $manager.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .focused($isSearchFocused)
                }

                if !manager.searchQuery.isEmpty {
                    Button(action: { manager.searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.white.opacity(0.65))
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                ZStack(alignment: .leading) {
                    if emojiManager.searchQuery.isEmpty {
                        Text(loc["search_emoji_placeholder"])
                            .font(.system(size: 12))
                            .foregroundColor(Color.white.opacity(0.55))
                    }
                    TextField("", text: $emojiManager.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .focused($isSearchFocused)
                }

                if !emojiManager.searchQuery.isEmpty {
                    Button(action: { emojiManager.searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.white.opacity(0.65))
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var accessibilityBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(Color(red: 0.4, green: 0.7, blue: 1.0))
                .font(.system(size: 11))

            Text(loc["enable_accessibility"])
                .font(.system(size: 10))
                .foregroundColor(Color.white.opacity(0.9))

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
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(red: 0.15, green: 0.28, blue: 0.48).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(red: 0.35, green: 0.55, blue: 0.90).opacity(0.3), lineWidth: 1)
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
                            }
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
                .foregroundColor(Color.white.opacity(0.35))

            if manager.searchQuery.isEmpty {
                Text(loc["clipboard_empty"])
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text(loc["clipboard_empty_hint"])
                    .font(.system(size: 11))
                    .foregroundColor(Color.white.opacity(0.70))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            } else {
                Text(loc["no_results"])
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text(loc["no_results_hint"])
                    .font(.system(size: 11))
                    .foregroundColor(Color.white.opacity(0.70))
            }
            Spacer()
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 8) {
            if manager.activeTab == .clipboard {
                Text("\(manager.filteredItems.count) \(loc["items_count"])")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.75))

                Spacer()

                HStack(spacing: 4) {
                    Text("↑↓")
                    Text("•")
                    Text(loc["shortcut_enter_paste"])
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color.white.opacity(0.65))

                Spacer()

                Button(action: {
                    showingClearConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.white.opacity(manager.items.isEmpty ? 0.30 : 0.75))
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
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
                        .foregroundColor(Color.white.opacity(0.75))
                }

                Spacer()

                Text(loc["shortcut_esc"])
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.65))
            }
        }
    }
}

// Visual Effect View for clean frosted glass background in dark mode
public struct VisualEffectBackground: NSViewRepresentable {
    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .hudWindow
        view.appearance = NSAppearance(named: .darkAqua)
        view.wantsLayer = true
        view.layer?.cornerRadius = 14
        view.layer?.masksToBounds = true
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
