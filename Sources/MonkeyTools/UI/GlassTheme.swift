import AppKit
import SwiftUI

/// Modern macOS adaptive vibrancy background (follows system Light/Dark appearance).
public struct AdaptiveVisualEffectView: NSViewRepresentable {
    public var material: NSVisualEffectView.Material
    public var blendingMode: NSVisualEffectView.BlendingMode
    public var cornerRadius: CGFloat

    public init(
        material: NSVisualEffectView.Material = .popover,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        cornerRadius: CGFloat = 18
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.cornerRadius = cornerRadius
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = blendingMode
        view.state = .active
        view.material = material
        view.wantsLayer = true
        if cornerRadius > 0 {
            view.layer?.cornerRadius = cornerRadius
            view.layer?.masksToBounds = true
        }
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

/// Backward-compatible alias for VisualEffectBackground using modern adaptive glass.
public struct VisualEffectBackground: NSViewRepresentable {
    public var cornerRadius: CGFloat

    public init(cornerRadius: CGFloat = 18) {
        self.cornerRadius = cornerRadius
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .popover
        view.wantsLayer = true
        view.layer?.cornerRadius = cornerRadius
        view.layer?.masksToBounds = true
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// Adaptive design tokens for modern macOS (Sequoia / Liquid Glass style) supporting Light & Dark Mode.
public enum ModernTheme {
    public static func panelTint(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(nsColor: .windowBackgroundColor).opacity(0.42)
            : Color.white.opacity(0.45)
    }

    public static func glassRimGradient(for scheme: ColorScheme) -> LinearGradient {
        if scheme == .dark {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.28),
                    Color.white.opacity(0.10),
                    Color.white.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.85),
                    Color.black.opacity(0.08),
                    Color.black.opacity(0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    public static func divider(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
    }

    public static func controlFill(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.09) : Color.black.opacity(0.055)
    }

    public static func controlBorder(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.09)
    }

    public static func cardFill(for scheme: ColorScheme, isSelected: Bool, isHovered: Bool) -> Color {
        if isSelected {
            return Color.accentColor.opacity(scheme == .dark ? 0.30 : 0.16)
        } else if isHovered {
            return scheme == .dark ? Color.white.opacity(0.11) : Color.black.opacity(0.06)
        } else {
            return scheme == .dark ? Color.white.opacity(0.055) : Color.white.opacity(0.55)
        }
    }

    public static func cardBorder(for scheme: ColorScheme, isSelected: Bool, isHovered: Bool) -> Color {
        if isSelected {
            return Color.accentColor.opacity(scheme == .dark ? 0.78 : 0.65)
        } else if isHovered {
            return scheme == .dark ? Color.white.opacity(0.20) : Color.black.opacity(0.12)
        } else {
            return scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.07)
        }
    }

    public static func subtleCardFill(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.65)
    }
}
