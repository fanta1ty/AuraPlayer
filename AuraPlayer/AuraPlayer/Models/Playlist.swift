//
//  Playlist.swift
//  AuraPlayer
//
//  Created by mobile on 15/7/26.
//
//  A user-created playlist. Tracks are stored as filenames (stable across
//  rescans/reinstalls) and resolved against the library at read time.
//

import Foundation

struct Playlist: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var trackFilenames: [String]
    var createdDate: Date
    var coverFilename: String?

    init(id: UUID = UUID(), name: String, trackFilenames: [String] = [],
         createdDate: Date = .now, coverFilename: String? = nil) {
        self.id = id
        self.name = name
        self.trackFilenames = trackFilenames
        self.createdDate = createdDate
        self.coverFilename = coverFilename
    }
}
