//
//  NowPlayingView.swift
//  AuraPlayer
//
//  Created by mobile on 6/7/26.
//
//  Full-screen now-playing: blurred art background, centered artwork that
//  scales on play/pause, seek bar, and the full control row.
//

import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject var player: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            background
            
            VStack(spacing: AuraSpacing.lg) {
                dismissHandle
                Spacer(minLength: 0)
                artwork
                Spacer(minLength: 0)
                trackInfo
                seekBar
                controls
            }
            .padding(.horizontal, AuraSpacing.xl)
            .padding(.top, AuraSpacing.md)
            .padding(.bottom, AuraSpacing.xxl)
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Background (full-bleed blurred art)
    
    @ViewBuilder private var background: some View {
        GeometryReader { geo in
            Group {
                if let art = player.currentArtwork {
                    Image(uiImage: art)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .blur(radius: 60)
                        .overlay(Color.background.opacity(0.5))
                        .overlay(.ultraThinMaterial)
                } else {
                    LinearGradient(
                        colors: [Color.surfaceElevated, Color.background],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Dismiss handle
    
    private var dismissHandle: some View {
        Capsule()
            .fill(Color.textTertiary)
            .frame(width: 40, height: 5)
            .contentShape(Rectangle())
            .onTapGesture {
                dismiss()
            }
    }
    
    // MARK: - Artwork (scales on play/pause)
    
    private var artwork: some View {
        Group {
            if let art = player.currentArtwork {
                Image(uiImage: art)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.surfaceElevated
                    .overlay(
                        Image(systemName: "music.note").font(.system(size: 64))
                            .foregroundStyle(Color.accent)
                    )
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 300, maxHeight: 300)
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.large))
        .cardShadow()
        .glowEffect(color: .accentGlow, radius: player.isPlaying ? 24 : 0)
        .scaleEffect(player.isPlaying ? 1.0 : 0.85)
        .animation(.spring(duration: 0.4), value: player.isPlaying)
    }
    
    // MARK: - Track info
    
    private var trackInfo: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.xs) {
            Text(player.currentTitle)
                .font(.auraTitle)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
            Text(player.currentArtist)
                .font(.auraHeadline)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Seek bar
    
    private var seekBar: some View {
        VStack(spacing: AuraSpacing.sm) {
            AuraSlider(
                value: Binding(
                    get: { player.progress },
                    set: { player.seek(toProgress: $0) })
            )
            HStack {
                Text(Self.time(player.currentTime))
                Spacer()
                Text(Self.time(player.duration))
            }
            .font(.auraTimestamp)
            .foregroundStyle(Color.textSecondary)
        }
    }
    
    // MARK: - Controls
    
    private var controls: some View {
        HStack {
            Image(systemName: "shuffle")
                .foregroundStyle(player.isShuffled ? Color.accent : Color.textSecondary)
                .onTapGesture { player.toggleShuffle() }
            
            Spacer()
            
            Image(systemName: "backward.fill")
                .foregroundStyle(Color.textPrimary)
                .onTapGesture { player.skipPrevious() }
            
            Spacer()
            
            // Large play/pause (glowing accent)
            Circle()
                .fill(Color.accent)
                .frame(width: 72, height: 72)
                .overlay(
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.background)
                )
                .glowEffect()
                .onTapGesture { player.togglePlayPause() }
            
            Spacer()
            
            Image(systemName: "forward.fill")
                .foregroundStyle(Color.textPrimary)
                .onTapGesture { player.skipNext() }
            
            Spacer()
            
            Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                .foregroundStyle(player.repeatMode == .none ? Color.textSecondary : Color.accent)
                .onTapGesture { player.cycleRepeatMode() }
        }
        .font(.auraTitle)
    }
    
    // MARK: - Helpers
    
    static func time(_ t: TimeInterval) -> String {
        guard t.isFinite, t >= 0 else { return "0:00" }
        let s = Int(t)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

#Preview {
    let vm = PlayerViewModel()
    vm.currentTitle = "Bohemian Rhapsody"
    vm.currentArtist = "Queen"
    vm.duration = 354
    vm.currentTime = 132
    vm.progress = 132.0 / 354.0
    vm.isPlaying = true
    return NowPlayingView()
        .environmentObject(vm)
}
