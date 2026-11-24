import SwiftUI
import AppKit

public struct ClipboardItemRow: View {
    public let item: ClipboardItem
    public let index: Int?
    public let isSelected: Bool
    public let onSelect: () -> Void
    public let onTogglePin: () -> Void
    public let onDelete: () -> Void
    public var onPreview: (() -> Void)? = nil
    public var onTranslate: (() -> Void)? = nil
    public var onOCR: (() -> Void)? = nil

    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    public init(
        item: ClipboardItem,
        index: Int?,
        isSelected: Bool,
        onSelect: @escaping () -> Void,
        onTogglePin: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onPreview: (() -> Void)? = nil,
        onTranslate: (() -> Void)? = nil,
        onOCR: (() -> Void)? = nil
    ) {
        self.item = item
        self.index = index
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.onTogglePin = onTogglePin
        self.onDelete = onDelete
        self.onPreview = onPreview
        self.onTranslate = onTranslate
        self.onOCR = onOCR
    }

    public var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                // Header line: shortcut badge, source app icon, type icon, time, actions
                HStack(alignment: .center, spacing: 5) {
                    if let idx = index, idx < 9 {
                        Text("⌘\(idx + 1)")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color.accentColor.opacity(0.18) : ModernTheme.controlFill(for: colorScheme))
                            )
                    }

                    if let appIcon = item.loadSourceAppIcon() {
                        Image(nsImage: appIcon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 13, height: 13)
                            .help(item.sourceAppName ?? item.sourceAppBundleID ?? "")
                    }

                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }

                    if item.type == .image {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.accentColor)
                    }

                    Text(item.localizedRelativeTime(loc: loc))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    // Info tag: chars or image dimensions (hidden when hovered to give room for action buttons)
                    if !isHovered {
                        if item.type == .image {
                            if let w = item.imageWidth, let h = item.imageHeight {
                                Text("\(w)×\(h)")
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                            } else {
                                Text("Image")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.tertiary)
                            }
                        } else {
                            Text("\(item.characterCount)c")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                    }

                    // Action buttons
                    HStack(spacing: 2) {
                        if let url = item.detectedURL {
                            Button(action: {
                                NSWorkspace.shared.open(url)
                            }) {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 20, height: 20)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help(loc["open_url"])
                        }

                        if let onPreview = onPreview {
                            Button(action: onPreview) {
                                Image(systemName: "eye")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20, height: 20)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help(loc["preview_item"])
                        }

                        if item.type == .text, let onTranslate = onTranslate {
                            Button(action: onTranslate) {
                                Image(systemName: "globe")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 20, height: 20)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help(loc["translate_item"])
                        }

                        if item.type == .image, let onOCR = onOCR {
                            Button(action: onOCR) {
                                Image(systemName: "doc.text.viewfinder")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.green)
                                    .frame(width: 20, height: 20)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help(loc["ocr_extract"])
                        }

                        Button(action: onTogglePin) {
                            Image(systemName: item.isPinned ? "pin.slash" : "pin")
                                .font(.system(size: 11))
                                .foregroundStyle(item.isPinned ? AnyShapeStyle(Color.orange) : AnyShapeStyle(.secondary))
                                .frame(width: 20, height: 20)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(loc[item.isPinned ? "unpin_item" : "pin_item"])

                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .frame(width: 20, height: 20)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(loc["delete_item"])
                    }
                    .opacity(isHovered || item.isPinned ? 1.0 : 0.0)
                }

                // Content preview (Image or Text)
                if item.type == .image {
                    imagePreview
                } else {
                    textPreview
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(borderColor, lineWidth: isSelected ? 1.5 : 0.75)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }

    // Text content (with optional Hex Color swatch)
    private var textPreview: some View {
        HStack(alignment: .center, spacing: 7) {
            if let nsColor = item.detectedHexColor {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color(nsColor: nsColor))
                    .frame(width: 18, height: 18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(ModernTheme.controlBorder(for: colorScheme), lineWidth: 1)
                    )
            }

            Text(item.previewText)
                .font(.system(size: 12.5, weight: .regular))
                .foregroundStyle(.primary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
    }

    // Image content thumbnail
    @ViewBuilder
    private var imagePreview: some View {
        if let nsImage = item.loadThumbnail() {
            ZStack {
                Color.black.opacity(colorScheme == .dark ? 0.30 : 0.06)
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 120)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(ModernTheme.controlBorder(for: colorScheme), lineWidth: 0.75)
            )
        } else {
            HStack(spacing: 6) {
                Image(systemName: "photo")
                Text("Image unavailable")
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(10)
        }
    }

    private var backgroundColor: Color {
        ModernTheme.cardFill(for: colorScheme, isSelected: isSelected, isHovered: isHovered)
    }

    private var borderColor: Color {
        ModernTheme.cardBorder(for: colorScheme, isSelected: isSelected, isHovered: isHovered)
    }
}
