//
//  TrackRow.swift
//  AuraPlayer
//
//  Created by mobile on 12/7/26.
//
//  Reusable library row: [artwork] [title + artist] [duration].
//

import SwiftUI

struct TrackRow: View {
    let track: Track
    var isPlaying: Bool = false
    
    var body: some View {
        HStack(spacing: AuraSpacing.md) {
            artwork
            
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.auraBody)
                    .foregroundStyle(
                        isPlaying ? Color.accent : Color.textPrimary
                    )
                    .lineLimit(1)
                Text(track.artist)
                    .font(.auraCaption)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(Self.durationString(track.duration))
                .font(.auraTimestamp)
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.vertical, AuraSpacing.xs)
    }
    
    @ViewBuilder private var artwork: some View {
        Group {
            if let data = track.artworkData, let img = UIImage(data: data) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Color.surfaceElevated
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundStyle(Color.accent)
                    )
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.small))
    }
    
    static func durationString(_ t: TimeInterval) -> String {
        guard t.isFinite, t >= 0 else { return "0:00" }
        let s = Int(t)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

#Preview {
    let sample = Track(
        title: "Bohemian Rhapsody",
        artist: "Queen",
        album: "A Night at the Opera",
        duration: 354,
        url: URL(fileURLWithPath: "/tmp/sample.mp3")
    )
    let longOne = Track(
        title: "A Really Long Song Title That Should Truncate Nicely",
        artist: "Some Artist With A Long Name",
        album: "Album",
        duration: 812,
        url: URL(fileURLWithPath: "/tmp/long.mp3")
    )
    
    return VStack(spacing: 0) {
        TrackRow(track: sample, isPlaying: true)
        TrackRow(track: longOne)
    }
    .padding(AuraSpacing.md)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Color.background)
    .preferredColorScheme(.dark)
}
