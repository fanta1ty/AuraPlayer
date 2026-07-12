//
//  Album.swift
//  AuraPlayer
//
//  Created by mobile on 12/7/26.
//
//  A group of tracks sharing an album name, derived from the library.
//

import Foundation

struct Album: Identifiable {
    let id: String // album title (grouping key)
    let title: String
    let artist: String
    let tracks: [Track]
    
    var trackCount: Int { tracks.count }
    var artworkData: Data? {
        tracks.first { $0.artworkData != nil }?.artworkData
    }
}
