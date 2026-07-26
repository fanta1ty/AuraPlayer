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
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.auraHeadline)
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
            
            Button {
                player.skipNext()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.auraHeadline)
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("Next track")
        }
        .padding(.horizontal, AuraSpacing.md)
        .padding(.vertical, AuraSpacing.sm)
        .background(.ultraThinMaterial)
        .background(Color.surface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: AuraRadius.medium)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        // Keep the buttons individually reachable, but give the bar itself a
        // clear identity so VoiceOver users know what it is.
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Now playing: \(player.currentTitle), \(player.currentArtist)")
        .accessibilityHint("Opens the full player")
    }
    
    @ViewBuilder private var artwork: some View {
        Group {
            if let art = player.currentArtwork {
                Image(uiImage: art)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.surfaceElevated
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundStyle(Color.accent)
                    )
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.small))
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
