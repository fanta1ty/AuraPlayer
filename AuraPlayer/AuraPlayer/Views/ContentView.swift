//
//  ContentView.swift
//  AuraPlayer
//
//  Created by mobile on 4/7/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var player = PlayerViewModel()
    
    var body: some View {
        VStack(spacing: AuraSpacing.xl) {
            Text("AuraPlayer")
                .font(.auraDisplay)
                .foregroundStyle(Color.textPrimary)
            
            // Progress slider (scrubbing seeks)
            VStack(spacing: AuraSpacing.sm) {
                AuraSlider(value: Binding(get: {
                    player.progress
                }, set: {
                    player.seek(toProgress: $0)
                }))
                HStack {
                    Text(timeString(player.currentTime))
                    Spacer()
                    Text(timeString(player.duration))
                }
                .font(.auraTimestamp)
                .foregroundStyle(Color.textSecondary)
            }
            
            AuraButton("Play Queue", systemImage: "play.fill", variant: .primary) {
                let names = ["track1", "track2", "track3"]   // your 3 test files
                let urls = names.compactMap { Bundle.main.url(forResource: $0, withExtension: "mp3") }
                player.load(queue: urls)
            }
            
            HStack(spacing: AuraSpacing.lg) {
                AuraButton(systemImage: "backward.fill", variant: .icon) { player.skipPrevious() }
                AuraButton(systemImage: player.isPlaying ? "pause.fill" : "play.fill", variant: .icon) {
                    player.togglePlayPause()
                }
                AuraButton(systemImage: "forward.fill", variant: .icon) { player.skipNext() }
            }
            
            HStack(spacing: AuraSpacing.xl) {
                // Shuffle
                Image(systemName: "shuffle")
                    .font(.auraHeadline)
                    .foregroundStyle(
                        player.isShuffled ? Color.accent : Color.textSecondary
                    )
                    .onTapGesture {
                        player.toggleShuffle()
                    }
                
                // Repeat (icon reflects mode)
                Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                    .font(.auraHeadline)
                    .foregroundStyle(
                        player.repeatMode == .none ? Color.textSecondary
                        : Color.accent
                    )
                    .onTapGesture {
                        player.cycleRepeatMode()
                    }
            }
        }
        .padding(AuraSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.background)
        .preferredColorScheme(.dark)
    }
    
    private func timeString(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

#Preview {
    ContentView()
}
