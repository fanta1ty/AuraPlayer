//
//  ArtistDetailView.swift
//  AuraPlayer
//
//  Created by mobile on 15/7/26.
//
//  One artist's albums as a grid. Reuses AlbumCard + AlbumDetailView.
//

import SwiftUI

struct ArtistDetailView: View {
    let artist: Artist
    
    private let columns = [
        GridItem(.flexible(), spacing: AuraSpacing.md),
        GridItem(.flexible(), spacing: AuraSpacing.md)
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AuraSpacing.lg) {
                Text(
                    "\(artist.albumCount) album\(artist.albumCount == 1 ? "" : "s") · \(artist.trackCount) track\(artist.trackCount == 1 ? "" : "s")"
                )
                .font(.auraCaption)
                .foregroundStyle(Color.textSecondary)
                
                LazyVGrid(columns: columns, spacing: AuraSpacing.lg) {
                    ForEach(artist.albums) { album in
                        NavigationLink {
                            AlbumDetailView(album: album)
                        } label: {
                            AlbumCard(album: album)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(AuraSpacing.md)
        }
        .background(Color.background)
        .navigationTitle(artist.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
