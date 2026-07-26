//
//  Artist.swift
//  AuraPlayer
//
//  Created by mobile on 15/7/26.
//
//  Tracks grouped by artist (case-insensitively), with their albums.
//

import Foundation

struct Artist: Identifiable {
    let id: String        // lowercased name — dedupe key
    let name: String      // display name (first casing seen)
    let tracks: [Track]

    var trackCount: Int { tracks.count }

    var albums: [Album] {
        Dictionary(grouping: tracks) { track in
            "\(track.album)\u{1F}\(track.effectiveAlbumArtist)"
        }
        .map { key, tracks in
            Album(id: key,
                  title: tracks.first?.album ?? "Unknown Album",
                  artist: tracks.first?.effectiveAlbumArtist ?? name,
                  tracks: tracks)
        }
            .sorted {
                $0.title
                    .localizedCaseInsensitiveCompare(
                        $1.title
                    ) == .orderedAscending
            }
    }

    var albumCount: Int { albums.count }
}
