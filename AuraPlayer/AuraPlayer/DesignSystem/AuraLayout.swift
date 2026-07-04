//
//  AuraLayout.swift
//  AuraPlayer
//
//  Spacing, corner radius, and shadow/glow constants. Airy scale for a premium feel.
//

import SwiftUI

enum AuraSpacing {
    static let xs: CGFloat  = 4
    static let sm: CGFloat  = 8
    static let md: CGFloat  = 16
    static let lg: CGFloat  = 24
    static let xl: CGFloat  = 32
    static let xxl: CGFloat = 48
}

enum AuraRadius {
    static let small: CGFloat  = 8
    static let medium: CGFloat = 16
    static let large: CGFloat  = 24
    static let pill: CGFloat   = 999
}

// MARK: - Shadow & glow

extension View {
    /// Subtle drop shadow for cards on dark surfaces.
    func cardShadow() -> some View {
        shadow(color: .black.opacity(0.45), radius: 12, x: 0, y: 6)
    }

    /// Signature cyan glow. Layered shadows create a soft bloom around active elements.
    func glowEffect(color: Color = .accentGlow, radius: CGFloat = 16) -> some View {
        self
            .shadow(color: color.opacity(0.55), radius: radius * 0.5)
            .shadow(color: color.opacity(0.35), radius: radius)
    }
}

// MARK: - Preview

#Preview("Layout & Glow") {
    VStack(spacing: AuraSpacing.xl) {

        // Spacing scale
        VStack(alignment: .leading, spacing: AuraSpacing.sm) {
            Text("Spacing").font(.auraCaption).foregroundStyle(Color.textTertiary)
            ForEach([("xs", AuraSpacing.xs), ("sm", AuraSpacing.sm), ("md", AuraSpacing.md),
                     ("lg", AuraSpacing.lg), ("xl", AuraSpacing.xl), ("xxl", AuraSpacing.xxl)], id: \.0) { name, value in
                HStack(spacing: AuraSpacing.md) {
                    Text(name).font(.auraCaption).foregroundStyle(Color.textSecondary).frame(width: 32, alignment: .leading)
                    RoundedRectangle(cornerRadius: 2).fill(Color.accent).frame(width: value, height: 12)
                    Text("\(Int(value))").font(.auraCaption).foregroundStyle(Color.textTertiary)
                }
            }
        }

        // Corner radii
        HStack(spacing: AuraSpacing.md) {
            ForEach([("sm", AuraRadius.small), ("md", AuraRadius.medium), ("lg", AuraRadius.large)], id: \.0) { name, r in
                VStack(spacing: AuraSpacing.xs) {
                    RoundedRectangle(cornerRadius: r).fill(Color.surfaceElevated).frame(width: 56, height: 56)
                    Text(name).font(.auraCaption).foregroundStyle(Color.textTertiary)
                }
            }
        }

        // Card shadow vs glow
        HStack(spacing: AuraSpacing.xl) {
            RoundedRectangle(cornerRadius: AuraRadius.medium)
                .fill(Color.surface)
                .frame(width: 80, height: 80)
                .cardShadow()
                .overlay(Text("card").font(.auraCaption).foregroundStyle(Color.textSecondary))

            Circle()
                .fill(Color.accent)
                .frame(width: 64, height: 64)
                .overlay(Image(systemName: "play.fill").foregroundStyle(Color.background))
                .glowEffect()
        }
    }
    .padding(AuraSpacing.xl)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.background)
    .preferredColorScheme(.dark)
}
