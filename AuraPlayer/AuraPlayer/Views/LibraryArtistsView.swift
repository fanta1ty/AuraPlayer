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
    @StateObject private var library = LibraryViewModel()
    
    private var artists: [Artist] {
        Dictionary(grouping: library.tracks) { $0.artist.lowercased() }
            .map { key, tracks in
                Artist(
                    id: key,
                    name: tracks.first?.artist ?? key,
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
                        .overlay(alignment: .trailing) { sectionIndex(proxy) }
                    }
                }
            }
            .background(Color.background)
            .navigationTitle("Artists")
        }
        .preferredColorScheme(.dark)
        .task { if library.tracks.isEmpty { await library.scan() } }
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
