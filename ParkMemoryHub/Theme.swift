import SwiftUI

struct Theme {
    // MARK: - Colors
    static let primaryColor = Color("PrimaryBlue")
    static let accentColor = Color("AccentPurple")
    static let secondaryColor = Color("SecondaryGreen")
    static let warningColor = Color("WarningOrange")
    static let errorColor = Color("ErrorRed")
    
    // MARK: - Background Colors
    static let backgroundPrimary = Color(.systemBackground)
    static let backgroundSecondary = Color(.secondarySystemBackground)
    static let backgroundTertiary = Color(.tertiarySystemBackground)
    
    // MARK: - Text Colors
    static let textPrimary = Color(.label)
    static let textSecondary = Color(.secondaryLabel)
    static let textTertiary = Color(.tertiaryLabel)
    
    // MARK: - Typography
    static let titleFont = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let headlineFont = Font.system(.headline, design: .rounded, weight: .semibold)
    static let bodyFont = Font.system(.body, design: .rounded)
    static let captionFont = Font.system(.caption, design: .rounded)
    
    // MARK: - Spacing
    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 16
    static let spacingL: CGFloat = 24
    static let spacingXL: CGFloat = 32
    
    // MARK: - Corner Radius
    static let cornerRadiusS: CGFloat = 8
    static let cornerRadiusM: CGFloat = 12
    static let cornerRadiusL: CGFloat = 16
    static let cornerRadiusXL: CGFloat = 24
    
    // MARK: - Shadows
    static let shadowSmall = Shadow(
        color: .black.opacity(0.1),
        radius: 4,
        offsetX: 0,
        offsetY: 2
    )
    
    static let shadowMedium = Shadow(
        color: .black.opacity(0.15),
        radius: 8,
        offsetX: 0,
        offsetY: 4
    )
    
    static let shadowLarge = Shadow(
        color: .black.opacity(0.2),
        radius: 16,
        offsetX: 0,
        offsetY: 8
    )
    
    // MARK: - Animations
    static let animationFast = Animation.easeInOut(duration: 0.2)
    static let animationMedium = Animation.easeInOut(duration: 0.3)
    static let animationSlow = Animation.easeInOut(duration: 0.5)
    static let springAnimation = Animation.spring(response: 0.3, dampingFraction: 0.6)
    
    // MARK: - iOS 18 Enhanced Animations
    @available(iOS 18.0, *)
    static let snappyAnimation = Animation.snappy(duration: 0.3)
    @available(iOS 18.0, *)
    static let smoothAnimation = Animation.smooth(duration: 0.4)
    
    // MARK: - Glassmorphism
    static let glassmorphism = Material.ultraThinMaterial
    static let glassmorphismThin = Material.thinMaterial
    static let glassmorphismThick = Material.thickMaterial
    
    // MARK: - iOS 18 Mesh Gradients
    @available(iOS 18.0, *)
    static let primaryMeshGradient = MeshGradient(
        width: 3,
        height: 3,
        points: [
            [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
            [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
            [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
        ],
        colors: [
            primaryColor, accentColor, secondaryColor,
            accentColor, primaryColor, accentColor,
            secondaryColor, accentColor, primaryColor
        ]
    )
    
    @available(iOS 18.0, *)
    static let accentMeshGradient = MeshGradient(
        width: 2,
        height: 2,
        points: [
            [0.0, 0.0], [1.0, 0.0],
            [0.0, 1.0], [1.0, 1.0]
        ],
        colors: [
            accentColor, primaryColor,
            primaryColor.opacity(0.8), accentColor.opacity(0.8)
        ]
    )
}

struct Shadow {
    let color: Color
    let radius: CGFloat
    let offsetX: CGFloat
    let offsetY: CGFloat
}

// MARK: - Color Extensions
// Theme colors are now defined in Assets.xcassets and accessed via Theme static properties

// MARK: - View Modifiers
struct GlassmorphismModifier: ViewModifier {
    let material: Material
    let cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .background(material, in: RoundedRectangle(cornerRadius: cornerRadius))
    }
}

struct ShadowModifier: ViewModifier {
    let shadow: Shadow
    
    func body(content: Content) -> some View {
        content
            .shadow(
                color: shadow.color,
                radius: shadow.radius,
                x: shadow.offsetX,
                y: shadow.offsetY
            )
    }
}

extension View {
    func glassmorphism(material: Material = Theme.glassmorphism, cornerRadius: CGFloat = Theme.cornerRadiusM) -> some View {
        modifier(GlassmorphismModifier(material: material, cornerRadius: cornerRadius))
    }
    
    func shadow(_ shadow: Shadow) -> some View {
        modifier(ShadowModifier(shadow: shadow))
    }
    
    func themeShadow(_ size: ShadowSize = .medium) -> some View {
        let shadow: Shadow
        switch size {
        case .small:
            shadow = Theme.shadowSmall
        case .medium:
            shadow = Theme.shadowMedium
        case .large:
            shadow = Theme.shadowLarge
        }
        return self.shadow(shadow)
    }
    
    // MARK: - iOS 18 Enhancements
    @available(iOS 18.0, *)
    func meshBackground() -> some View {
        self.background(Theme.primaryMeshGradient)
    }
    
    @available(iOS 18.0, *)
    func accentMeshBackground() -> some View {
        self.background(Theme.accentMeshGradient)
    }
    
    @available(iOS 18.0, *)
    func snappyAnimation() -> some View {
        self.animation(Theme.snappyAnimation, value: UUID())
    }
    
    func zoomTransition() -> some View {
        self.transition(.scale.combined(with: .opacity))
    }
}

enum ShadowSize {
    case small, medium, large
}
