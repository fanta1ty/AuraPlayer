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

    /// Same grouping rules as the Albums tab, so an artist page and the
    /// library can never disagree about what counts as one record.
    var albums: [Album] { AlbumGrouper.albums(from: tracks) }

    var albumCount: Int { albums.count }
}
