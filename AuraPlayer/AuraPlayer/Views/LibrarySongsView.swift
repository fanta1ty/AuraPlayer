//
//  LibrarySongsView.swift
//  AuraPlayer
//
//  Created by mobile on 12/7/26.
//
//  All songs in the library, searchable and sortable. Tap to play
//

import SwiftUI

struct LibrarySongsView: View {
    @EnvironmentObject var player: PlayerViewModel
    @EnvironmentObject var library: LibraryViewModel
    @EnvironmentObject var playlists: PlaylistViewModel
    
    @State private var searchText = ""
    @State private var sort: SortOrder = .title
    
    enum SortOrder: String, CaseIterable, Identifiable {
        case title = "A-Z"
        case recentlyAdded = "Recently Added"
        case duration = "Duration"
        var id: String { rawValue }
    }
    
    private var displayedTracks: [Track] {
        var list = library.tracks
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            list = list.filter({
                $0.title
                    .lowercased()
                    .contains(q) || $0.artist
                    .lowercased()
                    .contains(q)
            })
        }
        switch sort {
        case .title:
            list
                .sort {
                    $0.title
                        .localizedCaseInsensitiveCompare(
                            $1.title
                        ) == .orderedAscending
                }
        case .recentlyAdded:
            list.sort { $0.dateAdded > $1.dateAdded }
        case .duration:
            list.sort { $0.duration < $1.duration }
        }
        return list
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if library.isScanning && library.tracks.isEmpty {
                    ProgressView().tint(Color.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.background)
                } else if displayedTracks.isEmpty {
                    emptyState
                } else {
                    songList
                }
            }
            .navigationTitle("Songs")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort", selection: $sort) {
                            ForEach(SortOrder.allCases) { Text($0.rawValue).tag($0) }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundStyle(Color.accent)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search songs or artists")
        }
        .preferredColorScheme(.dark)
    }
    
    private var songList: some View {
        List {
            ForEach(displayedTracks) { track in
                TrackRow(
                    track: track,
                    isPlaying: player.currentTrackURL == track.url
                )
                .contentShape(Rectangle())
                .onTapGesture { play(track) }
                .contextMenu {
                    Menu("Add to Playlist") {
                        ForEach(playlists.playlists) { playlist in
                            Button(playlist.name) {
                                playlists.add(track: track, to: playlist)
                            }
                        }
                    }
                }
                .listRowBackground(Color.background)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.background)
        .refreshable { await library.scan() }
    }
    
    private func play(_ track: Track) {
        guard let start = displayedTracks.firstIndex(of: track) else { return }
        player.load(tracks: displayedTracks, startAt: start)
    }
    
    private var emptyState: some View {
        VStack(spacing: AuraSpacing.md) {
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundStyle(Color.textTertiary)
            Text("No songs yet")
                .font(.auraTitle)
                .foregroundStyle(Color.textPrimary)
            Text("Add audio files to AuraPlayer in the Files app, then pull down to refresh.")
                .font(.auraBody)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AuraSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.background)
    }
}
