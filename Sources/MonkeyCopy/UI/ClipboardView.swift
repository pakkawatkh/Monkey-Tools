import SwiftUI

public struct ClipboardView: View {
    public enum ActiveTab {
        case clipboard
        case emoji
    }

    @ObservedObject var manager: ClipboardManager = .shared
    @ObservedObject var autoPaster: AutoPaster = .shared
    @ObservedObject var settings: AppSettings = .shared
    @ObservedObject var emojiManager: EmojiManager = .shared

    public var onSelect: (ClipboardItem) -> Void
    public var onClose: () -> Void

    @FocusState private var isSearchFocused: Bool
    @State private var activeTab: ActiveTab = .clipboard
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
            if activeTab == .clipboard {
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
        .background(VisualEffectBackground())
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .preferredColorScheme(.dark)
        .onAppear {
            isSearchFocused = true
            autoPaster.refreshAccessibilityStatus()
        }
        .alert("Clear clipboard history?", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear (Keep Pinned)", role: .none) {
                manager.clearAll(includingPinned: false)
            }
            Button("Clear Everything", role: .destructive) {
                manager.clearAll(includingPinned: true)
            }
        } message: {
            Text("Do you want to clear unpinned history or everything?")
        }
    }

    // MARK: - Subviews

    private var customDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 1)
    }

    private var headerView: some View {
        VStack(spacing: 8) {
            // Top Row: Tabs + Window Controls
            HStack(spacing: 6) {
                // Tab Switcher (Clipboard vs Emoji)
                HStack(spacing: 2) {
                    tabButton(title: "Clipboard", icon: "doc.on.clipboard", tab: .clipboard)
                    tabButton(title: "Emoji", icon: "face.smiling", tab: .emoji)
                }
                .padding(2)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 7))

                Spacer()

                // Settings button
                Button(action: {
                    SettingsWindowController.shared.showSettings()
                }) {
                    Image(systemName: "gearshape")
                        .foregroundColor(Color.white.opacity(0.65))
                        .font(.system(size: 11))
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help("Settings...")

                // Close button
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .foregroundColor(Color.white.opacity(0.65))
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help("Close (Esc)")
            }

            // Search Bar
            searchField
        }
    }

    private func tabButton(title: String, icon: String, tab: ActiveTab) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                activeTab = tab
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(activeTab == tab ? .white : Color.white.opacity(0.55))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(activeTab == tab ? Color.white.opacity(0.14) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.white.opacity(0.45))
                .font(.system(size: 12))

            if activeTab == .clipboard {
                TextField("Search history... (↑↓)", text: $manager.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.95))
                    .focused($isSearchFocused)

                if !manager.searchQuery.isEmpty {
                    Button(action: { manager.searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.white.opacity(0.45))
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                TextField("Search emojis... (e.g. smile, heart, ลิง)", text: $emojiManager.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.95))
                    .focused($isSearchFocused)

                if !emojiManager.searchQuery.isEmpty {
                    Button(action: { emojiManager.searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.white.opacity(0.45))
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var accessibilityBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(Color(red: 0.4, green: 0.7, blue: 1.0))
                .font(.system(size: 11))

            Text("Enable Accessibility to Auto-Paste")
                .font(.system(size: 10))
                .foregroundColor(Color.white.opacity(0.9))

            Spacer()

            Button("Enable") {
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
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 32))
                .foregroundColor(Color.white.opacity(0.25))

            if manager.searchQuery.isEmpty {
                Text("Clipboard is empty")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.70))
                Text("Copy text or images (⌘C) to build your history.")
                    .font(.system(size: 11))
                    .foregroundColor(Color.white.opacity(0.40))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            } else {
                Text("No matching results")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.70))
                Text("Try searching for text or 'image'.")
                    .font(.system(size: 11))
                    .foregroundColor(Color.white.opacity(0.40))
            }
            Spacer()
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 8) {
            if activeTab == .clipboard {
                Text("\(manager.filteredItems.count) items")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.45))

                Spacer()

                HStack(spacing: 4) {
                    Text("↑↓ Navigate")
                    Text("•")
                    Text("↵ Paste")
                }
                .font(.system(size: 9))
                .foregroundColor(Color.white.opacity(0.35))

                Spacer()

                Button("Clear") {
                    showingClearConfirmation = true
                }
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .foregroundColor(Color.white.opacity(0.45))
                .disabled(manager.items.isEmpty)
            } else {
                HStack(spacing: 4) {
                    Text("💡")
                    Text("Click any emoji to paste directly")
                        .font(.system(size: 10))
                        .foregroundColor(Color.white.opacity(0.55))
                }

                Spacer()

                Text("Esc Close")
                    .font(.system(size: 9))
                    .foregroundColor(Color.white.opacity(0.35))
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
