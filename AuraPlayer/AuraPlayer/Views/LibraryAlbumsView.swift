//
//  LibraryAlbumsView.swift
//  AuraPlayer
//
//  Created by mobile on 12/7/26.
//
//  2-column grid of albums grouped from the library.
//

import SwiftUI

struct LibraryAlbumsView: View {
    @EnvironmentObject var player: PlayerViewModel
    @EnvironmentObject var library: LibraryViewModel
    
    private let columns = [
        GridItem(.flexible(), spacing: AuraSpacing.md),
        GridItem(.flexible(), spacing: AuraSpacing.md)
    ]
    
    private var albums: [Album] {
        Dictionary(grouping: library.tracks, by: { $0.album })
            .map { name, tracks in
                Album(
                    id: name,
                    title: name,
                    artist: tracks.first?.artist ?? "Unknown Artist",
                    tracks: tracks
                )
            }
            .sorted {
                $0.title
                    .localizedCaseInsensitiveCompare(
                        $1.title
                    ) == .orderedAscending
            }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if albums.isEmpty {
                    ContentUnavailableView(
                        "No Albums",
                        systemImage: "square.stack",
                        description: Text("Add music to build your library."))
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: AuraSpacing.lg) {
                            ForEach(albums) { album in
                                NavigationLink {
                                    AlbumDetailView(album: album)
                                } label: {
                                    AlbumCard(album: album)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(AuraSpacing.md)
                    }
                }
            }
            .background(Color.background)
            .navigationTitle("Albums")
        }
        .preferredColorScheme(.dark)
    }
}

struct AlbumCard: View {
    let album: Album
    
    var body: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.sm) {
            RoundedRectangle(cornerRadius: AuraRadius.medium)
                .fill(Color.surfaceElevated)
                .aspectRatio(1, contentMode: .fit) // square, fills the column width
                .overlay {
                    if let data = album.artworkData, let img = UIImage(data: data) {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        Image(systemName: "square.stack")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.accent)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: AuraRadius.medium))
            
            Text(album.title)
                .font(.auraHeadline)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
            Text(album.artist)
                .font(.auraCaption)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(1)
            Text("\(album.trackCount) track\(album.trackCount == 1 ? "" : "s")")
                .font(.auraCaption)
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
