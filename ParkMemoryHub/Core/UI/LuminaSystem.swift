//
//  LuminaSystem.swift
//  ParkMemoryHub
//
//  Native Swift port of the @xlumina/system design-system brain
//  (https://github.com/ndmx/lumina-codex — packages/lumina-system).
//
//  The TypeScript package is the canonical source for these values; this file
//  mirrors them for SwiftUI. Mapping:
//      tokens.ts      → Lumina.Color primitives, Lumina.Space, Lumina.Radius, Lumina.Typo
//      scheme.ts      → dynamic light/dark Colors (resolved per trait collection)
//      eras.ts        → the "atelier" accent (aura teal + spark coral)
//      variation.ts   → Lumina.variation(seed:) — deterministic, bounded per-instance flavor
//
//  Components read these tokens instead of hardcoding colors/radii, so the whole
//  app shifts together and stays on-brand in both schemes.
//

import SwiftUI
import UIKit

// MARK: - Hex + dynamic color helpers

extension UIColor {
    /// Build a UIColor from a 0xRRGGBB literal (mirrors the package hex primitives).
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >> 8) & 0xFF) / 255
        let b = CGFloat(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}

extension Color {
    /// A scheme-aware color — the SwiftUI analog of `resolveSchemeVars(scheme, era)`.
    init(light: UIColor, dark: UIColor) {
        self.init(UIColor { trait in
            trait.userInterfaceStyle == .dark ? dark : light
        })
    }
}

// MARK: - Lumina

/// The portable Lumina design-system, expressed for SwiftUI.
enum Lumina {

    // MARK: Color primitives (tokens.ts → colorPrimitives)

    enum Primitive {
        static let void = UIColor(hex: 0x06070A)
        static let ink = UIColor(hex: 0x101217)
        static let ivory = UIColor(hex: 0xF5EEE5)
        static let aura = UIColor(hex: 0x3C9B91)   // brand accent — softened teal
        static let spark = UIColor(hex: 0xFF7D60)  // brand accent — warm coral
        static let cyan = UIColor(hex: 0x8DE8FF)
        static let sand = UIColor(hex: 0xF2D8B4)
        static let danger = UIColor(hex: 0xFF6B6B)
    }

    // MARK: Scheme foundation (scheme.ts → schemes.light / schemes.dark)
    //
    // Resolved dynamically so a single Color adapts to light/dark automatically.

    enum Color {
        // Canvas
        static let background = SwiftUI.Color(
            light: UIColor(hex: 0xF3ECE1),
            dark: Primitive.void
        )
        static let surface = SwiftUI.Color(
            light: UIColor(hex: 0xFFFCF7, alpha: 0.92),
            dark: UIColor(hex: 0x101217, alpha: 0.92)
        )
        static let surfaceRaised = SwiftUI.Color(
            light: UIColor.white.withAlphaComponent(0.74),
            dark: UIColor.white.withAlphaComponent(0.05)
        )

        // Text tiers
        static let textPrimary = SwiftUI.Color(
            light: UIColor(hex: 0x15140F),
            dark: Primitive.ivory
        )
        static let textMuted = SwiftUI.Color(
            light: UIColor(hex: 0x15140F, alpha: 0.74),
            dark: UIColor(hex: 0xF5EEE5, alpha: 0.72)
        )
        static let textSubtle = SwiftUI.Color(
            light: UIColor(hex: 0x15140F, alpha: 0.56),
            dark: UIColor(hex: 0xF5EEE5, alpha: 0.55)
        )
        static let textFaint = SwiftUI.Color(
            light: UIColor(hex: 0x15140F, alpha: 0.36),
            dark: UIColor(hex: 0xF5EEE5, alpha: 0.34)
        )

        // Borders
        static let border = SwiftUI.Color(
            light: UIColor(hex: 0x15140F, alpha: 0.10),
            dark: UIColor.white.withAlphaComponent(0.08)
        )
        static let borderVisible = SwiftUI.Color(
            light: UIColor(hex: 0x15140F, alpha: 0.16),
            dark: UIColor.white.withAlphaComponent(0.14)
        )
        static let borderStrong = SwiftUI.Color(
            light: UIColor(hex: 0x15140F, alpha: 0.32),
            dark: UIColor.white.withAlphaComponent(0.28)
        )

        // Translucent overlays
        static let overlay = SwiftUI.Color(
            light: UIColor(hex: 0x15140F, alpha: 0.03),
            dark: UIColor.white.withAlphaComponent(0.04)
        )
        static let overlayMedium = SwiftUI.Color(
            light: UIColor(hex: 0x15140F, alpha: 0.06),
            dark: UIColor.white.withAlphaComponent(0.08)
        )
        static let overlayHeavy = SwiftUI.Color(
            light: UIColor(hex: 0x15140F, alpha: 0.12),
            dark: UIColor.white.withAlphaComponent(0.16)
        )

        // Atmospheric shadow tuned per scheme
        static let shadow = SwiftUI.Color(
            light: UIColor(hex: 0x3A2C18, alpha: 0.18),
            dark: UIColor.black.withAlphaComponent(0.42)
        )

        // Era accent (eras.ts → atelier). Accent is brand-level, identical in both schemes.
        static let accent = SwiftUI.Color(Primitive.aura)
        static let accentSecondary = SwiftUI.Color(Primitive.spark)
        /// Foreground to place *on top of* the accent fill.
        static let onAccent = SwiftUI.Color(Primitive.ivory)
        static let glow = accent
    }

    // MARK: Semantic status palette (derived from primitives, on-brand)

    enum Status {
        static let info = Color.accent              // teal
        static let highlight = Color.accentSecondary // coral
        static let success = SwiftUI.Color(Primitive.aura)
        static let pending = SwiftUI.Color(Primitive.spark)
        static let neutral = SwiftUI.Color(Primitive.cyan)
        static let warning = SwiftUI.Color(UIColor(hex: 0xE0A24A)) // readable amber (sand's legible sibling)
        static let danger = SwiftUI.Color(Primitive.danger)
    }

    // MARK: Spacing scale (tokens.ts → spacing, 4px base)

    enum Space {
        static let xs2: CGFloat = 4    // 1
        static let xs: CGFloat = 8     // 2
        static let sm: CGFloat = 12    // 3
        static let md: CGFloat = 16    // 4
        static let lg: CGFloat = 20    // 5
        static let xl: CGFloat = 24    // 6
        static let xl2: CGFloat = 32   // 8
        static let xl3: CGFloat = 48   // 12
    }

    // MARK: Radii (tokens.ts → radii)

    enum Radius {
        static let sm: CGFloat = 6
        static let base: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 22
        static let xl2: CGFloat = 36
        static let pill: CGFloat = 999
    }

    // MARK: Touch target (grid.ts → grids.mobile.minTarget — Apple HIG minimum)

    enum Layout {
        static let minTarget: CGFloat = 44
    }

    // MARK: Typography (tokens.ts → typography)
    //
    // Cormorant/Manrope aren't bundled, so we evoke them with system faces:
    // a serif display for headline moments, the app's rounded body elsewhere.

    enum Typo {
        static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
            .system(size: size, weight: weight, design: .serif)
        }
    }
}

// MARK: - Variation (variation.ts) — deterministic, bounded per-instance flavor

struct LuminaVariation {
    let accentHueShift: Double  // [-12, 12] degrees
    let radiusScale: Double     // [0.85, 1.15]
    let density: Double         // [0.92, 1.08]
    let glow: Double            // [0.7, 1.25]
    let tilt: Double            // [-6, 6] degrees

    static let neutral = LuminaVariation(
        accentHueShift: 0, radiusScale: 1, density: 1, glow: 1, tilt: 0
    )
}

extension Lumina {
    /// FNV-1a hash of a string seed → 32-bit unsigned (variation.ts → hashSeed).
    private static func hashSeed(_ seed: String) -> UInt32 {
        var h: UInt32 = 0x811C9DC5
        for byte in seed.utf8 {
            h ^= UInt32(byte)
            h = h &* 0x0100_0193
        }
        return h
    }

    /// mulberry32 PRNG (variation.ts → mulberry32). Returns a closure yielding [0, 1).
    private static func mulberry32(_ seed: UInt32) -> () -> Double {
        var a = seed
        return {
            a = a &+ 0x6D2B_79F5
            var t = a
            t = (t ^ (t >> 15)) &* (t | 1)
            t ^= t &+ ((t ^ (t >> 7)) &* (t | 61))
            return Double((t ^ (t >> 14))) / 4_294_967_296
        }
    }

    private static func lerp(_ min: Double, _ max: Double, _ t: Double) -> Double {
        min + (max - min) * t
    }

    /// Build a stable variation profile from a seed (variation.ts → createVariation).
    /// Same seed → identical profile, every render.
    static func variation(_ seed: String) -> LuminaVariation {
        let rand = mulberry32(hashSeed(seed))
        return LuminaVariation(
            accentHueShift: lerp(-12, 12, rand()),
            radiusScale: lerp(0.85, 1.15, rand()),
            density: lerp(0.92, 1.08, rand()),
            glow: lerp(0.7, 1.25, rand()),
            tilt: lerp(-6, 6, rand())
        )
    }

    /// Rotate the brand accent's hue by `degrees`, preserving saturation/brightness
    /// (variation.ts → shiftHue). Keeps a card in the accent family while feeling unique.
    static func accent(hueShiftedBy degrees: Double) -> SwiftUI.Color {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard Primitive.aura.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else {
            return Lumina.Color.accent
        }
        let shifted = (h + CGFloat(degrees) / 360).truncatingRemainder(dividingBy: 1)
        let hue = shifted < 0 ? shifted + 1 : shifted
        return SwiftUI.Color(UIColor(hue: hue, saturation: s, brightness: b, alpha: a))
    }
}
