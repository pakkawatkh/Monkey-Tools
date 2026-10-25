import SwiftUI

public struct EmojiPickerView: View {
    @ObservedObject var emojiManager = EmojiManager.shared
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
                    .fill(Color.white.opacity(0.10))
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
                        .foregroundColor(Color.white.opacity(0.75))
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
                    withAnimation(.easeInOut(duration: 0.15)) {
                        emojiManager.selectedCategory = cat
                    }
                }) {
                    Text(cat.rawValue)
                        .font(.system(size: 15))
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(emojiManager.selectedCategory == cat ? Color.white.opacity(0.20) : Color.white.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(emojiManager.selectedCategory == cat ? Color.white.opacity(0.25) : Color.white.opacity(0.06), lineWidth: 1)
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
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isPressed ? Color(red: 0.25, green: 0.5, blue: 0.9).opacity(0.35) : (isHovered ? Color.white.opacity(0.12) : Color.white.opacity(0.03)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(isPressed ? Color(red: 0.35, green: 0.65, blue: 1.0) : (isHovered ? Color.white.opacity(0.22) : Color.white.opacity(0.05)), lineWidth: 1)
                )
                .scaleEffect(isPressed ? 0.90 : (isHovered ? 1.08 : 1.0))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
