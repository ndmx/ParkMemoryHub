import SwiftUI

enum AppBackgroundStyle {
    case chrome
    case steel
    case marble
    case pearl
    case chromePearl

    var assetName: String {
        switch self {
        case .chrome:
            return "AppBackgroundChrome"
        case .steel:
            return "AppBackgroundSteel"
        case .marble:
            return "AppBackgroundMarble"
        case .pearl:
            return "AppBackgroundPearl"
        case .chromePearl:
            return "AppBackgroundChromePearl"
        }
    }
}

/// The app backdrop: a textured image, calmed by a Lumina scheme wash and lit
/// with a soft accent "glow-top" so every screen sits in the brand's atmosphere
/// (mirrors the era `glow` + scheme `background` tokens).
struct AppVisualBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    let style: AppBackgroundStyle

    var body: some View {
        Lumina.Color.background
            .overlay {
                Image(style.assetName)
                    .resizable()
                    .scaledToFill()
                    .opacity(colorScheme == .dark ? 0.32 : 0.5)
            }
            .overlay(readabilityWash)
            .overlay(glowTop)
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }

    /// Keeps content legible over the texture without flattening it.
    private var readabilityWash: some View {
        Lumina.Color.background
            .opacity(colorScheme == .dark ? 0.55 : 0.4)
    }

    /// Era glow: a luminous accent fog at the top fading into the canvas.
    private var glowTop: some View {
        LinearGradient(
            colors: [
                Lumina.Color.accent.opacity(colorScheme == .dark ? 0.14 : 0.10),
                Lumina.Color.background.opacity(0),
                Lumina.Color.shadow.opacity(colorScheme == .dark ? 0.5 : 0.22)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Surfaces

/// A Lumina card surface: token fill + scheme border + atmospheric shadow, with
/// optional seeded variation (radius breathes, accent glow) so sibling cards feel
/// alive but never drift off-brand. See `Lumina.variation(_:)`.
struct LuminaCardModifier: ViewModifier {
    var seed: String?
    var baseRadius: CGFloat
    var glow: Bool

    private var variation: LuminaVariation {
        seed.map(Lumina.variation) ?? .neutral
    }

    private var radius: CGFloat {
        let scaled = baseRadius * CGFloat(variation.radiusScale)
        return min(Lumina.Radius.xl2, max(Lumina.Radius.sm, scaled))
    }

    private var accent: Color {
        Lumina.accent(hueShiftedBy: variation.accentHueShift)
    }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return content
            .background(Lumina.Color.surfaceRaised, in: shape)
            .background(.ultraThinMaterial, in: shape)
            .overlay {
                shape.strokeBorder(borderStyle, lineWidth: 1)
            }
            .shadow(color: Lumina.Color.shadow, radius: 16 * CGFloat(variation.glow), x: 0, y: 10)
            .shadow(
                color: glow ? accent.opacity(0.20 * variation.glow) : .clear,
                radius: glow ? 22 : 0,
                x: 0,
                y: 0
            )
    }

    private var borderStyle: LinearGradient {
        LinearGradient(
            colors: glow
                ? [accent.opacity(0.45), Lumina.Color.border]
                : [Lumina.Color.borderVisible, Lumina.Color.border],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension View {
    func appScreenBackground(_ style: AppBackgroundStyle) -> some View {
        background {
            AppVisualBackground(style: style)
        }
    }

    /// Primary Lumina card. `seed` (e.g. a model id) gives the card its own stable
    /// flavor; `glow` adds the accent halo for hero/interactive cards.
    func luminaCard(seed: String? = nil, radius: CGFloat = Lumina.Radius.lg, glow: Bool = false) -> some View {
        modifier(LuminaCardModifier(seed: seed, baseRadius: radius, glow: glow))
    }

    // Backwards-compatible aliases — existing call sites now render as Lumina cards.
    func appReadableSurface(cornerRadius: CGFloat = Lumina.Radius.lg) -> some View {
        luminaCard(radius: cornerRadius, glow: true)
    }

    func appOutlinedSurface(cornerRadius: CGFloat = Lumina.Radius.lg) -> some View {
        appGlassBlock(cornerRadius: cornerRadius)
    }

    func appGlassBlock(cornerRadius: CGFloat = Lumina.Radius.lg) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return background(Lumina.Color.overlay, in: shape)
            .overlay {
                shape.strokeBorder(Lumina.Color.borderVisible, lineWidth: 1)
            }
    }

    /// A small token chip (pill) in the given tint — used for badges and tags.
    func luminaChip(_ tint: Color = Lumina.Color.accent) -> some View {
        font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, Lumina.Space.sm)
            .padding(.vertical, Lumina.Space.xs2 + 1)
            .background(tint.opacity(0.14), in: Capsule())
    }
}
