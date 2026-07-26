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

    // Built on text styles rather than fixed point sizes, so every label
    // scales with the reader's Dynamic Type setting.

    /// Large now-playing track title / hero text. (~34pt at default size)
    static let auraDisplay  = Font.system(.largeTitle, design: Aura.fontDesign).weight(.bold)
    /// Screen titles, section headers. (~22pt)
    static let auraTitle    = Font.system(.title2, design: Aura.fontDesign).weight(.semibold)
    /// Track titles in lists, prominent labels. (~17pt)
    static let auraHeadline = Font.system(.headline, design: Aura.fontDesign)
    /// Default body text, artist names. (~16pt)
    static let auraBody     = Font.system(.callout, design: Aura.fontDesign)
    /// Metadata, secondary labels. (~13pt)
    static let auraCaption  = Font.system(.footnote, design: Aura.fontDesign)
    /// Time display (00:00). Monospaced digits so width never shifts.
    static let auraTimestamp = Font.system(.footnote, design: .monospaced).weight(.medium)
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
