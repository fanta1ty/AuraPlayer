//
//  AuraFonts.swift
//  AuraPlayer
//
//  Created by Thinh Nguyen on 4/7/26.
//
//  Typography system — SF Pro (system), premium audiophile feel.
//  Swap `Aura.fontDesign` to .rounded to warm up the entire app in one edit.
//

import SwiftUI

enum Aura {
    /// Global font design. Change to `.rounded` to restyle all text app-wide.
    static let fontDesign: Font.Design = .default
}

extension Font {

    /// Large now-playing track title / hero text.
    static let auraDisplay  = Font.system(size: 34, weight: .bold,     design: Aura.fontDesign)
    /// Screen titles, section headers.
    static let auraTitle    = Font.system(size: 24, weight: .semibold, design: Aura.fontDesign)
    /// Track titles in lists, prominent labels.
    static let auraHeadline = Font.system(size: 18, weight: .semibold, design: Aura.fontDesign)
    /// Default body text, artist names.
    static let auraBody     = Font.system(size: 16, weight: .regular,  design: Aura.fontDesign)
    /// Metadata, secondary labels.
    static let auraCaption  = Font.system(size: 13, weight: .regular,  design: Aura.fontDesign)
    /// Time display (00:00). Monospaced digits so width never shifts.
    static let auraTimestamp = Font.system(size: 13, weight: .medium, design: .monospaced)
}

// MARK: - Preview

#Preview("Typography") {
    ScrollView {
        VStack(alignment: .leading, spacing: 24) {

            // Real now-playing style block
            VStack(alignment: .leading, spacing: 6) {
                Text("Now Playing")
                    .font(.auraCaption)
                    .foregroundStyle(Color.textTertiary)
                Text("Bohemian Rhapsody")
                    .font(.auraDisplay)
                    .foregroundStyle(Color.textPrimary)
                Text("Queen")
                    .font(.auraBody)
                    .foregroundStyle(Color.textSecondary)
            }

            Divider().overlay(Color.textDisabled)

            // Scrubber-style timestamps
            HStack {
                Text("2:41")
                    .font(.auraTimestamp)
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                Text("5:54")
                    .font(.auraTimestamp)
                    .foregroundStyle(Color.textSecondary)
            }

            Divider().overlay(Color.textDisabled)

            // Scale reference
            VStack(alignment: .leading, spacing: 14) {
                sample("auraDisplay", .auraDisplay)
                sample("auraTitle", .auraTitle)
                sample("auraHeadline", .auraHeadline)
                sample("auraBody", .auraBody)
                sample("auraCaption", .auraCaption)
                HStack(spacing: 8) {
                    Text("auraTimestamp").font(.auraCaption).foregroundStyle(Color.textTertiary)
                    Text("00:00").font(.auraTimestamp).foregroundStyle(Color.textPrimary)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .background(Color.background)
    .preferredColorScheme(.dark)
}

@ViewBuilder
private func sample(_ name: String, _ font: Font) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 12) {
        Text(name)
            .font(.auraCaption)
            .foregroundStyle(Color.textTertiary)
            .frame(width: 110, alignment: .leading)
        Text("The quick brown fox")
            .font(font)
            .foregroundStyle(Color.textPrimary)
    }
}
