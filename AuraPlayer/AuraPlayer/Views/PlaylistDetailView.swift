//
//  PlaylistDetailView.swift
//  AuraPlayer
//
//  Created by mobile on 16/7/26.
//

import SwiftUI

struct PlaylistDetailView: View {
    let playlistID: UUID
    
    @EnvironmentObject var playlists: PlaylistViewModel
    @EnvironmentObject var library: LibraryViewModel
    @EnvironmentObject var player: PlayerViewModel
    
    private var playlist: Playlist? { playlists.playlist(id: playlistID) }
    
    /// Resolve stored filenames against the scanned library, preserving order.
    private var tracks: [Track] {
        guard let playlist else { return [] }
        let byName = Dictionary(library.tracks.map { ($0.url.lastPathComponent, $0) },
                                uniquingKeysWith: { a, _ in a })
        return playlist.trackFilenames.compactMap { byName[$0] }
    }
    
    var body: some View {
        List {
            if !tracks.isEmpty {
                Section {
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                        TrackRow(track: track, isPlaying: player.currentTrackURL == track.url)
                            .contentShape(Rectangle())
                            .onTapGesture { player.load(tracks: tracks, startAt: index) }
                            .listRowBackground(Color.background)
                    }
                    .onMove { playlists.moveTracks(from: $0, to: $1, in: playlistID) }
                    .onDelete { playlists.removeTracks(at: $0, from: playlistID) }
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
        .overlay {
            if tracks.isEmpty {
                ContentUnavailableView("Empty Playlist", systemImage: "music.note.list",
                                       description: Text("Long-press a song in your library to add it."))
            }
        }
        .navigationTitle(playlist?.name ?? "Playlist")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton().foregroundStyle(Color.accent) }
    }
}
