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
    
    @State private var exportURL: ExportedPlaylist?

    private var playlist: Playlist? { playlists.playlist(id: playlistID) }

    /// Write the playlist as .m3u8 and offer it via the share sheet.
    private func exportM3U() {
        guard let playlist,
              let url = M3UService.export(name: playlist.name, tracks: tracks)
        else { return }
        exportURL = ExportedPlaylist(url: url)
    }
    
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
                        TrackRow(track: track,
                                 isPlaying: player.currentTrackURL == track.url,
                                 isPaused: !player.isPlaying)
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    exportM3U()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(Color.accent)
                }
                .disabled(tracks.isEmpty)
                .accessibilityLabel("Export playlist")
            }
            ToolbarItem(placement: .topBarTrailing) {
                EditButton().foregroundStyle(Color.accent)
            }
        }
        .sheet(item: $exportURL) { item in
            PlaylistShareSheet(url: item.url)
        }
    }
}

/// Wrapper so a URL can drive `sheet(item:)`.
struct ExportedPlaylist: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

struct PlaylistShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
