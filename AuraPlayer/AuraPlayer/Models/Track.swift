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
    var genre: String?
    var duration: TimeInterval
    let url: URL
    var artworkData: Data?
    var dateAdded: Date
    var playCount: Int
    var rating: Int // 0...5
    
    init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        album: String,
        genre: String? = nil,
        duration: TimeInterval,
        url: URL,
        artworkData: Data? = nil,
        dateAdded: Date = .now,
        playCount: Int = 0,
        rating: Int = 0
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.genre = genre
        self.duration = duration
        self.url = url
        self.artworkData = artworkData
        self.dateAdded = dateAdded
        self.playCount = playCount
        self.rating = rating
    }
}
