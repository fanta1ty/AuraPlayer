//
//  AuraColors.swift
//  AuraPlayer
//
//  Design tokens — Dark audiophile palette (see DESIGN_NOTES.md).
//  Accent: electric teal-cyan (#1CE3CE). Dark mode only for v1.
//

import SwiftUI

extension Color {

    // MARK: - Backgrounds
    /// App background — near-black, cool-tinted.
    static let background       = Color(hex: 0x0A0C10)
    /// Cards and panels.
    static let surface          = Color(hex: 0x12151B)
    /// Raised surfaces, sheets, popovers.
    static let surfaceElevated  = Color(hex: 0x1A1E26)
    /// Translucent overlay for scrims and hover states.
    static let surfaceOverlay   = Color(hex: 0xFFFFFF).opacity(0.06)

    // MARK: - Text
    /// Titles and primary content.
    static let textPrimary      = Color(hex: 0xF2F5F7)
    /// Artist names, secondary content.
    static let textSecondary    = Color(hex: 0x9AA3AD)
    /// Timestamps, metadata, tertiary content. Meets WCAG AA (4.5:1) for small text on all surfaces.
    static let textTertiary     = Color(hex: 0x848C96)
    /// Disabled text.
    static let textDisabled     = Color(hex: 0x3A424C)

    // MARK: - Accent
    /// Hero accent — electric teal-cyan.
    static let accent           = Color(hex: 0x1CE3CE)
    /// Muted accent for pressed/inactive states.
    static let accentDim        = Color(hex: 0x12A596)
    /// Brighter accent used behind glow effects.
    static let accentGlow       = Color(hex: 0x3DF0DD)

    // MARK: - Semantic
    static let success          = Color(hex: 0x34D399)
    static let warning          = Color(hex: 0xFBBF24)
    static let error            = Color(hex: 0xF87171)
}

// MARK: - Hex initializer

extension Color {
    /// Create a color from a 0xRRGGBB hex literal.
    init(hex: UInt, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

// MARK: - Preview

#Preview("Color Swatches") {
    struct Swatch: Identifiable {
        let id = UUID()
        let name: String
        let color: Color
    }

    let groups: [(String, [Swatch])] = [
        ("Backgrounds", [
            Swatch(name: "background", color: .background),
            Swatch(name: "surface", color: .surface),
            Swatch(name: "surfaceElevated", color: .surfaceElevated),
            Swatch(name: "surfaceOverlay", color: .surfaceOverlay),
        ]),
        ("Text", [
            Swatch(name: "textPrimary", color: .textPrimary),
            Swatch(name: "textSecondary", color: .textSecondary),
            Swatch(name: "textTertiary", color: .textTertiary),
            Swatch(name: "textDisabled", color: .textDisabled),
        ]),
        ("Accent", [
            Swatch(name: "accent", color: .accent),
            Swatch(name: "accentDim", color: .accentDim),
            Swatch(name: "accentGlow", color: .accentGlow),
        ]),
        ("Semantic", [
            Swatch(name: "success", color: .success),
            Swatch(name: "warning", color: .warning),
            Swatch(name: "error", color: .error),
        ]),
    ]

    return ScrollView {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(groups, id: \.0) { title, swatches in
                VStack(alignment: .leading, spacing: 10) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Color.textPrimary)
                    ForEach(swatches) { swatch in
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(swatch.color)
                                .frame(width: 56, height: 40)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                            Text(swatch.name)
                                .font(.body)
                                .foregroundStyle(Color.textSecondary)
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(24)
    }
    .background(Color.background)
    .preferredColorScheme(.dark)
}
