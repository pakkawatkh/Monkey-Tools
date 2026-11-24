import SwiftUI

public struct EmojiPickerView: View {
    @ObservedObject var emojiManager = EmojiManager.shared
    @Environment(\.colorScheme) private var colorScheme
    public var onSelectEmoji: (String) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 36, maximum: 44), spacing: 6)
    ]

    public init(onSelectEmoji: @escaping (String) -> Void) {
        self.onSelectEmoji = onSelectEmoji
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Category selector bar
            if emojiManager.searchQuery.isEmpty {
                categoryBar
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                Rectangle()
                    .fill(ModernTheme.divider(for: colorScheme))
                    .frame(height: 1)
            }

            // Emojis Grid
            let list = emojiManager.filteredEmojis
            if list.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Text("🔍")
                        .font(.system(size: 28))
                    Text("No emojis found")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(list, id: \.self) { emoji in
                            EmojiButton(emoji: emoji) {
                                emojiManager.useEmoji(emoji)
                                onSelectEmoji(emoji)
                            }
                        }
                    }
                    .padding(10)
                }
            }
        }
    }

    private var categoryBar: some View {
        HStack(spacing: 4) {
            ForEach(EmojiCategory.allCases) { cat in
                Button(action: {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.78)) {
                        emojiManager.selectedCategory = cat
                    }
                }) {
                    Text(cat.rawValue)
                        .font(.system(size: 15))
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(
                            Capsule()
                                .fill(emojiManager.selectedCategory == cat ? Color.accentColor.opacity(0.22) : ModernTheme.controlFill(for: colorScheme))
                        )
                        .overlay(
                            Capsule()
                                .stroke(emojiManager.selectedCategory == cat ? Color.accentColor.opacity(0.45) : Color.clear, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help(cat.title)
            }
        }
    }
}

private struct EmojiButton: View {
    let emoji: String
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                isPressed = false
            }
            action()
        }) {
            Text(emoji)
                .font(.system(size: 22))
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(isPressed ? Color.accentColor.opacity(0.28) : (isHovered ? ModernTheme.controlFill(for: colorScheme) : Color.clear))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(isPressed ? Color.accentColor.opacity(0.75) : (isHovered ? ModernTheme.controlBorder(for: colorScheme) : Color.clear), lineWidth: 1)
                )
                .scaleEffect(isPressed ? 0.90 : (isHovered ? 1.10 : 1.0))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}
