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
        Dictionary(grouping: tracks, by: { $0.album })
            .map { title, tracks in
                Album(id: title, title: title, artist: name, tracks: tracks)
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
