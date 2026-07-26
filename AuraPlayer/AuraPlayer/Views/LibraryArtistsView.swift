//
//  LibraryArtistsView.swift
//  AuraPlayer
//
//  Created by mobile on 15/7/26.
//
//  Alphabetical artist list with an A–Z section index.
//

import SwiftUI

struct LibraryArtistsView: View {
    @EnvironmentObject var player: PlayerViewModel
    @EnvironmentObject var library: LibraryViewModel
    @EnvironmentObject var stats: TrackStatsViewModel

    @State private var showComposers = false
    @State private var showFolders = false
    
    private var artists: [Artist] {
        // Group by album artist so a compilation lists under its credited
        // artist instead of scattering across every featured performer.
        Dictionary(grouping: library.tracks) { $0.effectiveAlbumArtist.lowercased() }
            .map { key, tracks in
                Artist(
                    id: key,
                    name: tracks.first?.effectiveAlbumArtist ?? key,
                    tracks: tracks
                )
            }
            .sorted {
                $0.name
                    .localizedCaseInsensitiveCompare(
                        $1.name
                    ) == .orderedAscending
            }
    }
    
    /// Artists grouped by first letter ("#" for non-letters), sorted.
    private var sections: [(letter: String, artists: [Artist])] {
        Dictionary(grouping: artists) { artist -> String in
            guard let first = artist.name.first, first.isLetter else {
                return "#"
            }
            return String(first).uppercased()
        }
        .map { (letter: $0.key, artists: $0.value) }
        .sorted { $0.letter < $1.letter }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if artists.isEmpty {
                    ContentUnavailableView("No Artists", systemImage: "music.mic",
                                           description: Text("Add music to build your library."))
                } else {
                    ScrollViewReader { proxy in
                        List {
                            ForEach(sections, id: \.letter) { section in
                                Section {
                                    ForEach(section.artists) { artist in
                                        NavigationLink {
                                            ArtistDetailView(artist: artist)
                                        } label: {
                                            row(artist)
                                        }
                                        .listRowBackground(Color.background)
                                    }
                                } header: {
                                    Text(section.letter)
                                        .font(.auraCaption)
                                        .foregroundStyle(Color.accent)
                                }
                                .id(section.letter)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .background(Color.background)
                        .safeAreaPadding(.bottom, AuraLayout.miniPlayerClearance)
                        .overlay(alignment: .trailing) { sectionIndex(proxy) }
                    }
                }
            }
            .background(Color.background)
            .navigationTitle("Artists")
            // Composer and folder browsing live here rather than as their own
            // tabs — five tabs is already the limit before iOS adds "More".
            // NavigationLink inside a Menu doesn't reliably register taps, so
            // the menu items set state and navigation is driven from here.
            .navigationDestination(isPresented: $showComposers) {
                LibraryComposersView()
            }
            .navigationDestination(isPresented: $showFolders) {
                LibraryFoldersView()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showComposers = true
                        } label: {
                            Label("Composers", systemImage: "music.quarternote.3")
                        }
                        Button {
                            showFolders = true
                        } label: {
                            Label("Folders", systemImage: "folder")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.auraTitle)
                            .foregroundStyle(Color.accent)
                            .frame(width: 44, height: 44)   // full-size tap target
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Browse by")
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func row(_ artist: Artist) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(artist.name)
                .font(.auraBody)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
            Text("\(artist.albumCount) album\(artist.albumCount == 1 ? "" : "s") · \(artist.trackCount) track\(artist.trackCount == 1 ? "" : "s")")
                .font(.auraCaption)
                .foregroundStyle(Color.textSecondary)
        }
    }
    
    private func sectionIndex(_ proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 2) {
            ForEach(sections, id: \.letter) { section in
                Text(section.letter)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accent)
                    .frame(width: 18)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation { proxy.scrollTo(section.letter, anchor: .top) }
                    }
            }
        }
        .padding(.trailing, AuraSpacing.xs)
    }
}
