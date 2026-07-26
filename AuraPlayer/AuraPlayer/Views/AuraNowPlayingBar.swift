//
//  AuraNowPlayingBar.swift
//  AuraPlayer
//
//  Created by mobile on 6/7/26.
//
//  Mini "now playing" strip. Sits above the tab bar; tap to open the full player.
//

import SwiftUI

struct AuraNowPlayingBar: View {
    @EnvironmentObject var player: PlayerViewModel
    var onTap: () -> Void
    
    var body: some View {
        HStack(spacing: AuraSpacing.md) {
            artwork
            
            VStack(alignment: .leading, spacing: 2) {
                Text(player.currentTitle)
                    .font(.auraHeadline)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Text(player.currentArtist)
                    .font(.auraCaption)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer(minLength: AuraSpacing.sm)
            
            Button {
                player.togglePlayPause()
            } label: {
                AuraPlayPauseIcon(isPlaying: player.isPlaying, size: 17)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")

            Button {
                player.skipNext()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.auraHeadline)
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("Next track")
        }
        .padding(.horizontal, AuraSpacing.md)
        .padding(.vertical, AuraSpacing.sm)
        .background(.ultraThinMaterial)
        .background(Color.surface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.medium))
        .overlay(alignment: .bottom) { progressLine }
        .overlay(
            RoundedRectangle(cornerRadius: AuraRadius.medium)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.medium))
        // A light tap confirms the toggle without looking at the screen.
        .sensoryFeedback(.impact(weight: .light), trigger: player.isPlaying)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        // Keep the buttons individually reachable, but give the bar itself a
        // clear identity so VoiceOver users know what it is.
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Now playing: \(player.currentTitle), \(player.currentArtist)")
        .accessibilityHint("Opens the full player")
    }
    
    /// Hairline of elapsed progress along the bottom edge — glanceable
    /// without adding a control the thumb could hit by accident.
    private var progressLine: some View {
        GeometryReader { geo in
            Capsule()
                .fill(Color.accent)
                .frame(width: max(0, geo.size.width * player.progress), height: 2)
                .animation(.linear(duration: 0.25), value: player.progress)
        }
        .frame(height: 2)
        .allowsHitTesting(false)
    }

    @ViewBuilder private var artwork: some View {
        Group {
            if let art = player.currentArtwork {
                Image(uiImage: art)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: AuraRadius.small))
            } else {
                // No cover art: spin a record instead of showing a dead note.
                AuraVinylView(size: 44, isSpinning: player.isPlaying)
            }
        }
        .frame(width: 44, height: 44)
    }
}

#Preview {
    let vm = PlayerViewModel()
    vm.currentTitle = "Bohemian Rhapsody"
    vm.currentArtist = "Queen"
    return AuraNowPlayingBar(onTap: {})
        .environmentObject(vm)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.background)
        .preferredColorScheme(.dark)
}
