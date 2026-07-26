//
//  GlobalSearchView.swift
//  AuraPlayer
//
//  One search field across songs, albums and artists.
//

import SwiftUI

struct GlobalSearchView: View {
    @EnvironmentObject var library: LibraryViewModel
    @EnvironmentObject var player: PlayerViewModel
    @EnvironmentObject var stats: TrackStatsViewModel
    @EnvironmentObject var playlists: PlaylistViewModel

    @State private var query = ""

    private var trimmed: String {
        query.trimmingCharacters(in: .whitespaces)
    }

    private var songs: [Track] {
        guard !trimmed.isEmpty else { return [] }
        return library.tracks.filter { track in
            track.title.localizedCaseInsensitiveContains(trimmed)
                || track.artist.localizedCaseInsensitiveContains(trimmed)
                || track.album.localizedCaseInsensitiveContains(trimmed)
                || (track.composer ?? "").localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var albums: [Album] {
        guard !trimmed.isEmpty else { return [] }
        return AlbumGrouper.albums(from: library.tracks, matching: trimmed)
    }

    private var artists: [Artist] {
        guard !trimmed.isEmpty else { return [] }
        return Dictionary(grouping: library.tracks) { $0.effectiveAlbumArtist.lowercased() }
            .compactMap { key, tracks -> Artist? in
                let name = tracks.first?.effectiveAlbumArtist ?? key
                guard name.localizedCaseInsensitiveContains(trimmed) else { return nil }
                return Artist(id: key, name: name, tracks: tracks)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var hasResults: Bool {
        !songs.isEmpty || !albums.isEmpty || !artists.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if trimmed.isEmpty {
                    ContentUnavailableView(
                        "Search Your Library",
                        systemImage: "magnifyingglass",
                        description: Text("Find songs, albums, artists and composers.")
                    )
                } else if !hasResults {
                    ContentUnavailableView.search(text: trimmed)
                } else {
                    results
                }
            }
            .background(Color.background)
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Songs, albums, artists")
        .preferredColorScheme(.dark)
    }

    private var results: some View {
        List {
            if !artists.isEmpty {
                Section {
                    ForEach(artists.prefix(5)) { artist in
                        NavigationLink {
                            ArtistDetailView(artist: artist)
                        } label: {
                            Label(artist.name, systemImage: "music.mic")
                                .foregroundStyle(Color.textPrimary)
                        }
                        .listRowBackground(Color.background)
                    }
                } header: { header("Artists") }
            }

            if !albums.isEmpty {
                Section {
                    ForEach(albums.prefix(5)) { album in
                        NavigationLink {
                            AlbumDetailView(album: album)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(album.title)
                                    .foregroundStyle(Color.textPrimary)
                                Text(album.artist)
                                    .font(.auraCaption)
                                    .foregroundStyle(Color.textSecondary)
                            }
                        }
                        .listRowBackground(Color.background)
                    }
                } header: { header("Albums") }
            }

            if !songs.isEmpty {
                Section {
                    ForEach(Array(songs.enumerated()), id: \.element.id) { index, track in
                        TrackRow(track: track,
                                 isPlaying: player.currentTrackURL == track.url,
                                 rating: stats.rating(for: track.url),
                                 isPaused: !player.isPlaying)
                            .contentShape(Rectangle())
                            .onTapGesture { player.load(tracks: songs, startAt: index) }
                            .contextMenu {
                                Button {
                                    player.playNext(track)
                                } label: {
                                    Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                                }
                                Button {
                                    player.addToQueue(track)
                                } label: {
                                    Label("Add to Queue", systemImage: "text.append")
                                }
                            }
                            .listRowBackground(Color.background)
                    }
                } header: { header("Songs · \(songs.count)") }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .safeAreaPadding(.bottom, AuraLayout.miniPlayerClearance)
    }

    private func header(_ text: String) -> some View {
        Text(text)
            .font(.auraCaption)
            .foregroundStyle(Color.textSecondary)
    }
}
