import SwiftUI
import AppKit

public struct ClipboardItemRow: View {
    public let item: ClipboardItem
    public let index: Int?
    public let isSelected: Bool
    public let onSelect: () -> Void
    public let onTogglePin: () -> Void
    public let onDelete: () -> Void

    @State private var isHovered = false

    public var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                // Header line: type icon, time, pin/delete actions
                HStack(alignment: .center, spacing: 6) {
                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }

                    if item.type == .image {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(red: 0.4, green: 0.7, blue: 1.0))
                    }

                    Text(item.relativeTime)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.70))

                    Spacer()

                    // Info tag: chars or image dimensions
                    if item.type == .image {
                        if let w = item.imageWidth, let h = item.imageHeight {
                            Text("\(w)×\(h)")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.65))
                        } else {
                            Text("Image")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.65))
                        }
                    } else {
                        Text("\(item.characterCount)c")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.65))
                    }

                    // Action buttons (Pin & Delete)
                    HStack(spacing: 2) {
                        Button(action: onTogglePin) {
                            Image(systemName: item.isPinned ? "pin.slash" : "pin")
                                .font(.system(size: 11))
                                .foregroundColor(item.isPinned ? .orange : Color.white.opacity(0.75))
                                .frame(width: 20, height: 20)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(item.isPinned ? "Unpin item" : "Pin item to top")

                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundColor(Color.white.opacity(0.70))
                                .frame(width: 20, height: 20)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Delete from history")
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
            .padding(9)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    // Text content
    private var textPreview: some View {
        Text(item.previewText)
            .font(.system(size: 12, weight: .regular))
            .foregroundColor(.white)
            .lineLimit(3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
    }

    // Image content thumbnail
    @ViewBuilder
    private var imagePreview: some View {
        if let nsImage = item.loadThumbnail() {
            ZStack {
                Color.black.opacity(0.35)
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 120)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
        } else {
            HStack(spacing: 6) {
                Image(systemName: "photo")
                Text("Image unavailable")
            }
            .font(.system(size: 11))
            .foregroundColor(Color.white.opacity(0.60))
            .padding(10)
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color(red: 0.18, green: 0.42, blue: 0.78).opacity(0.48)
        } else if isHovered {
            return Color.white.opacity(0.12)
        } else {
            return Color.white.opacity(0.065)
        }
    }

    private var borderColor: Color {
        if isSelected {
            return Color(red: 0.40, green: 0.65, blue: 1.0, opacity: 0.85)
        } else if isHovered {
            return Color.white.opacity(0.18)
        } else {
            return Color.white.opacity(0.08)
        }
    }
}
