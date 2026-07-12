//
//  LibraryScanner.swift
//  AuraPlayer
//
//  Created by mobile on 12/7/26.
//
//  Async scan of the app's Documents directory for audio files,
//  reading metadata from each via AVAsset.
//

import Foundation
import AVFoundation

enum LibraryScanner {
    static let supportedExtensions: Set<String> = [
        "mp3",
        "flac",
        "alac",
        "m4a",
        "aac",
        "wav",
        "aiff",
        "ogg",
        "dsf",
        "dff"
    ]
    
    /// Scan Documents and return a Track for every supported audio file.
    static func scanDocuments() async -> [Track] {
        let fm = FileManager.default
        guard let docs = fm.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            return []
        }
        
        let urls = (
            try? fm
                .contentsOfDirectory(
                    at: docs,
                    includingPropertiesForKeys: [.creationDateKey],
                    options: [.skipsHiddenFiles]
                )
        ) ?? []
        
        var tracks: [Track] = []
        for url in urls where supportedExtensions.contains(
            url.pathExtension.lowercased()
        ) {
            tracks.append(await makeTrack(from: url))
        }
        return tracks
    }
    
    private static func makeTrack(from url: URL) async -> Track {
        let asset = AVURLAsset(url: url)
        
        var title = url.deletingPathExtension().lastPathComponent
        var artist = "Unknown Artist"
        var album = "Unknown Album"
        var genre: String?
        var artworkData: Data?
        var duration: TimeInterval = 0
        
        if let cmDuration = try? await asset.load(.duration) {
            let seconds = CMTimeGetSeconds(cmDuration)
            if seconds.isFinite { duration = seconds }
        }
        
        if let items = try? await asset.load(.commonMetadata) {
            for item in items {
                switch item.commonKey {
                case .commonKeyTitle:
                    if let v = try? await item.load(.stringValue), !v.isEmpty {
                        title = v
                    }
                case .commonKeyArtist:
                    if let v = try? await item.load(.stringValue), !v.isEmpty {
                        artist = v
                    }
                case .commonKeyAlbumName:
                    if let v = try? await item.load(.stringValue), !v.isEmpty {
                        album = v
                    }
                case .commonKeyType:
                    genre = try? await item.load(.stringValue)
                case .commonKeyArtwork:
                    artworkData = try? await item.load(.dataValue)
                default:
                    break
                }
            }
        }
        
        let dateAdded = (
            try? url.resourceValues(forKeys: [.creationDateKey]).creationDate
        ) ?? .now
        
        return Track(
            title: title,
            artist: artist,
            album: album,
            genre: genre,
            duration: duration,
            url: url,
            artworkData: artworkData,
            dateAdded: dateAdded
        )
    }
}
