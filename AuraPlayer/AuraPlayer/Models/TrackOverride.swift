//
//  TrackOverride.swift
//  AuraPlayer
//
//  User-edited metadata that takes precedence over the file's own tags.
//  Stored app-side (keyed by filename) because AVFoundation can read tags
//  but cannot write them — this keeps the audio files untouched.
//

import Foundation

struct TrackOverride: Codable, Hashable {
    var title: String?
    var artist: String?
    var album: String?
    var genre: String?
    var year: String?
    /// Filename of the replacement artwork in the overrides art folder.
    var artworkFilename: String?

    var isEmpty: Bool {
        title == nil && artist == nil && album == nil
            && genre == nil && year == nil && artworkFilename == nil
    }
}
