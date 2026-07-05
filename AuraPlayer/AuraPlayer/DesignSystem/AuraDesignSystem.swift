//
//  AuraDesignSystem.swift
//  AuraPlayer
//
//  Created by mobile on 4/7/26.
//
//  Live showcase of the full design system in one preview.
//  Not used at runtime - a visual reference / regression check for the tokens.

import SwiftUI

struct AuraDesignSystemShowcase: View {
    @State private var seek = 0.4
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AuraSpacing.xl) {
                Text("AuraPlayer Design System")
                    .font(.auraDisplay)
                    .foregroundStyle(Color.textPrimary)
                
                // Buttons
                VStack(spacing: AuraSpacing.md) {
                    AuraButton(
                        "Play All",
                        systemImage: "play.fill",
                        variant: .primary
                    ) { }
                    AuraButton(
                        "Shuffle",
                        systemImage: "shuffle",
                        variant: .secondary
                    ) { }
                    HStack(spacing: AuraSpacing.lg) {
                        AuraButton(
                            systemImage: "backward.fill",
                            variant: .icon) { }
                        AuraButton(
                            systemImage: "pause.fill",
                            variant: .icon) { }
                        AuraButton(
                            systemImage: "forward.fill",
                            variant: .icon) { }
                    }
                }
                
                // Card
                AuraCard {
                    HStack(spacing: AuraSpacing.md) {
                        RoundedRectangle(cornerRadius: AuraRadius.small)
                            .fill(Color.accent.opacity(0.25))
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: "music.note")
                                    .foregroundStyle(Color.accent)
                            )
                        VStack(
                            alignment: .leading,
                            spacing: AuraSpacing.xs) {
                                Text("Bohemian Rhapsody")
                                    .font(.auraHeadline)
                                    .foregroundStyle(Color.textPrimary)
                                Text("Queen")
                                    .font(.auraBody)
                                    .foregroundStyle(Color.textSecondary)
                            }
                        Spacer()
                        Text("5:54")
                            .font(.auraBody)
                            .foregroundStyle(Color.textTertiary)
                    }
                }
                
                // Slider + ring
                AuraSlider(value: $seek)
                HStack(spacing: AuraSpacing.xl) {
                    AuraProgressRing(progress: 0.66, size: 72)
                    Circle()
                        .fill(Color.accent)
                        .frame(width: 64, height: 64)
                        .overlay(
                            Image(systemName: "play.fill")
                                .foregroundStyle(Color.background)
                        )
                        .glowEffect()
                }
            }
            .padding(AuraSpacing.xl)
        }
        .background(Color.background)
        .preferredColorScheme(.dark)
    }
}

#Preview("Design System") {
    AuraDesignSystemShowcase()
}
