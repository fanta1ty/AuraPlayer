//
//  AlbumDetailView.swift
//  AuraPlayer
//
//  Created by mobile on 12/7/26.
//
//  Tracks within one album, with Play All / Shuffle.
//

import SwiftUI

struct AlbumDetailView: View {
    let album: Album
    @EnvironmentObject var player: PlayerViewModel
    
    /// Albums play in disc/track order — never alphabetically.
    private var tracks: [Track] {
        album.tracks.sorted { $0.albumSortKey < $1.albumSortKey }
    }

    /// True when the album has real track numbers to show.
    private var hasTrackNumbers: Bool {
        album.tracks.contains { $0.trackNumber != nil }
    }

    private var isMultiDisc: Bool {
        Set(album.tracks.compactMap(\.discNumber)).count > 1
    }
    
    var body: some View {
        List {
            Section {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    HStack(spacing: AuraSpacing.md) {
                        // Show the real track number when tagged, "1-4" style
                        // for multi-disc sets, else fall back to position.
                        Text(label(for: track, fallback: index + 1))
                            .font(.auraCaption)
                            .foregroundStyle(Color.textTertiary)
                            .frame(width: isMultiDisc ? 34 : 24, alignment: .trailing)
                        Text(track.title)
                            .font(.auraBody)
                            .foregroundStyle(
                                player.currentTrackURL == track.url ? Color.accent : Color.textPrimary
                            )
                            .lineLimit(1)
                        Spacer()
                        Text(TrackRow.durationString(track.duration))
                            .font(.auraTimestamp)
                            .foregroundStyle(Color.textTertiary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { player.load(tracks: tracks, startAt: index) }
                    .listRowBackground(Color.background)
                }
            } header: {
                header
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.background)
        .navigationTitle(album.title)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func label(for track: Track, fallback: Int) -> String {
        guard hasTrackNumbers, let number = track.trackNumber else { return "\(fallback)" }
        if isMultiDisc, let disc = track.discNumber {
            return "\(disc)-\(number)"
        }
        return "\(number)"
    }

    private var header: some View {
        VStack(spacing: AuraSpacing.md) {
            Group {
                if let data = album.artworkData, let img = UIImage(data: data) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    Color.surfaceElevated
                        .overlay(Image(systemName: "square.stack").font(.system(size: 40))
                            .foregroundStyle(Color.accent))
                }
            }
            .frame(width: 160, height: 160)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.large))
            .cardShadow()
            
            Text(album.artist)
                .font(.auraHeadline)
                .foregroundStyle(Color.textSecondary)
            
            HStack(spacing: AuraSpacing.md) {
                AuraButton("Play", systemImage: "play.fill", variant: .primary) {
                    if player.isShuffled {
                        player.toggleShuffle()
                    }
                    player.load(tracks: tracks, startAt: 0)
                }
                AuraButton("Shuffle", systemImage: "shuffle", variant: .secondary) {
                    if !player.isShuffled {
                        player.toggleShuffle()
                    }
                    player.load(tracks: tracks, startAt: 0)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AuraSpacing.lg)
        .textCase(nil) // don't uppercase the header
    }
}
