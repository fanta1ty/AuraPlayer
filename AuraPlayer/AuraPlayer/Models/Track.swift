//
//  Track.swift
//  AuraPlayer
//
//  Created by mobile on 12/7/26.
//
//  A single audio track with metadata read from the file.
//

import Foundation

struct Track: Identifiable, Hashable {
    let id: UUID
    var title: String
    var artist: String
    var album: String
    /// Credited album artist — differs from `artist` on compilations, and is
    /// what albums should be grouped by.
    var albumArtist: String?
    var composer: String?
    var trackNumber: Int?
    var discNumber: Int?
    var genre: String?
    var year: String?
    var duration: TimeInterval
    let url: URL
    var artworkData: Data?
    var dateAdded: Date

    // Note: ratings and play counts live in TrackStatsViewModel, not here —
    // they must survive library rescans, which rebuild every Track.


    init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        album: String,
        albumArtist: String? = nil,
        composer: String? = nil,
        trackNumber: Int? = nil,
        discNumber: Int? = nil,
        genre: String? = nil,
        year: String? = nil,
        duration: TimeInterval,
        url: URL,
        artworkData: Data? = nil,
        dateAdded: Date = .now
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.albumArtist = albumArtist
        self.composer = composer
        self.trackNumber = trackNumber
        self.discNumber = discNumber
        self.genre = genre
        self.year = year
        self.duration = duration
        self.url = url
        self.artworkData = artworkData
        self.dateAdded = dateAdded
    }

    /// Who the album belongs to — falls back to the track artist. A tag that
    /// exists but is blank is treated as absent; plenty of taggers write an
    /// empty string rather than omitting the field.
    var effectiveAlbumArtist: String {
        guard let albumArtist,
              !albumArtist.trimmingCharacters(in: .whitespaces).isEmpty
        else { return artist }
        return albumArtist
    }

    /// Sort key that puts an album in disc/track order.
    var albumSortKey: (Int, Int, String) {
        (discNumber ?? 1, trackNumber ?? Int.max, title.lowercased())
    }
}
