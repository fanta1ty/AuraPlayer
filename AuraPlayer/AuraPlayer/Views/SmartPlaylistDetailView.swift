//
//  SmartPlaylistDetailView.swift
//  AuraPlayer
//
//  Tracks currently matching a smart playlist's rules.
//

import SwiftUI

struct SmartPlaylistDetailView: View {
    let playlistID: UUID

    @EnvironmentObject var library: LibraryViewModel
    @EnvironmentObject var player: PlayerViewModel
    @EnvironmentObject var stats: TrackStatsViewModel
    @StateObject private var smart = SmartPlaylistViewModel.shared

    private var playlist: SmartPlaylist? { smart.playlist(id: playlistID) }

    private var tracks: [Track] {
        guard let playlist else { return [] }
        return SmartPlaylistEngine.evaluate(playlist, tracks: library.tracks, stats: stats)
    }

    var body: some View {
        List {
            if !tracks.isEmpty {
                Section {
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                        TrackRow(track: track,
                                 isPlaying: player.currentTrackURL == track.url,
                                 rating: stats.rating(for: track.url),
                                 isPaused: !player.isPlaying)
                            .contentShape(Rectangle())
                            .onTapGesture { player.load(tracks: tracks, startAt: index) }
                            .listRowBackground(Color.background)
                    }
                } header: {
                    HStack(spacing: AuraSpacing.md) {
                        AuraButton("Play", systemImage: "play.fill", variant: .primary) {
                            if player.isShuffled { player.toggleShuffle() }
                            player.load(tracks: tracks, startAt: 0)
                        }
                        AuraButton("Shuffle", systemImage: "shuffle", variant: .secondary) {
                            if !player.isShuffled { player.toggleShuffle() }
                            player.load(tracks: tracks, startAt: 0)
                        }
                    }
                    .padding(.vertical, AuraSpacing.md)
                    .textCase(nil)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.background)
        .safeAreaPadding(.bottom, AuraLayout.miniPlayerClearance)
        .overlay {
            if tracks.isEmpty {
                ContentUnavailableView(
                    "Nothing Matches",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("No tracks meet these rules yet.")
                )
            }
        }
        .navigationTitle(playlist?.name ?? "Smart Playlist")
        .navigationBarTitleDisplayMode(.inline)
    }
}
