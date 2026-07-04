//
//  AuraCard.swift
//  AuraPlayer
//
//  Dark frosted-glass container. Wraps any content in a themed surface.
//

import SwiftUI

struct AuraCard<Content: View>: View {
    var padding: CGFloat = AuraSpacing.lg
    var cornerRadius: CGFloat = AuraRadius.large
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(.ultraThinMaterial)
            .background(Color.surface.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .cardShadow()
    }
}

#Preview("AuraCard") {
    VStack(spacing: AuraSpacing.lg) {
        AuraCard {
            HStack(spacing: AuraSpacing.md) {
                RoundedRectangle(cornerRadius: AuraRadius.small)
                    .fill(Color.accent.opacity(0.25))
                    .frame(width: 56, height: 56)
                    .overlay(Image(systemName: "music.note").foregroundStyle(Color.accent))
                VStack(alignment: .leading, spacing: AuraSpacing.xs) {
                    Text("Bohemian Rhapsody").font(.auraHeadline).foregroundStyle(Color.textPrimary)
                    Text("Queen").font(.auraBody).foregroundStyle(Color.textSecondary)
                }
                Spacer()
                Text("5:54").font(.auraTimestamp).foregroundStyle(Color.textTertiary)
            }
        }
    }
    .padding(AuraSpacing.xl)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.background)
    .preferredColorScheme(.dark)
}
