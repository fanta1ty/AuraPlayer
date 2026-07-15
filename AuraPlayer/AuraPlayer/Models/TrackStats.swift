//
//  TrackStats.swift
//  AuraPlayer
//
//  Created by mobile on 16/7/26.
//
//  User data for a track (rating, play count), stored separately from the file.
//

import Foundation

struct TrackStats: Codable, Hashable {
    var rating: Int = 0        // 0...5
    var playCount: Int = 0
}
