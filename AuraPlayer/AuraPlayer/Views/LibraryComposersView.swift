//
//  LibraryComposersView.swift
//  AuraPlayer
//
//  Browse by composer — the way classical libraries are actually organised,
//  where the performer matters less than who wrote the piece.
//

import SwiftUI

struct LibraryComposersView: View {
    @EnvironmentObject var library: LibraryViewModel
    @EnvironmentObject var player: PlayerViewModel
    @EnvironmentObject var stats: TrackStatsViewModel

    private struct Composer: Identifiable {
        let id: String          // lowercased name
        let name: String
        let tracks: [Track]
    }

    private var composers: [Composer] {
        Dictionary(grouping: library.tracks.filter { !($0.composer ?? "").isEmpty }) {
            ($0.composer ?? "").lowercased()
        }
        .map { key, tracks in
            Composer(id: key, name: tracks.first?.composer ?? key, tracks: tracks)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        Group {
            if composers.isEmpty {
                ContentUnavailableView(
                    "No Composers",
                    systemImage: "music.quarternote.3",
                    description: Text("None of your tracks have a composer tag. Classical releases usually do.")
                )
            } else {
                List {
                    ForEach(composers) { composer in
                        NavigationLink {
                            ComposerDetailView(name: composer.name, tracks: composer.tracks)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(composer.name)
                                    .font(.auraBody)
                                    .foregroundStyle(Color.textPrimary)
                                    .lineLimit(1)
                                Text("\(composer.tracks.count) track\(composer.tracks.count == 1 ? "" : "s")")
                                    .font(.auraCaption)
                                    .foregroundStyle(Color.textSecondary)
                            }
                        }
                        .listRowBackground(Color.background)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .safeAreaPadding(.bottom, AuraLayout.miniPlayerClearance)
            }
        }
        .background(Color.background)
        .navigationTitle("Composers")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ComposerDetailView: View {
    let name: String
    let tracks: [Track]

    @EnvironmentObject var player: PlayerViewModel
    @EnvironmentObject var stats: TrackStatsViewModel

    /// Group a composer's work by album so multi-movement pieces stay together.
    private var sorted: [Track] {
        tracks.sorted {
            if $0.album != $1.album {
                return $0.album.localizedCaseInsensitiveCompare($1.album) == .orderedAscending
            }
            return $0.albumSortKey < $1.albumSortKey
        }
    }

    var body: some View {
        List {
            Section {
                ForEach(Array(sorted.enumerated()), id: \.element.id) { index, track in
                    TrackRow(track: track,
                             isPlaying: player.currentTrackURL == track.url,
                             rating: stats.rating(for: track.url))
                        .contentShape(Rectangle())
                        .onTapGesture { player.load(tracks: sorted, startAt: index) }
                        .listRowBackground(Color.background)
                }
            } header: {
                HStack(spacing: AuraSpacing.md) {
                    AuraButton("Play", systemImage: "play.fill", variant: .primary) {
                        if player.isShuffled { player.toggleShuffle() }
                        player.load(tracks: sorted, startAt: 0)
                    }
                    AuraButton("Shuffle", systemImage: "shuffle", variant: .secondary) {
                        if !player.isShuffled { player.toggleShuffle() }
                        player.load(tracks: sorted, startAt: 0)
                    }
                }
                .padding(.vertical, AuraSpacing.md)
                .textCase(nil)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.background)
        .safeAreaPadding(.bottom, AuraLayout.miniPlayerClearance)
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
